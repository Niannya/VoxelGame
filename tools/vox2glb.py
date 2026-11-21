#!/usr/bin/env python
"""MagicaVoxel .vox -> glTF 2.0 binary (.glb)，体素外壳 + 贪心合并 + 顶点色。

思路：
  1. 解析 VOX 的 SIZE / XYZI / RGBA（调色板）；
  2. 逐方向提取"外露面"（相邻格子为空才算），同一颜色相邻面做贪心矩形合并；
  3. 输出 trimesh 模型（每个四边形 4 顶点、2 三角），顶点色 = 调色板颜色的线性空间值；
  4. Z-up(VOX) -> Y-up(glTF) 旋转，XZ 居中、脚底贴 y=0，按目标高度缩放。

用法：
  python vox2glb.py <in.vox> <out.glb> [目标高度=2.2]
"""
import sys
import struct
import numpy as np
import trimesh


def parse_vox(path):
    data = open(path, "rb").read()
    if data[:4] != b"VOX ":
        raise ValueError("不是 VOX 文件: %s" % path)
    pos = 8
    size = None
    voxels = None
    palette = None
    while pos < len(data):
        cid = data[pos:pos + 4]
        n, _ = struct.unpack("<ii", data[pos + 4:pos + 12])
        pos += 12
        body = data[pos:pos + n]
        pos += n
        if cid == b"SIZE":
            size = struct.unpack("<iii", body[:12])
        elif cid == b"XYZI":
            cnt = struct.unpack("<i", body[:4])[0]
            arr = np.frombuffer(body[4:4 + cnt * 4], dtype=np.uint8).reshape(cnt, 4)
            voxels = arr  # x, y, z, color_index
        elif cid == b"RGBA":
            pal = np.frombuffer(body[:1024], dtype=np.uint8).reshape(256, 4)
            palette = pal[:, :3].copy()
    if size is None or voxels is None:
        raise ValueError("缺少 SIZE / XYZI: %s" % path)
    if palette is None:  # 默认调色板（MagicaVoxel 内置）
        palette = _default_palette()
    return size, voxels, palette


def _default_palette():
    base = np.array([
        [0x00, 0x00, 0x00], [0xff, 0xff, 0xff], [0xcc, 0xff, 0xff], [0x99, 0xff, 0xcc],
        [0x66, 0xff, 0x99], [0x33, 0xff, 0x66], [0x00, 0xff, 0x33], [0x00, 0xcc, 0x00],
    ], dtype=np.uint8)
    pal = np.tile(base, (32, 1))
    return pal


def build_volume(size, voxels, palette):
    sx, sy, sz = size
    vol = np.zeros((sx, sy, sz), dtype=np.int32)
    # 越界保护
    m = ((voxels[:, 0] < sx) & (voxels[:, 1] < sy) & (voxels[:, 2] < sz))
    v = voxels[m]
    # 颜色索引 1..255 -> 调色板 0..254
    color = np.clip(v[:, 3].astype(np.int32) - 1, 0, 255)
    vol[v[:, 0], v[:, 1], v[:, 2]] = color + 1  # 0 表示空
    return vol


def greedy_faces(mask, colors):
    """在二维切片上做同色矩形贪心合并。

    返回 (r0, c0, dr, dc, color)：
      r0/c0 为矩形起始行/列（对应切片的第一维/第二维），dr/dc 为行数/列数。
    """
    out = []
    h, w = mask.shape
    used = np.zeros_like(mask, dtype=bool)
    for y in range(h):
        x = 0
        while x < w:
            if not mask[y, x] or used[y, x]:
                x += 1
                continue
            c = colors[y, x]
            # 向右扩展
            x2 = x
            while x2 + 1 < w and mask[y, x2 + 1] and not used[y, x2 + 1] and colors[y, x2 + 1] == c:
                x2 += 1
            # 向下扩展（整行同色）
            y2 = y
            while y2 + 1 < h:
                row_ok = True
                for xx in range(x, x2 + 1):
                    if (not mask[y2 + 1, xx]) or used[y2 + 1, xx] or colors[y2 + 1, xx] != c:
                        row_ok = False
                        break
                if not row_ok:
                    break
                y2 += 1
            used[y:y2 + 1, x:x2 + 1] = True
            # 行 = 切片第一维，列 = 切片第二维
            out.append((y, x, y2 - y + 1, x2 - x + 1, c))
            x = x2 + 1
    return out


