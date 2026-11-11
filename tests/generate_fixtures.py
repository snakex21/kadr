"""Development-only fixtures. Requires Pillow; never used by Kadr.exe."""
from pathlib import Path
from PIL import Image, ImageDraw

out = Path(__file__).resolve().parent / 'fixtures'
out.mkdir(exist_ok=True)
a = Image.new('RGB', (800, 500), '#18485b')
d = ImageDraw.Draw(a)
d.rectangle((40, 40, 759, 459), outline='#66d6bf', width=8)
d.ellipse((300, 110, 500, 310), fill='#f4c06b')
d.polygon([(80, 420), (290, 220), (440, 420)], fill='#9bd8cb')
d.polygon([(310, 420), (570, 180), (730, 420)], fill='#3c9b93')
d.text((64, 62), 'KADR / 800 x 500', fill='white')
a.save(out / '01-krajobraz.png')
a.save(out / '02-zdjecie.jpg', quality=93, dpi=(300, 300))
a.save(out / '03-obraz.bmp')
a.save(out / '04-strony.tiff', save_all=True, append_images=[a.transpose(Image.Transpose.ROTATE_90)])
frames = []
for i, color in enumerate(('#e06070', '#66d6bf', '#f4c06b')):
    frame = Image.new('RGB', (320, 200), '#21262d')
    draw = ImageDraw.Draw(frame)
    draw.rectangle((20 + i*70, 50, 100 + i*70, 150), fill=color)
    draw.text((15, 15), f'GIF / frame {i+1}', fill='white')
    frames.append(frame)
frames[0].save(out / '05-animacja.gif', save_all=True, append_images=frames[1:], duration=[120, 240, 360], loop=0, disposal=2)
alpha = Image.new('RGBA', (320, 240), (0, 0, 0, 0))
ImageDraw.Draw(alpha).ellipse((30, 20, 290, 220), fill=(102, 214, 191, 150))
alpha.save(out / '06-przezroczystosc.png')
a.resize((128, 128)).save(out / '07-ikona.ico')
a.save(out / '08-zażółć-gęślą.png')
(out / 'broken.png').write_bytes(b'not an image')
print('Fixtures:', out)
