import sys, json
from PIL import Image, ImageDraw, ImageFont, ImageFilter
W,H=1320,2868
SH='marketing/out/shots/'
OUT='marketing/out/custom-product-pages/'
AV='/System/Library/Fonts/Avenir Next.ttc'
def font(size, bold=True):
    return ImageFont.truetype(AV, size, index=8 if bold else 7)  # Heavy / DemiBold-ish
def grad():
    top=(54,24,110); bot=(196,58,104)
    g=Image.new('RGB',(1,H))
    for y in range(H):
        t=y/(H-1); g.putpixel((0,y),tuple(int(top[i]+(bot[i]-top[i])*t) for i in range(3)))
    return g.resize((W,H))
def wrap(d, text, f, maxw):
    words=text.split(); lines=[]; cur=''
    for w in words:
        t=(cur+' '+w).strip()
        if d.textlength(t,font=f)<=maxw: cur=t
        else: lines.append(cur); cur=w
    lines.append(cur); return lines
def make(shot, title, sub, name):
    im=grad(); d=ImageDraw.Draw(im)
    ft=font(112); fs=font(58,False)
    y=190
    for line in wrap(d,title,ft,W-160):
        d.text((W/2,y),line,font=ft,fill='white',anchor='ma'); y+=132
    y+=20
    for line in wrap(d,sub,fs,W-110):
        d.text((W/2,y),line,font=fs,fill=(255,225,240),anchor='ma'); y+=76
    # phone screenshot, scaled, rounded corners + shadow
    top=max(y+70, 760)
    sc=Image.open(SH+shot+'.png').convert('RGB')
    h=H-top+160  # let it run off the bottom edge
    w=int(sc.width*h/sc.height)
    if w>W-170: w=W-170; h=int(sc.height*w/sc.width)
    sc=sc.resize((w,h),Image.LANCZOS)
    r=90
    mask=Image.new('L',(w,h),0); ImageDraw.Draw(mask).rounded_rectangle((0,0,w,h),r,fill=255)
    x=(W-w)//2
    sh=Image.new('RGBA',(W,H),(0,0,0,0)); ImageDraw.Draw(sh).rounded_rectangle((x-6,top+24,x+w+6,top+h+30),r,fill=(0,0,0,110))
    sh=sh.filter(ImageFilter.GaussianBlur(28))
    im=Image.alpha_composite(im.convert('RGBA'),sh).convert('RGB')
    border=Image.new('RGB',(w+24,h+24),(20,20,24)); bm=Image.new('L',(w+24,h+24),0); ImageDraw.Draw(bm).rounded_rectangle((0,0,w+24,h+24),r+12,fill=255)
    im.paste(border,(x-12,top-12),bm)
    im.paste(sc,(x,top),mask)
    im.save(OUT+name+'.png')
    return OUT+name+'.png'
if __name__=='__main__':
    spec=json.load(open(sys.argv[1]))
    for s in spec: print(make(s['shot'],s['title'],s['sub'],s['name']))
