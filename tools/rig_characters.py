"""Build editable voxel rigs and Godot-ready animation clips.

Run with Blender 5.3: blender -b --factory-startup -P tools/rig_characters.py -- <index 0..5>
The unrigged GLBs are read from git history if they are not present locally.
This script writes rigged/*.glb and rigged_sources/*.blend.
"""

import bpy
import json
import math
import os
import subprocess
import sys
import tempfile


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAMES = ["char_01_cuntou", "char_02_baimao", "char_03_fenmao", "char_04_lanmao", "char_05_huangmao", "char_06_hemao"]
BONES = ("root", "pelvis", "spine", "head", "arm.L", "arm.R", "leg.L", "leg.R")
TOOL_CLIPS = ("Pick", "Hammer", "Bow", "Torch", "Backpack", "Canteen")


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)


def add_bone(arm, name, head, tail, parent=None):
    bone = arm.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    # Export the unweighted root as a real joint for consistent hierarchy/root motion.
    bone.use_deform = True
    if parent:
        bone.parent = arm.edit_bones[parent]
    return bone


def create_rig(mesh):
    arm_data = bpy.data.armatures.new("MinerSkeleton")
    arm = bpy.data.objects.new("MinerRig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    add_bone(arm_data, "root", (0, 0, 0), (0, 0, .2))
    add_bone(arm_data, "pelvis", (0, 0, .48), (0, 0, .82), "root")
    add_bone(arm_data, "spine", (0, 0, .82), (0, 0, 1.35), "pelvis")
    add_bone(arm_data, "head", (0, 0, 1.34), (0, 0, 1.95), "spine")
    add_bone(arm_data, "arm.L", (.28, 0, 1.12), (.48, 0, .74), "spine")
    add_bone(arm_data, "arm.R", (-.28, 0, 1.12), (-.48, 0, .74), "spine")
    add_bone(arm_data, "leg.L", (.15, 0, .51), (.15, 0, .07), "pelvis")
    add_bone(arm_data, "leg.R", (-.15, 0, .51), (-.15, 0, .07), "pelvis")
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.select_set(False)
    for bone in arm.pose.bones:
        bone.rotation_mode = "XYZ"
    mesh.parent = arm
    mod = mesh.modifiers.new("VoxelRig", "ARMATURE")
    mod.object = arm
    groups = {name: mesh.vertex_groups.new(name=name) for name in BONES if name != "root"}

    # The source duplicates vertices at each face. Give vertices at the same position
    # exactly the same weights, otherwise adjoining faces open cracks at joints.
    # Narrow blends keep the voxel silhouette while giving shoulders/hips a hinge.
    def smoothstep(lo, hi, value):
        t = max(0.0, min(1.0, (value - lo) / (hi - lo)))
        return t * t * (3.0 - 2.0 * t)

    counts = {name: 0 for name in groups}
    buckets = {name: {} for name in groups}
    for vertex in mesh.data.vertices:
        x, z = vertex.co.x, vertex.co.z
        head = smoothstep(1.30, 1.43, z)
        arm_weight = (1 - head) * smoothstep(.25, .37, abs(x)) * smoothstep(.47, .64, z) * (1 - smoothstep(1.17, 1.34, z))
        leg = (1 - head - arm_weight) * (1 - smoothstep(.42, .64, z)) * smoothstep(.015, .09, abs(x))
        body = max(0.0, 1 - head - arm_weight - leg)
        spine = body * smoothstep(.70, .94, z)
        weights = {
            "head": head,
            "arm.L" if x >= 0 else "arm.R": arm_weight,
            "leg.L" if x >= 0 else "leg.R": leg,
            "spine": spine,
            "pelvis": body - spine,
        }
        weights = {name: w for name, w in weights.items() if w >= .01}
        top = sorted(weights.items(), key=lambda item: item[1], reverse=True)[:4]
        total = sum(w for _, w in top)
        for name, weight in top:
            quantized = max(1, round(weight / total * 1000))
            buckets[name].setdefault(quantized, []).append(vertex.index)
        counts[top[0][0]] += 1
    for name, weights in buckets.items():
        for quantized, indices in weights.items():
            groups[name].add(indices, quantized / 1000, "REPLACE")
    return arm, counts


def key_pose(arm, frame, rotations=None, lift=0.0):
    rotations = rotations or {}
    for name in BONES:
        bone = arm.pose.bones[name]
        bone.rotation_euler = tuple(math.radians(v) for v in rotations.get(name, (0, 0, 0)))
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=name)
    pelvis = arm.pose.bones["pelvis"]
    pelvis.location = (0, 0, lift)
    pelvis.keyframe_insert(data_path="location", frame=frame, group="pelvis")


def action(arm, name, poses, loop=False):
    anim = bpy.data.actions.new(name)
    anim.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = anim
    for frame, rotations, lift in poses:
        key_pose(arm, frame, rotations, lift)
    # The action's slot persists; glTF ACTIONS mode picks up every clip.
    for layer in anim.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.handle_left_type = "AUTO_CLAMPED"
                        key.handle_right_type = "AUTO_CLAMPED"
    return anim


