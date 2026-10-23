#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""《像素机甲对战》像素素材生成器

程序化绘制游戏所需的全部像素图：机甲部件（双阵营配色）、背景图层、特效。
所有素材均按「世界原始分辨率 320x180」的 1 像素比例绘制，运行时由 Godot 整数倍放大。

约定
    机甲以「双脚中心」为原点，面朝右方（+x）绘制；
    关节枢轴：腿/臂 = 顶部中心，躯干 = 底部中心。
    部件尺寸  躯干 16x22 / 四肢 8x14 / 盾 12x18

用法
    python3 tools/gen_assets.py
输出
    assets/ 目录下的 PNG 文件
"""
import os
import random
import math
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets")

random.seed(20261017)

# ---------------------------------------------------------------- 调色板
# O=描边 D=暗部 M=主甲 L=高光 G=能量/发光 W=核心白
PALETTES = {
    "blue": {"O": (12, 15, 24, 255), "D": (36, 54, 84, 255),
             "M": (62, 98, 152, 255), "L": (120, 170, 226, 255),
             "G": (96, 226, 255, 255), "W": (236, 250, 255, 255)},
    "red": {"O": (24, 12, 16, 255), "D": (76, 32, 44, 255),
            "M": (154, 60, 72, 255), "L": (226, 122, 116, 255),
            "G": (255, 122, 84, 255), "W": (255, 238, 226, 255)},
}

# 完美格挡专用：金白色。刻意不用阵营配色，
# 因为它要同时出现在蓝机甲和红机甲身上，必须能从两者的颜色里跳出来。
GUARD_PAL = {"O": (40, 30, 4, 255), "D": (200, 140, 20, 255),
             "M": (255, 196, 40, 255), "L": (255, 226, 120, 255),
             "G": (255, 214, 60, 255), "W": (255, 253, 240, 255)}


# ---------------------------------------------------------------- 绘图格
class Grid:
    """字符像素画布：每个格子存一个调色板键，None 为透明。"""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def clear(self, x, y):
        self.set(x, y, None)

    def rect(self, x, y, w, h, c):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.set(i, j, c)

    def dot(self, pts, c):
        for x, y in pts:
            self.set(x, y, c)

    def opaque(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x] is not None
        return False

    def rim_top(self, colors, light="L"):
        """把轮廓顶面（上方为透明）的像素提亮为高光。"""
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] in colors and not self.opaque(x, y - 1):
                    self.px[y][x] = light

    def shade_bottom(self, colors, dark="D"):
        """把轮廓底面（下方为透明）的像素压暗。"""
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] in colors and not self.opaque(x, y + 1):
                    self.px[y][x] = dark

    def outline(self, c="O", include_diagonal=False):
        """给整个剪影包一圈 1 像素描边。"""
        nb = ((1, 0), (-1, 0), (0, 1), (0, -1))
        if include_diagonal:
            nb += ((1, 1), (1, -1), (-1, 1), (-1, -1))
        paint = {}
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x] is None and any(self.opaque(x + a, y + b) for a, b in nb):
                    paint[(x, y)] = c
        for (x, y), v in paint.items():
            self.px[y][x] = v

    def to_image(self, pal):
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        ld = im.load()
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y][x]
                if c:
                    ld[x, y] = pal[c]
        return im


def save(im, name):
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)
    print("  ->", os.path.relpath(path, ROOT))


# ---------------------------------------------------------------- 机甲部件
def part_torso(pal):
    g = Grid(16, 22)
    g.rect(5, 0, 6, 5, "M")     # 头部装甲
    g.rect(6, 1, 4, 3, "G")     # 单眼面罩
    g.rect(6, 5, 4, 2, "D")     # 颈部
    g.rect(4, 7, 8, 6, "M")     # 胸腔上段
    g.rect(3, 9, 10, 4, "M")    # 胸腔侧扩
    g.rect(2, 9, 1, 3, "D")     # 前侧散热
    g.rect(7, 10, 2, 3, "G")    # 动力核心
    g.rect(5, 13, 6, 3, "D")    # 腰部
    g.rect(4, 16, 8, 4, "M")    # 骨盆装甲
    g.rect(6, 20, 4, 2, "D")    # 裆部关节
    g.rim_top(("M", "D"))
    g.shade_bottom(("M", "D"), "D")
    g.rect(7, 10, 2, 3, "G")    # 核心压住明暗处理
    g.rect(6, 1, 4, 3, "G")
    g.outline("O")
    return g.to_image(pal)


def part_arm(pal):
    g = Grid(8, 14)
    g.rect(1, 0, 6, 1, "M")     # 肩甲顶
    g.rect(0, 1, 8, 5, "M")     # 肩甲
    g.rect(2, 6, 4, 4, "D")     # 上臂
    g.rect(1, 10, 6, 3, "M")    # 前臂
    g.rect(5, 12, 3, 2, "D")    # 炮座
    g.rim_top(("M", "D"))
    g.shade_bottom(("M", "D"), "D")
    g.rect(5, 12, 3, 1, "G")    # 炮口能量
    g.outline("O")
    return g.to_image(pal)


def part_leg(pal):
    g = Grid(8, 14)
    g.rect(2, 0, 4, 3, "D")     # 髋关节
    g.rect(1, 3, 6, 4, "M")     # 大腿
    g.rect(2, 7, 4, 2, "D")     # 膝关节
    g.rect(2, 9, 4, 3, "M")     # 小腿
    g.rect(0, 12, 8, 2, "M")    # 脚掌
    g.rim_top(("M", "D"))
    g.shade_bottom(("M", "D"), "D")
    g.rect(4, 13, 4, 1, "D")    # 脚尖
    g.outline("O")
    return g.to_image(pal)


def part_shield(pal):
    g = Grid(12, 18)
    g.rect(1, 1, 10, 16, "M")
    for x, y in ((1, 1), (10, 1), (1, 16), (10, 16)):   # 八角切角
        g.clear(x, y)
    g.rect(3, 3, 6, 12, "D")    # 内衬
    g.rim_top(("M", "D"))
    g.shade_bottom(("M", "D"), "D")
    g.rect(5, 6, 2, 7, "G")     # 中央能量槽
    g.rect(4, 8, 4, 2, "G")
    g.outline("O")
    return g.to_image(pal)


def part_blade(pal):
    """光刃：挂在手臂末端、朝前方延伸的能量刀刃（贴图指向 +x）。"""
    g = Grid(18, 7)
    g.rect(0, 2, 4, 3, "W")     # 刀柄根部的亮核
    g.rect(3, 1, 11, 5, "G")    # 刀身
    g.rect(4, 2, 9, 3, "W")
    g.rect(13, 2, 4, 3, "G")    # 刀尖
    g.rect(15, 3, 3, 1, "W")
    g.rect(0, 0, 2, 1, "G")
    g.rect(0, 6, 2, 1, "G")
    return g.to_image(pal)


# ---------------------------------------------------------------- 特效
def fx_burst(pal, size, core, mid, jitter=0.9):
    """径向爆炸/火花，边缘带像素抖动。"""
    g = Grid(size, size)
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5 + random.uniform(-jitter, jitter)
            if d <= core:
                g.set(x, y, "W")
            elif d <= mid:
                g.set(x, y, "G")
    return g.to_image(pal)


def fx_muzzle(pal):
    """炮口十字星芒。"""
    g = Grid(9, 9)
    g.rect(4, 0, 1, 9, "G")
    g.rect(0, 4, 9, 1, "G")
    g.rect(3, 3, 3, 3, "W")
    g.dot(((2, 2), (6, 2), (2, 6), (6, 6)), "W")
    g.dot(((3, 2), (5, 2), (2, 3), (2, 5), (3, 6), (5, 6), (6, 3), (6, 5)), "G")
    return g.to_image(pal)


def fx_bullet(pal):
    """水平飞行能量弹。"""
    g = Grid(9, 5)
    g.rect(0, 1, 1, 3, "G")     # 尾焰
    g.rect(1, 1, 3, 3, "G")
    g.rect(4, 0, 3, 5, "G")     # 弹头
    g.rect(5, 1, 3, 3, "W")
    g.outline("O")
    return g.to_image(pal)


def fx_ring(pal, size, r_in, r_out):
    """冲击环：爆气脱身用的环形冲击波。"""
    g = Grid(size, size)
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) + random.uniform(-0.6, 0.6)
            if d <= r_in:
                g.set(x, y, "W")
            elif d <= r_out:
                g.set(x, y, "G")
    return g.to_image(pal)


def fx_guard(pal, size):
    """完美格挡：双层菱形护盾闪光 + 实心核心。

    专用一个金白色调（不走阵营配色），因为它要在一蓝一红两台机甲身上都一眼看清。
    """
    g = Grid(size, size)
    c = (size - 1) / 2.0
    r1 = size * 0.26
    r2 = size * 0.40
    for y in range(size):
        for x in range(size):
            m = abs(x - c) + abs(y - c) + random.uniform(-0.5, 0.5)
            if m <= r1 * 0.5:
                g.set(x, y, "W")            # 实心核心，冲击感更强
            elif abs(m - r1) <= 1.0:
                g.set(x, y, "W")
            elif abs(m - r2) <= 1.4:
                g.set(x, y, "G")
    return g.to_image(pal)


def fx_charge(pal, size):
    """蓄力：向内收拢的能量环 + 中心亮点。

    静态图看不出「向内收拢」，靠播放时反复脉冲 + 逐渐放大来传达蓄力感。
    """
    g = Grid(size, size)
    c = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) + random.uniform(-0.4, 0.4)
            if d <= size * 0.15:
                g.set(x, y, "W")
            elif abs(d - size * 0.33) <= 1.2:
                g.set(x, y, "G")
            elif abs(d - size * 0.45) <= 1.0:
                g.set(x, y, "D")
    return g.to_image(pal)


def fx_shatter(pal, size):
    """破防：护盾被打碎——中心亮点 + 六道向外飞散的碎片。"""
    g = Grid(size, size)
    c = (size - 1) / 2.0
    spokes = math.pi / 3.0
    for y in range(size):
        for x in range(size):
            dx, dy = x - c, y - c
            d = math.hypot(dx, dy) + random.uniform(-0.3, 0.3)
            if d <= 1.7:
                g.set(x, y, "W")
                continue
            if d > size * 0.48:
                continue
            # 每 60° 一道碎片，越往外越暗，读起来就是「碎开」
            k = (math.atan2(dy, dx) + math.pi) / spokes
            if abs(k - round(k)) < 0.14:
                g.set(x, y, "W" if d < size * 0.22 else ("G" if d < size * 0.34 else "M"))
    return g.to_image(pal)


def fx_roll(pal, w, h):
    """翻滚闪避：横向速度线 + 尾尘，用来明确提示「闪过去了」。"""
    g = Grid(w, h)
    streaks = ((2, 9), (5, 16), (8, 12), (11, 15), (14, 8))
    for y, length in streaks:
        for x in range(w):
            t = x / (w - 1)
            if t * w > w - length:
                g.set(x, y, "G")
                if length > 12 and t * w > w - length + 3:
                    g.set(x, y, "W")
    g.rect(w - 3, 4, 3, 9, "G")
    g.rect(w - 2, 6, 2, 5, "W")
    return g.to_image(pal)


def fx_slash(pal, w, h, curve=3.0, thickness=1.0):
    """斩击弧光：中间厚、两端薄的新月形刀光。"""
    g = Grid(w, h)
    cy = (h - 1) / 2.0
    for x in range(w):
        t = x / (w - 1)
        yc = cy - curve * math.sin(t * math.pi)
        half = thickness * (0.8 + 3.4 * math.sin(t * math.pi))
        for y in range(h):
            d = abs(y - yc)
            if d <= half * 0.42:
                g.set(x, y, "W")
            elif d <= half:
                g.set(x, y, "G")
    return g.to_image(pal)


# ---------------------------------------------------------------- 背景
def bayer_mix(c1, c2, t):
    return tuple(round(a + (b - a) * t) for a, b in zip(c1, c2))


def bg_sky():
    """320x180 夜空渐变 + 星点 + 月亮。"""
    w, h = 320, 180
    top, mid, warm = (14, 16, 34), (58, 34, 68), (146, 74, 86)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    ld = im.load()
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(h):
        t = y / (h - 1)
        if t < 0.72:
            k = t / 0.72
            a, b = top, mid
        else:
            k = (t - 0.72) / 0.28
            a, b = mid, warm
        base = bayer_mix(a, b, k)
        for x in range(w):
            q = (bayer[y % 4][x % 4] + 0.5) / 16.0
            c = bayer_mix(base, b, q * 0.55)
            ld[x, y] = (c[0], c[1], c[2], 255)
    # 月亮
    mx, my, mr = 252, 38, 11
    for y in range(my - mr - 3, my + mr + 4):
        for x in range(mx - mr - 3, mx + mr + 4):
            if not (0 <= x < w and 0 <= y < h):
                continue
            d = ((x - mx) ** 2 + (y - my) ** 2) ** 0.5 + random.uniform(-0.7, 0.7)
            if d <= mr - 3:
                ld[x, y] = (248, 240, 214, 255)
            elif d <= mr:
                ld[x, y] = (214, 198, 176, 255)
            elif d <= mr + 2.5 and random.random() < 0.5:
                ld[x, y] = (120, 110, 130, 255)
    # 星点
    for _ in range(120):
        x, y = random.randrange(w), random.randrange(0, 108)
        v = random.choice(((210, 226, 255), (160, 178, 220), (120, 132, 180)))
        ld[x, y] = (v[0], v[1], v[2], 255)
    return im


def bg_layer(name, height, base, top_glow, light_color, seed_shift):
    """剪影天际线图层（透明背景）。"""
    rnd = random.Random(9000 + seed_shift)
    w, h = 320, height
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ld = im.load()
    x = -6
    while x < w:
        bw = rnd.randint(11, 30)
        bh = rnd.randint(int(h * 0.28), int(h * 0.88))
        top = h - bh
        # 建筑主体
        for j in range(top, h):
            for i in range(x, min(w, x + bw)):
                ld[i, j] = base
        # 顶面亮边
        for i in range(x, min(w, x + bw)):
            ld[i, top] = top_glow
        # 阶梯状屋顶
        for step in range(rnd.randint(0, 2)):
            sw, sh2 = rnd.randint(3, 6), rnd.randint(2, 5)
            sx = x + rnd.randint(0, max(0, bw - sw))
            for j in range(max(0, top - sh2), top):
                for i in range(sx, min(w, sx + sw)):
                    ld[i, j] = base
            for i in range(sx, min(w, sx + sw)):
                ld[i, max(0, top - sh2)] = top_glow
        # 天线
        if rnd.random() < 0.3:
            ax = x + rnd.randint(1, max(1, bw - 2))
            ah = rnd.randint(4, 11)
            for j in range(max(0, top - ah), top):
                ld[ax, j] = base
            ld[ax, max(0, top - ah)] = (220, 120, 120, 255)
        # 窗户灯
        for wy in range(top + 4, h - 3, 5):
            for wx in range(x + 2, min(w - 1, x + bw - 2), 4):
                if rnd.random() < 0.34:
                    ld[wx, wy] = light_color
        x += bw + rnd.randint(0, 3)
    return im


def bg_ground():
    """320x30 地面：金属表层 + 铆钉 + 暗部噪点。"""
    w, h = 320, 30
    im = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    ld = im.load()
    plate_hi, plate, plate_dark = (126, 134, 156), (92, 100, 120), (58, 62, 78)
    soil, deep = (36, 38, 52), (24, 25, 36)
    for y in range(h):
        for x in range(w):
            if y == 0:
                ld[x, y] = plate_hi
            elif y < 4:
                ld[x, y] = plate
            elif y < 9:
                ld[x, y] = plate_dark
            elif y < 13:
                ld[x, y] = soil
            else:
                ld[x, y] = deep
    for x in range(0, w, 16):          # 铆钉与接缝
        ld[x, 1] = (180, 188, 206)
        ld[x + 1, 1] = (70, 76, 94)
        for y in range(2, 9):
            ld[x, y] = (40, 44, 58)
        ld[x + 1, 3] = (150, 158, 178)
    for _ in range(360):               # 暗部噪点
        x, y = random.randrange(w), random.randrange(13, h)
        ld[x, y] = (32 + random.randint(0, 10), 33 + random.randint(0, 10), 46, 255)
    for _ in range(60):                # 地表高光碎点
        x = random.randrange(w)
        ld[x, 0] = (200, 208, 226)
        if x + 1 < w:
            ld[x + 1, 1] = (150, 158, 178)
    return im


# ---------------------------------------------------------------- 主流程
def main():
    print("[1/3] 机甲部件")
    for team, pal in PALETTES.items():
        save(part_torso(pal), f"mecha/{team}_torso.png")
        save(part_arm(pal), f"mecha/{team}_arm.png")
        save(part_leg(pal), f"mecha/{team}_leg.png")
        save(part_shield(pal), f"mecha/{team}_shield.png")
        save(part_blade(pal), f"mecha/{team}_blade.png")

    print("[2/3] 特效")
    for team, pal in PALETTES.items():
        save(fx_muzzle(pal), f"fx/{team}_muzzle.png")
        save(fx_bullet(pal), f"fx/{team}_bullet.png")
        save(fx_burst(pal, 12, 2.2, 5.4), f"fx/{team}_hit.png")
        save(fx_burst(pal, 9, 1.6, 3.9), f"fx/{team}_spark.png")
        save(fx_slash(pal, 22, 15, 3.2, 1.0), f"fx/{team}_slash_a.png")   # 轻斩
        save(fx_slash(pal, 32, 24, 5.0, 1.5), f"fx/{team}_slash_b.png")   # 重斩终结
        save(fx_slash(pal, 44, 32, 6.6, 2.0), f"fx/{team}_slash_c.png")   # 破甲重击（大弧光）
        save(fx_ring(pal, 30, 8.0, 13.0), f"fx/{team}_burst.png")         # 爆气脱身
        save(fx_roll(pal, 22, 17), f"fx/{team}_roll.png")                 # 翻滚闪避
        save(fx_charge(pal, 26), f"fx/{team}_charge.png")                 # 重击蓄力
        save(fx_shatter(pal, 30), f"fx/{team}_shatter.png")               # 破防碎裂
    # 完美格挡：金白色调，两台机甲共用一张（要能从阵营配色里跳出来）
    save(fx_guard(GUARD_PAL, 30), "fx/guard.png")

    print("[3/3] 场景")
    save(bg_sky(), "scene/sky.png")
    save(bg_layer("far", 56, (44, 46, 70, 255), (62, 64, 92, 255), (196, 178, 132, 255), 1),
         "scene/skyline_far.png")
    save(bg_layer("near", 44, (26, 28, 44, 255), (40, 42, 62, 255), (168, 128, 96, 255), 2),
         "scene/skyline_near.png")
    save(bg_ground(), "scene/ground.png")
    print("完成。")


if __name__ == "__main__":
    main()
