"""生成「角色遮挡遮罩」：给准备间标题做前后遮挡用。

标题里的 MINE 应该被前面的角色挡住（角色在字上面）。做法是给标题着色器一张遮罩图，
遮罩里白色 = 这里属于角色，标题的像素就被丢掉。

遮罩按**底图坐标**（1920x1071）画，和 lobby_bg.jpg 一一对应；
lobby.gd 会把底图的摆放位置传给着色器，所以在脚本里改 BG_OFFSET / BG_SCALE 不用重跑本脚本。

轮廓是手描的多边形，宁可画大一点（多遮一点只是把字切掉一点，少遮会露出字压在角色上）。

用法：python tools/gen_lobby_occluder.py
输出：assets/ui/backgrounds/lobby_bg_occluder.png
"""
import os

from PIL import Image, ImageDraw

# 底图像素尺寸（= 遮罩尺寸）
SIZE = (1920, 1071)

# 每个角色一块多边形（底图坐标，顺时针）。只描会被 MINE 扫到的三个角色上半身。
# 头顶那一圈是照着放大到 3 倍的底图逐点描的 —— 描松了字会被切在半空中，很难看。
CHARACTERS = [
    # 橙背心白胡子：安全帽 + 脸 + 肩
    [(568, 240), (582, 205), (600, 180), (620, 162), (642, 152), (668, 158), (692, 172),
     (712, 196), (728, 222), (738, 246), (746, 272), (748, 300), (744, 340), (744, 500),
     (516, 500), (520, 420), (536, 330), (548, 290), (566, 258)],
    # 粉发女孩：毛球帽 + 头灯 + 脸
    [(730, 318), (742, 288), (766, 260), (792, 242), (828, 232), (860, 238), (890, 252),
     (912, 272), (926, 292), (942, 300), (972, 318), (994, 342), (1002, 372), (1006, 500),
     (712, 500), (714, 400), (720, 352)],
    # 蓝发黄安全帽
    [(1126, 340), (1140, 300), (1158, 276), (1180, 256), (1206, 240), (1236, 228),
     (1266, 232), (1296, 245), (1322, 262), (1346, 286), (1366, 310), (1384, 334),
     (1394, 358), (1400, 500), (1130, 500)],
]


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "assets", "ui", "backgrounds", "lobby_bg_occluder.png")

    img = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for poly in CHARACTERS:
        d.polygon(poly, fill=(255, 255, 255, 255))
    img.save(out)
    print("saved", out, img.size)

    # 顺手把描出来的轮廓叠到底图上（半透明白 + 绿边），方便肉眼检查是否贴合
    bg = Image.open(os.path.join(root, "assets", "ui", "backgrounds", "lobby_bg.jpg")).convert("RGBA")
    overlay = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for poly in CHARACTERS:
        od.polygon(poly, fill=(255, 255, 255, 80))
    check = Image.alpha_composite(bg, overlay).convert("RGB")
    dd = ImageDraw.Draw(check)
    for poly in CHARACTERS:
        dd.line(list(poly) + [poly[0]], fill=(0, 255, 0), width=2)
    check.crop((400, 60, 1450, 560)).save(os.path.join(root, ".godot", "occluder_check.png"))
    print("check image: .godot/occluder_check.png")


if __name__ == "__main__":
    main()
