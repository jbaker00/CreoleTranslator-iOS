#!/usr/bin/env python3
"""WCAG contrast audit for every foreground/background pairing in the app.

Run after any color change: python3 scripts/contrast_audit.py  (exit 1 on failure)
Text needs 4.5:1, large text / icons / progress bars 3:1. Values mirror the
Palette extension in ContentView.swift (appAccent etc.) and Apple's system
colors. Confirmed against rendered simulator pixels on iOS 26.5 — note iOS 26
ignores the AccentColor asset for .accentColor, so views use Color.appAccent. Add a row here when a view gets a new color pairing.
"""
import sys

def hx(h, a=1.0):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

def over(fg, bg):
    a = fg[3]
    return tuple(round(fg[i] * a + bg[i] * (1 - a)) for i in range(3)) + (1,)

def tint(c, a):
    return c[:3] + (a,)

def lum(c):
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    return 0.2126 * ch(c[0]) + 0.7152 * ch(c[1]) + 0.0722 * ch(c[2])

def ratio(fg, bg):
    l1, l2 = lum(over(fg, bg)), lum(bg)
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

MODES = {
    'light': dict(
        # system
        bg=hx('FFFFFF'), bg2=hx('F2F2F7'), bg3=hx('FFFFFF'), cell=hx('FFFFFF'),
        label=hx('000000'), orange=hx('FF9500'),
        grad=[(92, 46, 184, 1), (178, 61, 112, 1)],  # ContentView bgColors, light
        # app palette
        accent=hx('0060DF'), fill=hx('0060DF'), sec=hx('636366'), err=hx('D70015'),
        warn=hx('B34700'), yel=hx('856200'), rec=hx('D70015')),
    'dark': dict(
        bg=hx('000000'), bg2=hx('1C1C1E'), bg3=hx('2C2C2E'), cell=hx('1C1C1E'),
        label=hx('FFFFFF'), orange=hx('FF9F0A'),
        grad=[hx('1C1C1E'), hx('000000')],
        accent=hx('64B0FF'), fill=hx('0A60D0'), sec=hx('AEAEB2'), err=hx('FF6961'),
        warn=hx('FFB340'), yel=hx('FFD60A'), rec=hx('D70015')),
}
WHITE, BLACK = hx('FFFFFF'), hx('000000')

def rows(S):
    A, card_btn = S['accent'], over(tint(S['accent'], 0.15), S['bg3'])
    return [
        ('Header title / subtitle / status / history count (white on gradient)', WHITE, S['grad'], 4.5),
        ('Header circle icons', A, [S['bg2']], 3),
        ('Voice/Type unselected (on SegmentedBacking)', S['label'], [S['bg2']], 4.5),
        ('Record / Switch Direction / auto-detect chip', A, [S['bg2']], 4.5),
        ('Stop Recording (white on red)', WHITE, [S['rec']], 4.5),
        ('Input placeholder', S['sec'], [S['bg2']], 4.5),
        ('Translate enabled (white on fill)', WHITE, [S['fill']], 4.5),
        ('Translate disabled', S['sec'], [S['bg3']], 3),
        ('Card title / result / feedback prompt', S['label'], [S['bg3']], 4.5),
        ('Card placeholder', S['sec'], [S['bg3']], 4.5),
        ('Card speaker + thumbs icons', A, [card_btn], 3),
        ('Card thumb not chosen', S['sec'], [card_btn], 3),
        ('HD chip', A, [over(tint(A, 0.12), S['bg3'])], 4.5),
        ('HD chip empty (black on orange)', BLACK, [S['orange']], 4.5),
        ('Error / warning text', S['err'], [S['bg'], S['bg2'], S['cell']], 4.5),
        ('Warning text', S['warn'], [S['bg'], S['cell']], 4.5),
        ('Recording hint / progress', S['sec'], [S['bg']], 4.5),
        ('Phrasebook chip / speaker / icons', A, [S['bg'], S['bg3']], 4.5),
        ('Secondary text (all screens)', S['sec'], [S['bg'], S['bg2'], S['bg3'], S['cell']], 4.5),
        ('Favorite star / Favorites only', S['yel'], [S['bg2']], 4.5),
        ('History speaker / Show more', A, [S['bg2']], 4.5),
        ('Settings accent / checkmarks', A, [S['cell']], 4.5),
        ('Consent button (white on fill)', WHITE, [S['fill']], 4.5),
    ]

failures = 0
for mode, S in MODES.items():
    for name, fg, bgs, need in rows(S):
        for bg in bgs:
            r = ratio(fg, bg)
            if r < need:
                failures += 1
                print(f'FAIL {mode:5s} {r:5.2f} (need {need}) {name}')
            elif '-v' in sys.argv:
                print(f' ok  {mode:5s} {r:5.2f} (need {need}) {name}')
print(f'{failures} failure(s)')
sys.exit(1 if failures else 0)
