from PIL import Image
import struct

PNG = 'assets/icons/ico.png'
ICO = 'windows/runner/resources/app_icon.ico'
SIZES = [256, 128, 64, 48, 32, 16]

def auto_crop(img):
    """Find content bounds, center in largest square, with small padding."""
    px = img.load()
    w, h = img.size
    L, T, R, B = w, h, 0, 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 10 and r < 250 and g < 250 and b < 250:
                L = min(L, x); T = min(T, y)
                R = max(R, x); B = max(B, y)
    # Add 4px padding
    pad = 4
    L, T = max(0, L - pad), max(0, T - pad)
    R, B = min(w - 1, R + pad), min(h - 1, B + pad)
    cw, ch = R - L + 1, B - T + 1
    side = max(cw, ch)
    # Center content in square
    cx, cy = (L + R) // 2, (T + B) // 2
    half = side // 2
    x0, y0 = max(0, cx - half), max(0, cy - half)
    x1, y1 = min(w, x0 + side), min(h, y0 + side)
    return img.crop((x0, y0, x1, y1))

def rgba_to_bmp(img, size):
    if size != img.size[0]:
        img = img.resize((size, size), Image.LANCZOS)
    w, h = size, size
    rs = ((w * 32 + 31) // 32) * 4
    bmp = bytearray(40 + rs * h)
    struct.pack_into('<IiiHHIIiiII', bmp, 0, 40, w, h * 2, 1, 32, 0, rs * h, 0, 0, 0, 0)
    px = img.tobytes()
    for y in range(h):
        for x in range(w):
            si = ((h - 1 - y) * w + x) * 4
            di = 40 + y * rs + x * 4
            bmp[di:di+4] = bytes([px[si+2], px[si+1], px[si], px[si+3]])
    return bytes(bmp)

def main():
    src = Image.open(PNG).convert('RGBA')
    print(f'Original: {src.size}')

    cropped = auto_crop(src)
    print(f'Cropped:  {cropped.size}')

    ico = bytearray(struct.pack('<HHH', 0, 1, len(SIZES)))
    bmps = []
    off = 6 + 16 * len(SIZES)
    for s in SIZES:
        b = rgba_to_bmp(cropped, s)
        bmps.append(b)
        sz = 0 if s >= 256 else s
        ico += struct.pack('<BBBBHHII', sz, sz, 0, 0, 1, 32, len(b), off)
        off += len(b)
    for b in bmps:
        ico += b
    with open(ICO, 'wb') as f:
        f.write(ico)
    print(f'ICO:     {ICO} ({", ".join(f"{s}x{s}" for s in SIZES)})')

if __name__ == '__main__':
    main()
