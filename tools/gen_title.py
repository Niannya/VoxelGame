"""生成准备间标题的像素字 PNG（两条独立的字：MINE / CRASH!）。

手写 5x7 位图字形 → 放大成方块 → 加粗描边 + 金色纵向渐变 + 顶部高光。
每个词单独出一张「紧贴字形」的图，方便在 lobby.gd 里各自用一个四边形贴到屏幕上
（MINE 在上、CRASH! 在左下），两张图各自独立，互不牵连。

用法：python tools/gen_title.py
输出：assets/ui/title_mine.png、assets/ui/title_crash.png
"""
import os

from PIL import Image, ImageDraw

# 5 宽 x 7 高的位图字形（1 = 实心）
GLYPHS = {
    "M": ["10001", "11011", "10101", "10001", "10001", "10001", "10001"],
    "I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
    "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "!": ["00100", "00100", "00100", "00100", "00100", "00000", "00100"],
    " ": ["00000", "00000", "00000", "00000", "00000", "00000", "00000"],
}

PIX = 38          # 一个位图像素放大后的边长
GAP = 45          # 字间距
OUTLINE = 9       # 描边宽度
TOP_GOLD = (255, 226, 141)
BOT_GOLD = (214, 137, 42)
EDGE = (26, 20, 12)


def word_size(word):
    w = len(word) * 5 * PIX + (len(word) - 1) * GAP
    return w, 7 * PIX


def draw_word(draw, word, ox, oy):
    """先画描边（方块外扩），再画渐变填充，最后一条顶部高光。"""
    cells = []
    cx = ox
    for ch in word:
        rows = GLYPHS[ch]
        for ry, row in enumerate(rows):
            for rx, bit in enumerate(row):
                if bit == "1":
                    cells.append((cx + rx * PIX, oy + ry * PIX))
        cx += 5 * PIX + GAP

    for (x, y) in cells:
        draw.rectangle([x - OUTLINE, y - OUTLINE, x + PIX - 1 + OUTLINE, y + PIX - 1 + OUTLINE], fill=EDGE)

    for (x, y) in cells:
        ry = (y - oy) / float(7 * PIX)
        t = min(1.0, max(0.0, ry))
        col = tuple(int(TOP_GOLD[i] + (BOT_GOLD[i] - TOP_GOLD[i]) * t) for i in range(3))
        draw.rectangle([x, y, x + PIX - 1, y + PIX - 1], fill=col)

    # 顶部一行像素提亮，模拟受光
    for (x, y) in cells:
        if (y - oy) < PIX:
            draw.rectangle([x, y, x + PIX - 1, y + PIX // 3], fill=(255, 245, 200))


def make_word(word, path):
    """画一个词，画布收紧到「字形 + 描边」，四边不留空白。"""
    w, h = word_size(word)
    pad = OUTLINE + 1
    img = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    draw_word(ImageDraw.Draw(img), word, pad, pad)
    img.save(path)
    print("saved %s %dx%d (aspect %.3f)" % (path, img.size[0], img.size[1], img.size[0] / img.size[1]))


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "assets", "ui")
    os.makedirs(out_dir, exist_ok=True)
    make_word("MINE", os.path.join(out_dir, "title_mine.png"))
    make_word("CRASH!", os.path.join(out_dir, "title_crash.png"))


if __name__ == "__main__":
    main()
