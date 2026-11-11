"""Original Kadr artwork; build-time only. Pillow, no external assets."""
from pathlib import Path
from PIL import Image, ImageDraw
root = Path(__file__).resolve().parent.parent
out = root / 'assets'
out.mkdir(exist_ok=True)
scale=4
im=Image.new('RGBA',(256*scale,256*scale))
d=ImageDraw.Draw(im)
def box(xy): return tuple(int(v*scale) for v in xy)
d.rounded_rectangle(box((6,6,250,250)),radius=58*scale,fill='#147d66')
d.rounded_rectangle(box((46,57,210,199)),radius=16*scale,fill='#f9fbed')
d.rounded_rectangle(box((58,69,198,187)),radius=9*scale,fill='#e6efdc')
d.ellipse(box((151,86,178,113)),fill='#efb958')
d.polygon([box((60,184)),box((111,116)),box((157,184))],fill='#69ad93')
d.polygon([box((111,184)),box((157,138)),box((196,184))],fill='#237c65')
im=im.resize((256,256),Image.Resampling.LANCZOS)
im.save(out/'kadr.png')
im.save(out/'kadr.ico',format='ICO',sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)],bitmap_format='bmp')
print('Original icon:',out/'kadr.ico')
