from pathlib import Path
from PIL import Image
out=Path(__file__).resolve().parent/'fixtures'
out.mkdir(exist_ok=True)
for w,h in [(1,1),(2,3),(8,8)]:
    image=Image.new('RGBA',(w,h))
    image.putdata([((x*71+30)%256,(y*89+50)%256,((x+y)*47+70)%256,255 if (x+y)%3 else 180) for y in range(h) for x in range(w)])
    image.save(out/f'{w}x{h}.png')
print('Prepared 1x1, 2x3, 8x8 PNG regression fixtures')
