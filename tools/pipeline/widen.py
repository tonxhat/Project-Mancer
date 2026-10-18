# widen.py IN OUT NEW_H : grow a path strip vertically, filling with inner road rows (pixels stay square)
import sys, numpy as np
from PIL import Image
src, dst, nh = sys.argv[1], sys.argv[2], int(sys.argv[3])
rng = np.random.default_rng(7)
a = np.asarray(Image.open(src).convert('RGBA')).copy()
H, W, _ = a.shape
cov = (a[:, :, 3] > 127).mean(1)
core = np.where(cov > 0.97)[0]; t, b = core.min(), core.max() + 1
# inner band = middle 50% of the solid road (no edge grass/snow/rubble)
q = (b - t) // 4; it, ib = t + q, b - q
band = a[it:ib]; bh = band.shape[0]
E = nh - H; c = (t + b) // 2
bl = max(2, bh // 4)                     # dithered blend rows at each join
# build filler: band copies, each rolled sideways, blended into each other
fill = np.zeros((E + 2 * bl, W, 4), np.uint8); y = 0; k = 1
while y < fill.shape[0]:
    blk = np.roll(band, (k * W) // 3 + k * 17, axis=1); k += 1
    n = min(bh, fill.shape[0] - y)
    if y == 0:
        fill[:n] = blk[:n]
    else:  # overlap previous block by bl rows with dither
        o = min(bl, y)
        for r in range(o):
            pick = rng.random(W) < (r + .5) / o
            fill[y - o + r][pick] = blk[r][pick]
        n2 = min(bh - o, fill.shape[0] - y)
        fill[y:y + n2] = blk[o:o + n2]; n = n2
    y += n
top, bot = a[:c].copy(), a[c:].copy()
# dither-blend filler edges into the original halves
for r in range(bl):
    tt = (r + .5) / bl
    p = rng.random(W) < tt;  top[c - bl + r][p] = fill[r][p]
    p = rng.random(W) < 1 - tt; bot[r][p] = fill[E + bl + r][p]
out = np.concatenate([top, fill[bl:E + bl], bot])
Image.fromarray(out).save(dst)
print(src, (W, H), '->', out.shape[1], out.shape[0])
