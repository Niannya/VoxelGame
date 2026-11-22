import bpy
import bmesh
import json
import sys

path = sys.argv[-1]
bpy.ops.import_scene.gltf(filepath=path)
result = []
for obj in bpy.data.objects:
    if obj.type != 'MESH':
        continue
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    islands = []
    unseen = set(bm.verts)
    while unseen:
        start = unseen.pop()
        group = {start}
        queue = [start]
        while queue:
            current = queue.pop()
            for edge in current.link_edges:
                for vert in edge.verts:
                    if vert in unseen:
                        unseen.remove(vert)
                        group.add(vert)
                        queue.append(vert)
        islands.append(len(group))
    bm.free()
    result.append({
        'name': obj.name,
        'vertices': len(obj.data.vertices),
        'polygons': len(obj.data.polygons),
        'materials': [m.name for m in obj.data.materials],
        'dimensions': list(obj.dimensions),
        'bounds': [[min(v.co[i] for v in obj.data.vertices), max(v.co[i] for v in obj.data.vertices)] for i in range(3)],
        'islands': len(islands),
        'largest_islands': sorted(islands, reverse=True)[:12],
        'z_bands': [
            {
                'z': round(i * .2, 2),
                'count': len([v for v in obj.data.vertices if i * .2 <= v.co.z < (i + 1) * .2]),
                'x_span': [round(min([v.co.x for v in obj.data.vertices if i * .2 <= v.co.z < (i + 1) * .2] or [0]), 3), round(max([v.co.x for v in obj.data.vertices if i * .2 <= v.co.z < (i + 1) * .2] or [0]), 3)],
            }
            for i in range(11)
        ] if obj.name == 'voxel_character' else [],
    })
print('@@JSON@@' + json.dumps(result))
