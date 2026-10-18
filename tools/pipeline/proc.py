# Process a stage's 7 raw ChatGPT images into game assets.
# usage: proc.py RAWDIR OUTDIR  (RAWDIR has img0..img6 png in order 1..7)
import sys, numpy as np
from PIL import Image
raw, out = sys.argv[1], sys.argv[2]
rng = np.random.default_rng(5)

def load(i): return np.asarray(Image.open(f'{raw}/img{i}.png').convert('RGB')).astype(float)

def grid_n(a, axis, lo, hi):
    L = a.shape[1] if axis == 1 else a.shape[0]
    d = np.abs(np.diff(a, axis=axis)).sum(axis=(0, 2) if axis == 1 else (1, 2)); m = d.mean()
    best = []
    for n in range(lo, hi + 1):
        e = np.round(np.arange(1, n) * L / n).astype(int) - 1
        e = e[(e >= 0) & (e < len(d))]
        best.append((d[e].mean() / m, n))
    best.sort(reverse=True)
    top = best[0][0]
    return max(n for s, n in best if s >= 0.9 * top)   # finest grid near the best score

def blocks(a, nx, ny):
    H, W, _ = a.shape; fx, fy = W / nx, H / ny
    o = np.zeros((ny, nx, 3))
    for j in range(ny):
        y0 = int(j * fy + fy * .3); y1 = max(y0 + 1, int(j * fy + fy * .7))
        for i in range(nx):
            x0 = int(i * fx + fx * .3); x1 = max(x0 + 1, int(i * fx + fx * .7))
            o[j, i] = np.median(a[y0:y1, x0:x1].reshape(-1, 3), axis=0)
    return o

def key(o):
    r, g, b = o[..., 0], o[..., 1], o[..., 2]
    grn = (g > 140) & (g > r + 60) & (g > b + 60)
    al = np.where(grn, 0, 255)
    # remove the green fringe: edge pixels (next to transparent) that lean green
    from scipy import ndimage as _nd
    for _ in range(2):
        edge = (al > 0) & _nd.binary_dilation(al == 0, structure=np.ones((3, 3)))
        fr = edge & (g > np.maximum(r, b) + 18)
        al = np.where(fr, 0, al)
    return np.dstack([o, al]).astype(np.uint8)

def seam_x(img, frac=0.08):
    # dithered cross-fade of the right edge into the left so the strip tiles left-to-right
    H, W, C = img.shape; o = max(2, int(W * frac))
    res = img[:, :W - o].copy()
    for k in range(o):
        t = (k + 0.5) / o   # 0 near seam (use right part), 1 inside (use left part)
        pick = rng.random(H) < t
        res[:, k][~pick] = img[:, W - o + k][~pick]
    return res

def seam_pano(img, maxfrac=0.12, bw=0.025):
    # cut where the right side best matches the left edge, then a narrow dithered blend
    H, W, C = img.shape; f = img.astype(np.float32)
    ref = f[:, :4]
    best, bo = 1e18, 0
    for o in range(0, int(W * maxfrac)):
        cand = f[:, W - o - 4:W - o] if o else f[:, W - 4:W]
        # compare the columns just before the cut to the columns just before x=0 (wrap) -> use left cols vs cut cols
        d = np.abs(f[:, W - o - 4:W - o] - ref).mean() if o else np.abs(f[:, W-4:W] - ref).mean()
        if d < best: best, bo = d, o
    # the image wraps at W-bo: columns [W-bo-4, W-bo) should resemble [0,4) shifted; simple: crop to W-bo-4 so next col is ref
    cut = W - bo - 4 if bo else W
    res = img[:, :cut].copy() if bo else img.copy()
    return seam_x(res, bw)

def seam_y(img, frac=0.08):
    return np.transpose(seam_x(np.transpose(img, (1, 0, 2)), frac), (1, 0, 2))

def save(arr, name): Image.fromarray(arr.astype(np.uint8)).save(f'{out}/{name}'); print(name, arr.shape[1], 'x', arr.shape[0])

import os; os.makedirs(out, exist_ok=True)
# panoramas: half resolution like Verdant Field (1086x362), keyed, seamless
for i, name, k in [(0, 'sky.png', False), (1, 'far.png', True), (2, 'hor.png', True)]:
    a = load(i); H, W, _ = a.shape
    o = blocks(a, W // 2, H // 2)
    img = key(o) if k else np.dstack([o, np.full(o.shape[:2], 255)])
    img = seam_pano(img)
    img = np.asarray(Image.fromarray(img.astype(np.uint8)).resize((1086, 362), Image.NEAREST))
    save(img, name)
# ground + rock textures: true pixel grid, seamless both ways
for i, name, (lo, hi) in [(3, 'ground.png', (90, 220)), (5, 'rock.png', (110, 260))]:
    a = load(i)
    n = grid_n(a, 1, lo, hi)
    o = blocks(a, n, n)
    img = np.dstack([o, np.full(o.shape[:2], 255)])
    img = seam_y(seam_x(img, 0.1), 0.1)
    save(img, name)
# path strip: pixel grid, keyed, seamless left-right
a = load(4); H, W, _ = a.shape
n = grid_n(a, 1, 200, 420); ny = max(1, round(n * H / W))
img = seam_x(key(blocks(a, n, ny)))
save(img, 'path.png')
# props: 4 quarters, keyed and trimmed, true grid
a = load(6); H, W, _ = a.shape
n = grid_n(a, 1, 160, 400); ny = round(n * H / W)
o = key(blocks(a, n, ny))
q = o.shape[1] // 4
for k in range(4):
    part = Image.fromarray(o[:, k * q:(k + 1) * q])
    bb = part.getbbox()
    if bb: part = part.crop(bb)
    part.save(f'{out}/prop{k + 1}.png'); print(f'prop{k+1}.png', part.size)

# --- better prop split: connected objects, small bits join the nearest big object ---
from scipy import ndimage
al = o[..., 3] > 0
lab, nlab = ndimage.label(ndimage.binary_dilation(al, iterations=2), structure=np.ones((3, 3)))
lab = lab * al
sizes = ndimage.sum(al, lab, range(1, nlab + 1))
order = np.argsort(-sizes)
big = [int(i) + 1 for i in order[:4]]
cent = {l: np.array(ndimage.center_of_mass(lab == l)) for l in range(1, nlab + 1)}
assign = np.zeros_like(lab)
for l in range(1, nlab + 1):
    if l in big:
        tgt = l
    else:
        tgt = min(big, key=lambda b: np.linalg.norm(cent[l] - cent[b]))
    assign[lab == l] = tgt
big.sort(key=lambda b: cent[b][1])
for k, b in enumerate(big):
    m = assign == b
    part = o.copy(); part[~m, 3] = 0
    im = Image.fromarray(part); bb = im.getbbox(); im = im.crop(bb)
    im.save(f'{out}/prop{k + 1}.png'); print(f'prop{k+1}.png (split)', im.size)