def vox_to_mesh(vol, palette, target_height=2.2):
    sx, sy, sz = vol.shape
    solid = vol > 0
    verts = []
    faces = []
    vcols = []

    # 六个方向：(轴, 正负)
    dirs = [(0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1)]
    for axis, sign in dirs:
        # 沿 axis 逐层；其余两轴构成二维平面
        others = [a for a in (0, 1, 2) if a != axis]
        for layer in range(vol.shape[axis]):
            nb = layer + sign
            if nb < 0 or nb >= vol.shape[axis]:
                neighbour = np.zeros_like(np.take(solid, layer, axis=axis))
            else:
                neighbour = np.take(solid, nb, axis=axis)
            cur = np.take(solid, layer, axis=axis)
            mask = cur & ~neighbour
            if not mask.any():
                continue
            colors = np.take(vol, layer, axis=axis)
            # mask/colors 的轴顺序 = others
            rects = greedy_faces(mask, colors)
            for (r0, c0, dr, dc, c) in rects:
                rgb = palette[min(max(c - 1, 0), 255)] / 255.0
                _emit_quad(verts, faces, vcols, axis, sign, layer, others, r0, c0, dr, dc, rgb)

    verts = np.asarray(verts, dtype=np.float64)
    faces = np.asarray(faces, dtype=np.int64)
    vcols = np.asarray(vcols, dtype=np.float64)

    # Z-up -> Y-up: (x, y, z) -> (x, z, -y)
    verts = np.column_stack([verts[:, 0], verts[:, 2], -verts[:, 1]])

    # 居中 + 脚底落地 + 缩放到目标高度
    mins = verts.min(axis=0)
    maxs = verts.max(axis=0)
    height = maxs[1] - mins[1]
    scale = target_height / height if height > 0 else 1.0
    center_x = (mins[0] + maxs[0]) * 0.5
    center_z = (mins[2] + maxs[2]) * 0.5
    verts[:, 0] = (verts[:, 0] - center_x) * scale
    verts[:, 1] = (verts[:, 1] - mins[1]) * scale
    verts[:, 2] = (verts[:, 2] - center_z) * scale

    # 顶点色 sRGB -> 线性（glTF COLOR_0 规范为线性空间）
    lin = np.where(vcols <= 0.04045, vcols / 12.92, ((vcols + 0.055) / 1.055) ** 2.4)
    mesh = trimesh.Trimesh(vertices=verts, faces=faces, process=False)
    rgba = np.column_stack([lin, np.ones(len(lin))])
    mesh.visual = trimesh.visual.ColorVisuals(mesh=mesh, vertex_colors=rgba)
    return mesh


def _emit_quad(verts, faces, vcols, axis, sign, layer, others, r0, c0, dr, dc, rgb):
    """把一个矩形面拆成 2 个三角形（顶点不共享，保证每个面颜色/法线独立）。

    r0/c0/dr/dc 分别对应切片的两维（others[0] 为行方向，others[1] 为列方向）。
    """
    o1, o2 = others
    base = len(verts)

    def corner(a, b):  # a 沿 o1（行），b 沿 o2（列）
        p = [0.0, 0.0, 0.0]
        p[axis] = layer + (1.0 if sign > 0 else 0.0)
        p[o1] = a
        p[o2] = b
        return p

    p0 = corner(r0, c0)
    p1 = corner(r0 + dr, c0)
    p2 = corner(r0 + dr, c0 + dc)
    p3 = corner(r0, c0 + dc)
    verts.extend([p0, p1, p2, p3])
    for _ in range(4):
        vcols.append(rgb)

    # 根据法线方向决定绕序，保证朝外
    if sign > 0:
        faces.extend([[base, base + 1, base + 2], [base, base + 2, base + 3]])
    else:
        faces.extend([[base, base + 2, base + 1], [base, base + 3, base + 2]])


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    src, dst = sys.argv[1], sys.argv[2]
    target_h = float(sys.argv[3]) if len(sys.argv) > 3 else 2.2
    size, voxels, palette = parse_vox(src)
    print("  size=%s voxels=%d" % (size, len(voxels)))
    vol = build_volume(size, voxels, palette)
    mesh = vox_to_mesh(vol, palette, target_h)
    mesh.export(dst, file_type="glb")
    print("  -> %s  tris=%d  verts=%d" % (dst, len(mesh.faces), len(mesh.vertices)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
