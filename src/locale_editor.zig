// Editor vocabulary, in the same language order as languages.zig. GPL-3.0-or-later.
const std = @import("std");
pub const Key = enum { edit, brightness, contrast, saturation, rotate_left, flip_h, flip_v, crop_hint, memory_hint, unsaved };
const data = [30][10][]const u8{
    // pl
    .{ "Edycja zdjęcia", "Jasność", "Kontrast", "Nasycenie", "Obróć w lewo", "Odbij poziomo", "Odbij pionowo", "Kadrowanie: zaznacz obszar na zdjęciu lub wpisz piksele.", "Zmiany są w pamięci. Plik zmieni się dopiero po zapisaniu.", "Są niezapisane zmiany. Kontynuować bez zapisywania?\n\nAby je zachować, wybierz Anuluj i użyj Zapisz (Ctrl+S) lub Zapisz jako (Ctrl+Shift+S)." },
    // en
    .{ "Edit image", "Brightness", "Contrast", "Saturation", "Rotate left", "Flip horizontal", "Flip vertical", "Crop: select an area on the image or enter pixels.", "Changes are in memory. Save afterwards to change the file.", "There are unsaved changes. Continue without saving?\n\nTo keep them, Cancel and use Save (Ctrl+S) or Save as (Ctrl+Shift+S)." },
    // es
    .{ "Editar imagen", "Brillo", "Contraste", "Saturación", "Girar a la izquierda", "Voltear horizontal", "Voltear vertical", "Recortar: selecciona un área o introduce los píxeles.", "Cambios en memoria. Guarda después para cambiar el archivo.", "Hay cambios sin guardar. ¿Continuar sin guardarlos?\n\nPara conservarlos, cancela y usa Guardar (Ctrl+S) o Guardar como (Ctrl+Shift+S)." },
    // fr
    .{ "Modifier l’image", "Luminosité", "Contraste", "Saturation", "Pivoter à gauche", "Miroir horizontal", "Miroir vertical", "Recadrer : sélectionnez une zone ou saisissez les pixels.", "Modifications en mémoire. Enregistrez ensuite le fichier.", "Des modifications ne sont pas enregistrées. Continuer sans enregistrer ?\n\nPour les conserver, annulez puis utilisez Enregistrer (Ctrl+S) ou Enregistrer sous (Ctrl+Shift+S)." },
    // de
    .{ "Bild bearbeiten", "Helligkeit", "Kontrast", "Sättigung", "Links drehen", "Horizontal spiegeln", "Vertikal spiegeln", "Zuschneiden: Bereich im Bild wählen oder Pixel eingeben.", "Änderungen im Speicher. Datei anschließend speichern.", "Es gibt ungespeicherte Änderungen. Ohne Speichern fortfahren?\n\nZum Behalten abbrechen und Speichern (Ctrl+S) oder Speichern unter (Ctrl+Shift+S) verwenden." },
    // pt
    .{ "Editar imagem", "Brilho", "Contraste", "Saturação", "Girar à esquerda", "Inverter horizontal", "Inverter vertical", "Recortar: selecione uma área ou digite os pixels.", "Alterações na memória. Salve depois para alterar o arquivo.", "Há alterações não salvas. Continuar sem salvar?\n\nPara mantê-las, cancele e use Salvar (Ctrl+S) ou Salvar como (Ctrl+Shift+S)." },
    // ru
    .{ "Редактор фото", "Яркость", "Контраст", "Насыщенность", "Поворот влево", "Отразить по X", "Отразить по Y", "Обрезка: выделите область или введите размеры в пикселях.", "Изменения в памяти. Затем сохраните файл.", "Есть несохранённые изменения. Продолжить без сохранения?\n\nЧтобы сохранить их, нажмите Отмена и выберите Сохранить (Ctrl+S) или Сохранить как (Ctrl+Shift+S)." },
    // uk
    .{ "Редактор фото", "Яскравість", "Контраст", "Насиченість", "Поворот ліворуч", "Відбити по X", "Відбити по Y", "Обрізання: виділіть ділянку або введіть розміри в пікселях.", "Зміни в пам’яті. Потім збережіть файл.", "Є незбережені зміни. Продовжити без збереження?\n\nЩоб зберегти їх, натисніть Скасувати й виберіть Зберегти (Ctrl+S) або Зберегти як (Ctrl+Shift+S)." },
    // it
    .{ "Modifica immagine", "Luminosità", "Contrasto", "Saturazione", "Ruota a sinistra", "Rifletti orizzontale", "Rifletti verticale", "Ritaglio: seleziona un’area o inserisci i pixel.", "Modifiche in memoria. Salva poi per aggiornare il file.", "Ci sono modifiche non salvate. Continuare senza salvare?\n\nPer conservarle, annulla e usa Salva (Ctrl+S) o Salva con nome (Ctrl+Shift+S)." },
    // nl
    .{ "Afbeelding bewerken", "Helderheid", "Contrast", "Verzadiging", "Links draaien", "Horizontaal spiegelen", "Verticaal spiegelen", "Bijsnijden: selecteer een gebied of voer pixels in.", "Wijzigingen in geheugen. Sla het bestand daarna op.", "Er zijn niet-opgeslagen wijzigingen. Doorgaan zonder opslaan?\n\nAnnuleer om ze te behouden en gebruik Opslaan (Ctrl+S) of Opslaan als (Ctrl+Shift+S)." },
    // cs
    .{ "Upravit obrázek", "Jas", "Kontrast", "Sytost", "Otočit vlevo", "Převrátit vodorovně", "Převrátit svisle", "Ořez: vyberte oblast obrázku nebo zadejte pixely.", "Změny jsou v paměti. Soubor pak uložte.", "Existují neuložené změny. Pokračovat bez uložení?\n\nChcete-li je zachovat, zrušte akci a použijte Uložit (Ctrl+S) nebo Uložit jako (Ctrl+Shift+S)." },
    // hu
    .{ "Kép szerkesztése", "Fényerő", "Kontraszt", "Telítettség", "Forgatás balra", "Vízszintes tükrözés", "Függőleges tükrözés", "Kivágás: jelöljön ki egy területet vagy adja meg a pixeleket.", "Módosítások a memóriában. Utána mentse a fájlt.", "Nem mentett módosítások vannak. Folytatja mentés nélkül?\n\nMegtartásukhoz szakítsa meg, majd válassza a Mentés (Ctrl+S) vagy Mentés másként (Ctrl+Shift+S) lehetőséget." },
    // ro
    .{ "Editare imagine", "Luminozitate", "Contrast", "Saturație", "Rotire la stânga", "Oglindire orizontală", "Oglindire verticală", "Decupare: selectați o zonă sau introduceți pixelii.", "Modificări în memorie. Salvați apoi fișierul.", "Există modificări nesalvate. Continuați fără salvare?\n\nPentru a le păstra, anulați și folosiți Salvare (Ctrl+S) sau Salvare ca (Ctrl+Shift+S)." },
    // tr
    .{ "Resmi düzenle", "Parlaklık", "Kontrast", "Doygunluk", "Sola döndür", "Yatay çevir", "Dikey çevir", "Kırpma: resimde alan seçin veya piksel girin.", "Değişiklikler bellekte. Ardından dosyayı kaydedin.", "Kaydedilmemiş değişiklikler var. Kaydetmeden devam edilsin mi?\n\nKorumak için iptal edip Kaydet (Ctrl+S) veya Farklı kaydet (Ctrl+Shift+S) kullanın." },
    // el
    .{ "Επεξεργασία εικόνας", "Φωτεινότητα", "Αντίθεση", "Κορεσμός", "Στροφή αριστερά", "Οριζόντια αναστροφή", "Κάθετη αναστροφή", "Περικοπή: επιλέξτε περιοχή ή εισαγάγετε εικονοστοιχεία.", "Αλλαγές στη μνήμη. Αποθηκεύστε έπειτα το αρχείο.", "Υπάρχουν μη αποθηκευμένες αλλαγές. Συνέχεια χωρίς αποθήκευση;\n\nΓια διατήρηση, ακυρώστε και επιλέξτε Αποθήκευση (Ctrl+S) ή Αποθήκευση ως (Ctrl+Shift+S)." },
    // ar
    .{ "تحرير الصورة", "السطوع", "التباين", "التشبع", "تدوير لليسار", "عكس أفقي", "عكس عمودي", "اقتصاص: حدد مساحة على الصورة أو أدخل البكسلات.", "التغييرات في الذاكرة. احفظ الملف بعد ذلك.", "توجد تغييرات غير محفوظة. هل تريد المتابعة دون حفظ؟\n\nللاحتفاظ بها، ألغِ ثم استخدم حفظ (Ctrl+S) أو حفظ باسم (Ctrl+Shift+S)." },
    // he
    .{ "עריכת תמונה", "בהירות", "ניגודיות", "רוויה", "סיבוב שמאלה", "היפוך אופקי", "היפוך אנכי", "חיתוך: בחר אזור בתמונה או הזן פיקסלים.", "השינויים בזיכרון. לאחר מכן יש לשמור את הקובץ.", "יש שינויים שלא נשמרו. להמשיך ללא שמירה?\n\nכדי לשמור אותם, בטל והשתמש בשמירה (Ctrl+S) או בשמירה בשם (Ctrl+Shift+S)." },
    // hi
    .{ "चित्र संपादन", "चमक", "कंट्रास्ट", "संतृप्ति", "बाएँ घुमाएँ", "क्षैतिज पलटें", "लंबवत पलटें", "काटना: चित्र में क्षेत्र चुनें या पिक्सेल दर्ज करें।", "बदलाव मेमोरी में हैं। फिर फ़ाइल सहेजें।", "बदलाव सहेजे नहीं गए हैं। बिना सहेजे जारी रखें?\n\nउन्हें रखने के लिए रद्द करें और सहेजें (Ctrl+S) या इस रूप में सहेजें (Ctrl+Shift+S) का उपयोग करें।" },
    // bn
    .{ "ছবি সম্পাদনা", "উজ্জ্বলতা", "কনট্রাস্ট", "স্যাচুরেশন", "বামে ঘোরান", "অনুভূমিক উল্টান", "উল্লম্ব উল্টান", "কাটুন: ছবিতে এলাকা বাছুন বা পিক্সেল লিখুন।", "পরিবর্তন মেমরিতে আছে। পরে ফাইল সংরক্ষণ করুন।", "অসংরক্ষিত পরিবর্তন আছে। সংরক্ষণ না করে চালিয়ে যাবেন?\n\nরাখতে হলে বাতিল করে সংরক্ষণ (Ctrl+S) বা নতুন নামে সংরক্ষণ (Ctrl+Shift+S) ব্যবহার করুন।" },
    // ur
    .{ "تصویر میں ترمیم", "چمک", "کنٹراسٹ", "سیرابی", "بائیں گھمائیں", "افقی پلٹائیں", "عمودی پلٹائیں", "تراشنا: تصویر میں حصہ منتخب کریں یا پکسل درج کریں۔", "تبدیلیاں میموری میں ہیں۔ اس کے بعد فائل محفوظ کریں۔", "تبدیلیاں محفوظ نہیں ہوئیں۔ محفوظ کیے بغیر جاری رکھیں؟\n\nانہیں رکھنے کے لیے منسوخ کریں، پھر محفوظ کریں (Ctrl+S) یا بطور محفوظ کریں (Ctrl+Shift+S) استعمال کریں۔" },
    // zh
    .{ "编辑图片", "亮度", "对比度", "饱和度", "向左旋转", "水平翻转", "垂直翻转", "裁剪：在图片上选择区域，或输入像素值。", "更改仅在内存中。之后保存才会修改文件。", "有未保存的更改。是否不保存并继续？\n\n要保留更改，请取消，然后使用保存 (Ctrl+S) 或另存为 (Ctrl+Shift+S)。" },
    // ja
    .{ "画像を編集", "明るさ", "コントラスト", "彩度", "左に回転", "左右反転", "上下反転", "切り抜き：画像で範囲を選ぶかピクセル数を入力。", "変更はメモリ内のみです。後で保存してください。", "未保存の変更があります。保存せずに続行しますか？\n\n変更を残すにはキャンセルし、保存 (Ctrl+S) または名前を付けて保存 (Ctrl+Shift+S) を使ってください。" },
    // ko
    .{ "이미지 편집", "밝기", "대비", "채도", "왼쪽 회전", "좌우 뒤집기", "상하 뒤집기", "자르기: 이미지에서 영역을 선택하거나 픽셀을 입력하세요.", "변경 사항은 메모리에만 있습니다. 나중에 저장하세요.", "저장하지 않은 변경 사항이 있습니다. 저장하지 않고 계속할까요?\n\n유지하려면 취소하고 저장 (Ctrl+S) 또는 다른 이름으로 저장 (Ctrl+Shift+S)을 사용하세요." },
    // id
    .{ "Edit gambar", "Kecerahan", "Kontras", "Saturasi", "Putar ke kiri", "Balik horizontal", "Balik vertikal", "Pangkas: pilih area gambar atau masukkan piksel.", "Perubahan di memori. Simpan sesudahnya untuk mengubah berkas.", "Ada perubahan yang belum disimpan. Lanjutkan tanpa menyimpan?\n\nUntuk menyimpannya, batalkan lalu gunakan Simpan (Ctrl+S) atau Simpan sebagai (Ctrl+Shift+S)." },
    // vi
    .{ "Chỉnh sửa ảnh", "Độ sáng", "Độ tương phản", "Độ bão hòa", "Xoay trái", "Lật ngang", "Lật dọc", "Cắt: chọn vùng trên ảnh hoặc nhập số điểm ảnh.", "Thay đổi ở trong bộ nhớ. Sau đó hãy lưu tệp.", "Có thay đổi chưa lưu. Tiếp tục mà không lưu?\n\nĐể giữ lại, hãy hủy rồi dùng Lưu (Ctrl+S) hoặc Lưu thành (Ctrl+Shift+S)." },
    // th
    .{ "แก้ไขรูปภาพ", "ความสว่าง", "ความเปรียบต่าง", "ความอิ่มสี", "หมุนซ้าย", "พลิกแนวนอน", "พลิกแนวตั้ง", "ครอบตัด: เลือกพื้นที่บนภาพหรือป้อนพิกเซล", "การเปลี่ยนแปลงอยู่ในหน่วยความจำ บันทึกไฟล์ภายหลัง", "มีการเปลี่ยนแปลงที่ยังไม่ได้บันทึก ต้องการดำเนินการต่อโดยไม่บันทึกหรือไม่?\n\nหากต้องการเก็บไว้ ให้ยกเลิกแล้วใช้ บันทึก (Ctrl+S) หรือ บันทึกเป็น (Ctrl+Shift+S)" },
    // fa
    .{ "ویرایش تصویر", "روشنایی", "کنتراست", "اشباع", "چرخش به چپ", "وارونگی افقی", "وارونگی عمودی", "برش: ناحیه‌ای از تصویر را انتخاب کنید یا پیکسل وارد کنید.", "تغییرات در حافظه‌اند. سپس پرونده را ذخیره کنید.", "تغییرات ذخیره‌نشده وجود دارد. بدون ذخیره ادامه می‌دهید؟\n\nبرای نگهداری، لغو کنید و ذخیره (Ctrl+S) یا ذخیره با نام (Ctrl+Shift+S) را به کار ببرید." },
    // ta
    .{ "படத்தைத் திருத்து", "ஒளிர்வு", "மாறுபாடு", "வண்ணச் செறிவு", "இடப்புறம் சுழற்று", "கிடைமட்டமாகத் திருப்பு", "செங்குத்தாகத் திருப்பு", "வெட்டுதல்: படத்தில் பகுதியைத் தேர்ந்தெடுக்கவும் அல்லது பிக்சல்களை உள்ளிடவும்.", "மாற்றங்கள் நினைவகத்தில் உள்ளன. பின்னர் கோப்பைச் சேமிக்கவும்.", "சேமிக்காத மாற்றங்கள் உள்ளன. சேமிக்காமல் தொடரவா?\n\nஅவற்றை வைத்திருக்க, ரத்துசெய்து சேமி (Ctrl+S) அல்லது இவ்வாறு சேமி (Ctrl+Shift+S) பயன்படுத்தவும்." },
    // te
    .{ "చిత్రాన్ని సవరించు", "ప్రకాశం", "కాంట్రాస్ట్", "సంతృప్తత", "ఎడమకు తిప్పు", "అడ్డంగా తిప్పు", "నిలువుగా తిప్పు", "కత్తిరింపు: చిత్రంలో ప్రాంతాన్ని ఎంచుకోండి లేదా పిక్సెల్‌లు నమోదు చేయండి.", "మార్పులు మెమరీలో ఉన్నాయి. తరువాత ఫైల్‌ను సేవ్ చేయండి.", "సేవ్ చేయని మార్పులు ఉన్నాయి. సేవ్ చేయకుండా కొనసాగించాలా?\n\nవాటిని ఉంచడానికి రద్దు చేసి, సేవ్ (Ctrl+S) లేదా ఇలా సేవ్ (Ctrl+Shift+S) వాడండి." },
    // mr
    .{ "चित्र संपादन", "उजळपणा", "कॉन्ट्रास्ट", "संपृक्तता", "डावीकडे फिरवा", "आडवे उलटा", "उभे उलटा", "कापणे: चित्रातील भाग निवडा किंवा पिक्सेल लिहा.", "बदल मेमरीमध्ये आहेत. नंतर फाइल जतन करा.", "जतन न केलेले बदल आहेत. जतन न करता पुढे जायचे?\n\nते ठेवण्यासाठी रद्द करा आणि जतन करा (Ctrl+S) किंवा असे जतन करा (Ctrl+Shift+S) वापरा." },
};
pub fn row(comptime key: Key) [30][]const u8 {
    var result: [30][]const u8 = undefined;
    for (data, 0..) |pack, index| result[index] = pack[@intFromEnum(key)];
    return result;
}
test "editor phrases cover all 30 languages with valid UTF-8" {
    for (data) |pack| for (pack) |value| {
        try std.testing.expect(value.len > 0);
        try std.testing.expect(std.unicode.utf8ValidateSlice(value));
    };
}