def build_actions(arm, index):
    # The six miners have different silhouettes and mannerisms.
    idle_mid = [
        {"spine": (2, 0, 0), "head": (-3, 0, 0), "arm.L": (2, 0, 1)},
        {"head": (0, 0, 7), "arm.R": (4, 0, -2), "spine": (0, 0, -2)},
        {"pelvis": (0, 0, 3), "head": (0, 0, -5), "arm.L": (-4, 0, 0)},
        {"spine": (4, 0, 0), "head": (-5, 0, 3), "arm.L": (3, 0, 3), "arm.R": (-3, 0, -3)},
        {"head": (4, 0, -5), "spine": (-2, 0, 2), "arm.R": (3, 0, 0)},
        {"spine": (-2, 0, -2), "head": (3, 0, 4), "arm.L": (2, 0, 0)},
    ][index]
    idle_other = {k: tuple(-.55 * v for v in xyz) for k, xyz in idle_mid.items()}
    action(arm, "Idle", [(1, {}, 0), (30, idle_mid, .018 if index != 3 else .032), (60, {}, 0), (90, idle_other, -.008), (121, {}, 0)], loop=True)

    welcomes = [
        {"arm.R": (22, 0, -22), "head": (-6, 0, 0)},
        {"arm.L": (-18, 0, 18), "head": (5, 0, 12)},
        {"arm.L": (0, 0, 24), "spine": (0, 0, 8)},
        {"arm.R": (32, 0, -12), "head": (-8, 0, -8)},
        {"arm.R": (0, 0, -20), "spine": (0, 0, -5)},
        {"arm.L": (25, 0, 12), "head": (0, 0, 8)},
    ]
    action(arm, "Select", [(1, {}, 0), (10, welcomes[index], .035), (22, {k: tuple(.65*v for v in xyz) for k, xyz in welcomes[index].items()}, .012), (32, {}, 0)])

    motions = {
        "Pick": [(1, {}, 0), (9, {"spine": (-12, 0, -7), "arm.R": (-45, 0, -13), "arm.L": (-10, 0, 6)}, 0), (16, {"spine": (9, 0, 6), "arm.R": (47, 0, 8), "arm.L": (5, 0, 0)}, -.02), (31, {}, 0)],
        "Hammer": [(1, {}, 0), (13, {"spine": (-12, 0, 0), "arm.L": (-55, 0, 15), "arm.R": (-55, 0, -15)}, .025), (24, {"spine": (16, 0, 0), "arm.L": (42, 0, 4), "arm.R": (42, 0, -4)}, -.025), (41, {}, 0)],
        "Bow": [(1, {}, 0), (13, {"spine": (0, 0, 9), "arm.L": (-52, 0, 18), "arm.R": (-23, 0, -24), "head": (0, 0, -7)}, 0), (28, {"spine": (0, 0, 9), "arm.L": (-52, 0, 18), "arm.R": (18, 0, -8), "head": (0, 0, -7)}, 0), (40, {}, 0)],
        "Torch": [(1, {}, 0), (10, {"arm.R": (-35, 0, -27), "head": (-8, 0, -7)}, 0), (24, {"arm.R": (-40, 0, -20), "head": (-3, 0, 5)}, .012), (36, {}, 0)],
        "Backpack": [(1, {}, 0), (13, {"spine": (17, 0, 0), "arm.L": (27, 0, 20), "arm.R": (27, 0, -20), "head": (-7, 0, 0)}, -.018), (29, {"spine": (8, 0, 0), "arm.L": (8, 0, 9), "arm.R": (8, 0, -9)}, 0), (41, {}, 0)],
        "Canteen": [(1, {}, 0), (12, {"arm.R": (-58, 0, -10), "head": (16, 0, -5)}, 0), (30, {"arm.R": (-58, 0, -10), "head": (19, 0, -5)}, 0), (43, {}, 0)],
    }
    for name in TOOL_CLIPS:
        action(arm, name, motions[name])
    arm.animation_data.action = bpy.data.actions["Idle"]


def main(index):
    clear_scene()
    name = NAMES[index]
    src = os.path.join(ROOT, "assets", "characters", name + ".glb")
    temporary_source = None
    if not os.path.isfile(src):
        original = subprocess.run(
            ["git", "show", f"0b759b4:assets/characters/{name}.glb"],
            cwd=ROOT, check=True, capture_output=True,
        ).stdout
        with tempfile.NamedTemporaryFile(prefix=name + "_", suffix=".glb", delete=False) as temp:
            temp.write(original)
            temporary_source = temp.name
        src = temporary_source
    out_dir = os.path.join(ROOT, "assets", "characters", "rigged")
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.import_scene.gltf(filepath=src)
    if temporary_source:
        os.remove(temporary_source)
    meshes = [obj for obj in bpy.data.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError(f"Expected one mesh in {src}, found {[m.name for m in meshes]}")
    mesh = meshes[0]
    mesh.name = name + "_mesh"
    arm, counts = create_rig(mesh)
    build_actions(arm, index)
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 121
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    out = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True, export_def_bones=True, export_skins=True, export_image_format="AUTO")
    source_dir = os.path.join(ROOT, "assets", "characters", "rigged_sources")
    os.makedirs(source_dir, exist_ok=True)
    blend = os.path.join(source_dir, name + ".blend")
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=blend, compress=True)
    print("@@JSON@@" + json.dumps({"source": src, "output": out, "blend": blend, "size": os.path.getsize(out), "vertices": len(mesh.data.vertices), "polygons": len(mesh.data.polygons), "weights": counts, "bones": list(BONES), "actions": list(TOOL_CLIPS) + ["Idle", "Select"]}))


if __name__ == "__main__":
    main(int(sys.argv[-1]))
