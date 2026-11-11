//! Minimal, dynamically loaded DjVuLibre C API. No CRT is linked into Kadr.
const std = @import("std");
const w = @import("win.zig");
const allocator = std.heap.page_allocator;
// MinGW's FARPROC is translated as a variadic stdcall function by Zig 0.11.
// Use the ABI-equivalent raw pointer binding without instantiating FARPROC.
extern "kernel32" fn GetProcAddress(w.c.HMODULE, [*:0]const u8) callconv(.Stdcall) ?*anyopaque;

const Context = opaque {};
const Job = opaque {};
const Doc = opaque {};
const Page = opaque {};
const Format = opaque {};
const Message = extern struct {
    tag: c_int,
    context: ?*Context,
    document: ?*Doc,
    page: ?*Page,
    job: ?*Job,
};
const Rect = extern struct { x: c_int = 0, y: c_int = 0, w: c_uint, h: c_uint };

// These are exports, unlike the job_done, document_release and page_release
// convenience macros in ddjvuapi.h. All DjVu entry points are cdecl on x86.
const Api = struct {
    ddjvu_context_create: *const fn ([*:0]const u8) callconv(.C) ?*Context,
    ddjvu_context_release: *const fn (*Context) callconv(.C) void,
    ddjvu_document_create_by_filename_utf8: *const fn (*Context, [*:0]const u8, c_int) callconv(.C) ?*Doc,
    ddjvu_document_job: *const fn (*Doc) callconv(.C) ?*Job,
    ddjvu_document_get_pagenum: *const fn (*Doc) callconv(.C) c_int,
    ddjvu_page_create_by_pageno: *const fn (*Doc, c_int) callconv(.C) ?*Page,
    ddjvu_page_job: *const fn (*Page) callconv(.C) ?*Job,
    ddjvu_job_status: *const fn (*Job) callconv(.C) c_int,
    ddjvu_job_stop: *const fn (*Job) callconv(.C) void,
    ddjvu_job_release: *const fn (*Job) callconv(.C) void,
    ddjvu_message_peek: *const fn (*Context) callconv(.C) ?*const Message,
    ddjvu_message_pop: *const fn (*Context) callconv(.C) void,
    ddjvu_page_get_width: *const fn (*Page) callconv(.C) c_int,
    ddjvu_page_get_height: *const fn (*Page) callconv(.C) c_int,
    ddjvu_format_create: *const fn (c_int, c_int, [*]c_uint) callconv(.C) ?*Format,
    ddjvu_format_set_row_order: *const fn (*Format, c_int) callconv(.C) void,
    ddjvu_format_set_y_direction: *const fn (*Format, c_int) callconv(.C) void,
    ddjvu_format_release: *const fn (*Format) callconv(.C) void,
    ddjvu_page_render: *const fn (*Page, c_int, *const Rect, *const Rect, *const Format, c_ulong, [*]u8) callconv(.C) c_int,
};

const dll_names = .{
    w.L("deps\\djvu\\msvcr100.dll"),
    w.L("deps\\djvu\\msvcp100.dll"),
    w.L("deps\\djvu\\libjpeg.dll"),
    w.L("deps\\djvu\\libdjvulibre.dll"),
};
var cached_api: ?Api = null;
var cached_modules: [dll_names.len]w.c.HMODULE = undefined;

// Called on the UI thread. A successful load is cached for the process lifetime:
// job_release/context_release do NOT join DjVuLibre's worker threads. Unloading
// the DLL on close (especially after a decode error) could execute freed code.
// Failed/partial library loads, in contrast, have not started any jobs and are
// completely unwound. Every dependency is preloaded by absolute path, avoiding
// both the working-directory DLL search and a process-wide SetDllDirectory.
fn getApi() ?*const Api {
    if (cached_api) |*api| return api;
    const path = allocator.alloc(u16, 32768) catch return null;
    defer allocator.free(path);
    const n: usize = @intCast(w.c.GetModuleFileNameW(null, path.ptr, @intCast(path.len)));
    if (n == 0 or n >= path.len) return null;
    var prefix = n;
    while (prefix > 0 and path[prefix - 1] != '\\' and path[prefix - 1] != '/') : (prefix -= 1) {}
    if (prefix == 0) return null;

    var modules: [dll_names.len]w.c.HMODULE = undefined;
    var count: usize = 0;
    var keep = false;
    defer {
        if (!keep) {
            while (count > 0) {
                count -= 1;
                _ = w.c.FreeLibrary(modules[count]);
            }
        }
    }
    inline for (dll_names) |name| {
        if (prefix + name.len >= path.len) return null;
        @memcpy(path[prefix..][0..name.len], name);
        path[prefix + name.len] = 0;
        modules[count] = w.c.LoadLibraryW(@ptrCast(path.ptr)) orelse return null;
        count += 1;
    }
    var api: Api = undefined;
    inline for (std.meta.fields(Api)) |field| {
        const symbol = GetProcAddress(modules[count - 1], field.name ++ "\x00") orelse return null;
        @field(api, field.name) = @ptrCast(symbol);
    }
    cached_modules = modules;
    cached_api = api;
    keep = true;
    return &cached_api.?;
}

pub const max_pages = 100000;
pub const max_side = 6000;
pub const max_pixels: u64 = 80000000;
const job_ok = 2;
const decode_timeout_ms: u32 = 60000;

