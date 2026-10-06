"""Product page header (3840x1646) and search-results (3840x2560) creative assets.
Run from the repo root after capturing marketing/out/shots/ (see README)."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
SH='marketing/out/shots/'; OUT='marketing/out/creative-assets/'
AV='/System/Library/Fonts/Avenir Next.ttc'
flag=Image.open('Flag_of_Haiti.svg.png').convert('RGBA')
TOP=(54,24,110); BOT=(196,58,104)

def grad(W,H):
    small=Image.new('RGB',(64,64)); px=small.load()
    for y in range(64):
        for x in range(64):
            t=(x/63)*0.45+(y/63)*0.55
            px[x,y]=tuple(int(TOP[i]+(BOT[i]-TOP[i])*t) for i in range(3))
    return small.resize((W,H),Image.BICUBIC)

def phone(im, name, cx, top, h, angle=0):
    shot=Image.open(SH+name+'.png').convert('RGB')
    w=int(shot.width*h/shot.height); sc=shot.resize((w,h),Image.LANCZOS); r=int(w*0.12); b=int(w*0.025)
    card=Image.new('RGBA',(w+2*b,h+2*b),(0,0,0,0))
    m=Image.new('L',card.size,0); ImageDraw.Draw(m).rounded_rectangle((0,0,card.width-1,card.height-1),r+b,fill=255)
    card.paste((18,18,22,255),(0,0),m)
    m2=Image.new('L',(w,h),0); ImageDraw.Draw(m2).rounded_rectangle((0,0,w-1,h-1),r,fill=255)
    card.paste(sc,(b,b),m2)
    if angle: card=card.rotate(angle,expand=True,resample=Image.BICUBIC)
    sh=Image.new('RGBA',im.size,(0,0,0,0)); x=cx-card.width//2
    sh.paste((0,0,0,130),(x+20,top+40),card); sh=sh.filter(ImageFilter.GaussianBlur(50))
    im=Image.alpha_composite(im.convert('RGBA'),sh); im.paste(card,(x,top),card); return im

def put_flag(im, cx, cy, fw, angle):
    f=flag.resize((fw,int(flag.height*fw/flag.width)),Image.LANCZOS).rotate(angle,expand=True,resample=Image.BICUBIC)
    sh=Image.new('RGBA',im.size,(0,0,0,0)); sh.paste((0,0,0,110),(cx-f.width//2+20,cy-f.height//2+30),f)
    im=Image.alpha_composite(im.convert('RGBA'),sh.filter(ImageFilter.GaussianBlur(36)))
    im.paste(f,(cx-f.width//2,cy-f.height//2),f); return im

# Header: no text (one image for every language); focal content in the centre.
W,H=3840,1646
im=grad(W,H).convert('RGBA')
im=put_flag(im, 1250, 820, 1000, -7)
im=phone(im,'medical',2150,130,1400,angle=3)
im=phone(im,'phrasebook-Greetings',2720,170,1400,angle=-3)
im.convert('RGB').save(OUT+'header-3840x1646.png')

# Search results: localized headline + three phones.
def search(lang, title):
    W,H=3840,2560
    im=grad(W,H).convert('RGBA'); d=ImageDraw.Draw(im)
    f=ImageFont.truetype(AV,190,index=8)
    d.text((W/2,230),title,font=f,fill='white',anchor='ma')
    for name,cx,top,a in [('family',1130,640,5),('medical',1920,560,0),('phrasebook-Medical',2710,640,-5)]:
        im=phone(im,name,cx,top,1850,angle=a)
    im.convert('RGB').save(OUT+f'search-{lang}-3840x2560.png')
search('en','Speak it. Hear it in Kreyòl.')
search('fr','Parlez. Entendez-le en kreyòl.')
