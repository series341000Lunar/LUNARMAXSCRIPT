"""Run with Blender: blender -b --factory-startup --python this_file.py"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import renew_parent_animation as addon


addon.register()
scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 11


def reset_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    scene.frame_set(4)


def make_object(name, mesh=False):
    if mesh:
        vertices = [(0, 0, 0), (1, 0, 0), (0, 1, 0)]
        data = bpy.data.meshes.new(f"{name}Mesh")
        data.from_pydata(vertices, [], [(0, 1, 2)])
    else:
        data = None
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return obj


def key(obj, path, frame, value):
    setattr(obj, path, value)
    assert obj.keyframe_insert(data_path=path, frame=frame)
    for fc in addon._action_fcurves(obj.animation_data.action, obj.animation_data.action_slot):
        for point in fc.keyframe_points:
            point.interpolation = 'LINEAR'


def captured_world(children):
    result = {child: {} for child in children}
    for frame in range(1, 12):
        scene.frame_set(frame)
        graph = bpy.context.evaluated_depsgraph_get()
        for child in children:
            result[child][frame] = child.evaluated_get(graph).matrix_world.copy()
    return result


def run_bake(parent, children):
    bpy.ops.object.select_all(action='DESELECT')
    for child in children:
        child.select_set(True)
    parent.select_set(True)
    bpy.context.view_layer.objects.active = parent
    scene.frame_set(4)
    source = captured_world(children)
    scene.frame_set(4)
    selection = set(bpy.context.selected_objects)
    assert bpy.ops.object.renew_parent_animation() == {'FINISHED'}
    assert scene.frame_current == 4
    assert set(bpy.context.selected_objects) == selection
    assert bpy.context.view_layer.objects.active == parent
    for child in children:
        assert child.parent == parent
        assert child.matrix_parent_inverse == Matrix.Identity(4)
        assert child.rotation_mode == 'QUATERNION'
        assert child.animation_data.action is not None
        curves = list(addon._action_fcurves(child.animation_data.action,
                                            child.animation_data.action_slot))
        assert {curve.data_path for curve in curves} == {
            'location', 'rotation_quaternion', 'scale'
        }
        assert all(len(curve.keyframe_points) == 11 for curve in curves)
        assert all(point.interpolation == 'LINEAR' for curve in curves
                   for point in curve.keyframe_points)
    max_position, max_rotation, _ = addon._validate_world_motion(
        bpy.context, list(range(1, 12)), children, source
    )
    assert max_position <= addon.POSITION_TOLERANCE, max_position
    assert max_rotation <= addon.ROTATION_TOLERANCE_DEG, max_rotation
    print(f"TEST MAX ERROR: position={max_position:.9f}, rotation={max_rotation:.9f} deg")
    return source


def test_a_translation():
    reset_scene()
    parent = make_object('A_Parent')
    child = make_object('A_Child', mesh=True)
    material = bpy.data.materials.new('A_Material')
    child.data.materials.append(material)
    mesh_data = child.data
    key(parent, 'location', 1, (0, 0, 0))
    key(parent, 'location', 11, (10, 0, 0))
    key(child, 'location', 1, (2, 0, 0))
    key(child, 'location', 11, (12, 0, 0))
    run_bake(parent, [child])
    for frame in range(1, 12):
        scene.frame_set(frame)
        assert abs(child.location.x - 2.0) < 1e-5
    assert child.data == mesh_data and child.data.materials[0] == material
    print('Test A PASS')


def test_b_translation_rotation():
    reset_scene()
    parent = make_object('B_Parent')
    child = make_object('B_Child')
    key(parent, 'location', 1, (0, 0, 0))
    key(parent, 'location', 11, (10, 1, 2))
    key(parent, 'rotation_euler', 1, (0, 0, 0))
    key(parent, 'rotation_euler', 11, (0, 0, math.pi / 2))
    key(child, 'location', 1, (2, 1, 0))
    key(child, 'location', 11, (9, 4, 3))
    key(child, 'rotation_euler', 1, (0.2, -0.3, 0.1))
    key(child, 'rotation_euler', 11, (0.6, 0.7, -0.8))
    run_bake(parent, [child])
    print('Test B PASS')


def test_c_multiple_children():
    reset_scene()
    parent = make_object('C_Parent')
    key(parent, 'location', 1, (0, 0, 0))
    key(parent, 'location', 11, (4, 5, 6))
    key(parent, 'rotation_euler', 1, (0, 0, 0))
    key(parent, 'rotation_euler', 11, (0.4, -0.2, 0.8))
    children = []
    for index in range(3):
        child = make_object(f'C_Child_{index}')
        key(child, 'location', 1, (index + 1, index * 2, -index))
        key(child, 'location', 11, (index + 5, index * 3, index + 1))
        key(child, 'rotation_euler', 1, (0, 0, index * 0.2))
        key(child, 'rotation_euler', 11, (0.1 * index, 0.2 * index, 1.2))
        children.append(child)
    run_bake(parent, children)
    print('Test C PASS')


def test_d_constraint_source():
    reset_scene()
    parent = make_object('D_Parent')
    target = make_object('D_Constraint_Target')
    child = make_object('D_Child')
    key(parent, 'location', 1, (0, 0, 0))
    key(parent, 'location', 11, (3, 4, 0))
    key(parent, 'rotation_euler', 1, (0, 0, 0))
    key(parent, 'rotation_euler', 11, (0, 0, 0.8))
    key(target, 'location', 1, (2, 2, 0))
    key(target, 'location', 11, (7, 3, 2))
    key(target, 'rotation_euler', 1, (0.1, 0.2, 0.3))
    key(target, 'rotation_euler', 11, (0.5, -0.4, 0.7))
    constraint = child.constraints.new('COPY_TRANSFORMS')
    constraint.target = target
    old_target_action = target.animation_data.action
    run_bake(parent, [child])
    assert constraint.mute
    assert target.animation_data.action == old_target_action
    print('Test D PASS')


def test_e_driver_and_nla_source():
    reset_scene()
    parent = make_object('E_Parent')
    child = make_object('E_Child')
    key(parent, 'location', 1, (0, 0, 0))
    key(parent, 'location', 11, (5, 0, 0))
    key(child, 'location', 1, (2, 1, 0))
    key(child, 'location', 11, (7, 3, 0))
    anim = child.animation_data
    source_action = anim.action
    track = anim.nla_tracks.new()
    track.name = 'Imported source NLA'
    track.strips.new('Source', 1, source_action)
    anim.action = None
    driver_curve = child.driver_add('location', 0)
    driver_curve.driver.expression = 'frame * 0.25'
    run_bake(parent, [child])
    assert track.mute
    assert driver_curve.mute
    assert child.animation_data.action != source_action
    print('Test E Driver/NLA PASS')


def test_failure_safety():
    reset_scene()
    parent = make_object('Failure_Parent')
    child = make_object('Failure_Child')
    key(parent, 'location', 1, (0, 0, 0))
    key(parent, 'location', 11, (5, 0, 0))
    key(child, 'location', 1, (1, 0, 0))
    key(child, 'location', 11, (6, 0, 0))
    old_action = child.animation_data.action
    source = captured_world([child])
    bpy.ops.object.select_all(action='DESELECT')
    parent.select_set(True)
    child.select_set(True)
    bpy.context.view_layer.objects.active = parent
    scene.frame_set(4)
    original_bake = addon._bake_child

    def fail_after_baking(*args):
        original_bake(*args)
        raise RuntimeError('simulated bake failure')

    addon._bake_child = fail_after_baking
    try:
        try:
            assert bpy.ops.object.renew_parent_animation() == {'CANCELLED'}
        except RuntimeError as exc:
            assert 'simulated bake failure' in str(exc)
    finally:
        addon._bake_child = original_bake
    assert child.parent is None
    assert child.animation_data.action == old_action
    assert scene.frame_current == 4
    for frame in range(1, 12):
        scene.frame_set(frame)
        graph = bpy.context.evaluated_depsgraph_get()
        assert addon._matrix_difference(
            child.evaluated_get(graph).matrix_world, source[child][frame]
        ) < 1e-5
    print('Failure rollback PASS')

    reset_scene()
    parent = make_object('Cycle_Parent')
    child = make_object('Cycle_Child')
    parent.parent = child
    parent.select_set(True)
    child.select_set(True)
    bpy.context.view_layer.objects.active = parent
    try:
        assert bpy.ops.object.renew_parent_animation() == {'CANCELLED'}
    except RuntimeError as exc:
        assert 'Parent cycle' in str(exc)
    assert parent.parent == child and child.parent is None
    print('Cycle rejection PASS')

    reset_scene()
    parent = make_object('Singular_Parent')
    child = make_object('Singular_Child')
    parent.scale = (0, 1, 1)
    parent.select_set(True)
    child.select_set(True)
    bpy.context.view_layer.objects.active = parent
    try:
        assert bpy.ops.object.renew_parent_animation() == {'CANCELLED'}
    except RuntimeError as exc:
        assert 'not invertible' in str(exc)
    assert child.parent is None
    print('Singular matrix rejection PASS')


test_a_translation()
test_b_translation_rotation()
test_c_multiple_children()
test_d_constraint_source()
test_e_driver_and_nla_source()
test_failure_safety()
print('ALL TESTS PASS')