pub const Raster = struct {
    pixels: []u8,
    width: u32,
    height: u32,

    pub fn deinit(self: *Raster) void {
        allocator.free(self.pixels);
        self.* = .{ .pixels = &.{}, .width = 0, .height = 0 };
    }
};

pub const Document = struct {
    api: ?*const Api = null,
    context: ?*Context = null,
    document: ?*Doc = null,
    pages: u32 = 0,

    pub fn open(self: *Document, path: [*:0]const u16) bool {
        self.close();
        self.api = getApi() orelse return false;
        var success = false;
        defer if (!success) self.close();
        const api = self.api.?;
        // The official Windows build's UTF-8 variant supports Unicode paths;
        // the locale-based filename API silently loses non-ANSI characters.
        const utf8 = std.unicode.utf16leToUtf8AllocZ(allocator, std.mem.span(path)) catch return false;
        defer allocator.free(utf8);
        self.context = api.ddjvu_context_create("Kadr") orelse return false;
        self.document = api.ddjvu_document_create_by_filename_utf8(self.context.?, utf8.ptr, 0) orelse return false;
        const job = api.ddjvu_document_job(self.document.?) orelse return false;
        if (!self.wait(job)) return false;
        const count = api.ddjvu_document_get_pagenum(self.document.?);
        if (count <= 0 or count > max_pages) return false;
        self.pages = @intCast(count);
        success = true;
        return true;
    }

    pub fn close(self: *Document) void {
        if (self.api) |api| {
            if (self.document) |doc| {
                releaseJob(api, api.ddjvu_document_job(doc) orelse @ptrCast(doc));
            }
            if (self.context) |ctx| api.ddjvu_context_release(ctx);
        }
        self.* = .{};
    }

    // Consume all asynchronous messages, not just the first DOCINFO/PAGEINFO.
    // Errors may precede the terminal job status. Each context belongs to just
    // one Document, so an ERROR message cannot concern another open image.
    fn drainMessages(self: *const Document) bool {
        const api = self.api.?;
        var ok = true;
        while (api.ddjvu_message_peek(self.context.?)) |message| {
            if (message.tag == 0) ok = false; // DDJVU_ERROR
            api.ddjvu_message_pop(self.context.?);
        }
        return ok;
    }

    fn wait(self: *const Document, job: *Job) bool {
        const api = self.api.?;
        const start = w.c.GetTickCount();
        while (true) {
            if (!self.drainMessages()) return false;
            const status = api.ddjvu_job_status(job);
            if (status >= job_ok) return status == job_ok and self.drainMessages();
            // message_wait has no timeout. Polling also handles malformed files
            // which stop producing messages; GetTickCount wraps safely on XP.
            if (w.c.GetTickCount() -% start >= decode_timeout_ms) return false;
            w.c.Sleep(10);
        }
    }

    pub fn render(self: *Document, index: u32) ?Raster {
        const api = self.api orelse return null;
        const doc = self.document orelse return null;
        if (index >= self.pages or index > std.math.maxInt(c_int)) return null;
        const page = api.ddjvu_page_create_by_pageno(doc, @intCast(index)) orelse return null;
        // document_job/page_job are exported type casts, never null for a valid
        // object. The pointer fallback also releases an unexpectedly bad job.
        const job = api.ddjvu_page_job(page) orelse {
            releaseJob(api, @ptrCast(page));
            return null;
        };
        defer releaseJob(api, job);
        if (!self.wait(job)) return null;
        const iw = api.ddjvu_page_get_width(page);
        const ih = api.ddjvu_page_get_height(page);
        if (iw <= 0 or ih <= 0) return null;
        var width: u32 = @intCast(iw);
        var height: u32 = @intCast(ih);
        const longest = @max(width, height);
        if (longest > max_side) {
            width = @intCast(@max(1, @as(u64, width) * max_side / longest));
            height = @intCast(@max(1, @as(u64, height) * max_side / longest));
        }
        const pixels = @as(u64, width) * height;
        if (width > max_side or height > max_side or pixels == 0 or pixels > max_pixels) return null;
        const buffer = allocator.alloc(u8, @intCast(pixels * 4)) catch return null;
        var success = false;
        defer if (!success) allocator.free(buffer);
        @memset(buffer, 255);
        // DDJVU_FORMAT_RGBMASK32, native little-endian B,G,R,unused bytes.
        // PixelFormat32bppRGB in GDI+ ignores the unused byte (no alpha).
        var masks = [_]c_uint{ 0x00ff0000, 0x0000ff00, 0x000000ff };
        const format = api.ddjvu_format_create(3, masks.len, &masks) orelse return null;
        defer api.ddjvu_format_release(format);
        api.ddjvu_format_set_row_order(format, 1);
        api.ddjvu_format_set_y_direction(format, 1);
        const rect = Rect{ .w = width, .h = height };
        if (api.ddjvu_page_render(page, 0, &rect, &rect, format, width * 4, buffer.ptr) == 0) return null;
        if (!self.drainMessages()) return null;
        success = true;
        return .{ .pixels = buffer, .width = width, .height = height };
    }
};

fn releaseJob(api: *const Api, job: *Job) void {
    if (api.ddjvu_job_status(job) < job_ok) api.ddjvu_job_stop(job);
    api.ddjvu_job_release(job);
}
