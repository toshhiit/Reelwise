"""Логотип Reelwise: крючок и волна на тёмно-бирюзовом скруглённом квадрате.

Рисунок (крючок + волна) рисуется на отдельном слое, затем по его реальным границам
ставится ровно по центру плитки — и по горизонтали, и по вертикали.
"""
from PIL import Image, ImageDraw
import math

S = 1024                      # рисуем крупно и уменьшаем — так края гладкие
WHITE = (240, 246, 247, 255)
ACC = (110, 214, 200, 255)


def tile():
    grad = Image.new('RGBA', (S, S))
    top, bot = (26, 80, 88), (14, 36, 46)
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / (S - 1)
        gd.line([(0, y), (S, y)], fill=tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)) + (255,))
    mask = Image.new('L', (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.23), fill=255)
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    out.paste(grad, (0, 0), mask)
    return out


def mark():
    """Крючок и волна на прозрачном слое (положение потом центрируется)."""
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    W = int(S * 0.072)                       # толщина линии
    R = int(S * 0.15)                        # радиус изгиба (по оси линии)
    cx = int(S * 0.60)                       # цевьё
    by = int(S * 0.56)                       # центр изгиба по высоте
    bx = cx - R                              # центр изгиба по горизонтали
    tx = bx - R                              # жало — зеркально цевью относительно центра изгиба
    # ушко — кольцо, его центр на оси цевья
    er = int(S * 0.062)
    ey = int(S * 0.17)
    d.ellipse([cx - er, ey - er, cx + er, ey + er], outline=WHITE, width=int(W * 0.55))
    # цевьё: от низа кольца до центра изгиба
    d.rectangle([cx - W // 2, ey + er - int(W * 0.3), cx + W // 2, by], fill=WHITE)
    # изгиб — нижняя половина кольца
    d.arc([bx - R - W // 2, by - R - W // 2, bx + R + W // 2, by + R + W // 2], start=0, end=180, fill=WHITE, width=W)
    # жало: вертикально вверх до высоты ty, затем остриё
    ty = int(S * 0.43)
    d.rectangle([tx - W // 2, ty, tx + W // 2, by], fill=WHITE)
    d.polygon([(tx - W // 2, ty + 1), (tx + W // 2, ty + 1), (tx, ty - int(W * 1.25))], fill=WHITE)
    # бородка внутрь (к цевью), симметричный треугольник
    d.polygon([(tx + W // 2 - 1, ty - int(W * 0.35)), (tx + int(W * 1.3), ty + int(W * 0.85)),
               (tx + W // 2 - 1, ty + int(W * 0.75))], fill=WHITE)
    return im


def wave():
    """Волна: гладкая линия — кружки, наложенные через ~1 px (у ломаной PIL зубчатые края)."""
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    wy, amp, x0, x1 = int(S * 0.80), int(S * 0.032), S * 0.18, S * 0.82   # симметрично относительно S/2
    r = int(S * 0.072 * 0.68) / 2
    n = 1400
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        y = wy - amp * math.sin(i / n * 2 * math.pi * 1.5)
        d.ellipse([x - r, y - r, x + r, y + r], fill=ACC)
    return im


def logo():
    t = tile()
    h, w = mark(), wave()
    hl, ht, hr, hb = h.getbbox()
    wl, wt, wr, wb = w.getbbox()
    # крючок — ровно над серединой волны; вся композиция — ровно по центру плитки по высоте
    hx = round((wl + wr) / 2 - (hl + hr) / 2)
    top, bot = min(ht, wt), max(hb, wb)
    dy = round(S / 2 - (top + bot) / 2)
    dx = round(S / 2 - (wl + wr) / 2)
    t.alpha_composite(w, (dx, dy))
    t.alpha_composite(h, (dx + hx, dy))
    return t, (min(hl + hx, wl) + dx, top + dy, max(hr + hx, wr) + dx, bot + dy)


if __name__ == '__main__':
    big, box = logo()
    print('рисунок после центрирования:', box, 'поля слева/справа', box[0], S - box[2],
          'сверху/снизу', box[1], S - box[3])
    im256 = big.resize((256, 256), Image.LANCZOS)
    im256.save('reelwise_256.png')
    big.resize((96, 96), Image.LANCZOS).save('logo96.png')
    big.resize((44, 44), Image.LANCZOS).save('logo44.png')
    im256.save('reelwise.ico', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    sheet = Image.new('RGBA', (620, 300), (20, 24, 31, 255))
    sheet.paste(im256, (20, 22), im256)
    # тонкие направляющие по центру большой плитки — видно, ровно ли
    g = ImageDraw.Draw(sheet)
    g.line([(148, 22), (148, 278)], fill=(255, 90, 90, 140))
    g.line([(20, 150), (276, 150)], fill=(255, 90, 90, 140))
    for i, s in enumerate((96, 48, 32, 16)):
        tt = big.resize((s, s), Image.LANCZOS)
        sheet.paste(tt, (300 + i * 80, 120 - s // 2), tt)
    sheet.save('preview.png')


def switch(on, bg=(22, 27, 34), w=44, h=24, k=8):
    """Тумблер для окна: фон окна запечён (у Picture в AHK прозрачность ненадёжна)."""
    W, H = w * k, h * k
    im = Image.new('RGB', (W, H), bg)
    d = ImageDraw.Draw(im)
    track = (92, 200, 184) if on else (46, 55, 68)
    d.rounded_rectangle([0, 0, W - 1, H - 1], radius=H // 2, fill=track)
    r = int(H * 0.36)
    cx = W - H // 2 if on else H // 2
    knob = (240, 246, 247) if on else (139, 150, 165)
    d.ellipse([cx - r, H // 2 - r, cx + r, H // 2 + r], fill=knob)
    return im.resize((w, h), Image.LANCZOS)


if __name__ == '__main__':
    switch(True).save('switch_on.png')
    switch(False).save('switch_off.png')
