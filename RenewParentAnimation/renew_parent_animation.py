"""Bake evaluated world motion into parent-relative Blender object animation."""

bl_info = {
    "name": "Renew Parent Animation",
    "author": "LUNARMAXSCRIPT",
    "version": (1, 0, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > Animation Tools",
    "description": "Parent selected children to the active object without changing sampled world motion",
    "category": "Animation",
}

import math

import bpy
from mathutils import Matrix


POSITION_TOLERANCE = 1e-4  # Blender units
ROTATION_TOLERANCE_DEG = 0.01
DECOMPOSITION_TOLERANCE = 1e-5
TRANSFORM_PATHS = {
    "location", "rotation_euler", "rotation_quaternion", "rotation_axis_angle",
    "scale", "delta_location", "delta_rotation_euler",
    "delta_rotation_quaternion", "delta_scale", "matrix_basis",
    "matrix_local", "matrix_world", "matrix_parent_inverse",
}


class BakeError(Exception):
    pass


def _world_matrix(obj, depsgraph):
    return obj.evaluated_get(depsgraph).matrix_world.copy()


def _matrix_difference(a, b):
    return max(abs(a[row][col] - b[row][col])
               for row in range(4) for col in range(4))


def _local_samples(parent_world, child_world, frames, child_name):
    samples = []
    previous_rotation = None
    for frame in frames:
        try:
            local = parent_world[frame].inverted() @ child_world[frame]
        except (ValueError, ZeroDivisionError) as exc:
            raise BakeError(f"Frame {frame}: parent World Matrix is not invertible") from exc

        location, rotation, scale = local.decompose()
        reconstructed = Matrix.LocRotScale(location, rotation, scale)
        limit = DECOMPOSITION_TOLERANCE * max(
            1.0, max(abs(local[row][col]) for row in range(4) for col in range(4))
        )
        if _matrix_difference(local, reconstructed) > limit:
            raise BakeError(
                f"{child_name}, frame {frame}: local matrix contains shear that "
                "Blender object TRS keys cannot represent"
            )
        if previous_rotation is not None and previous_rotation.dot(rotation) < 0:
            rotation.negate()
        samples.append((location.copy(), rotation.copy(), scale.copy()))
        previous_rotation = rotation
    return samples


def _is_transform_driver(fcurve):
    return fcurve.data_path.split("[", 1)[0] in TRANSFORM_PATHS


def _snapshot_child(child):
    anim = child.animation_data
    return {
        "parent": child.parent,
        "parent_type": child.parent_type,
        "parent_bone": child.parent_bone,
        "parent_inverse": child.matrix_parent_inverse.copy(),
        "basis": child.matrix_basis.copy(),
        "rotation_mode": child.rotation_mode,
        "delta_location": child.delta_location.copy(),
        "delta_rotation_euler": child.delta_rotation_euler.copy(),
        "delta_rotation_quaternion": child.delta_rotation_quaternion.copy(),
        "delta_scale": child.delta_scale.copy(),
        "constraints": [(constraint, constraint.mute) for constraint in child.constraints],
        "anim_existed": anim is not None,
        "action": anim.action if anim else None,
        "action_slot": getattr(anim, "action_slot", None) if anim and anim.action else None,
        "nla": [(track, track.mute) for track in anim.nla_tracks] if anim else [],
        "drivers": [(curve, curve.mute) for curve in anim.drivers] if anim else [],
    }


def _disable_old_transform_source(child):
    # Preserve source datablocks for Undo/manual inspection, but stop their
    # transform evaluation before assigning the new parent-relative Action.
    for constraint in child.constraints:
        constraint.mute = True
    anim = child.animation_data
    if anim:
        for track in anim.nla_tracks:
            track.mute = True
        for curve in anim.drivers:
            if _is_transform_driver(curve):
                curve.mute = True
        anim.action = None


def _reset_delta_transforms(child):
    child.delta_location = (0.0, 0.0, 0.0)
    child.delta_rotation_euler = (0.0, 0.0, 0.0)
    child.delta_rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    child.delta_scale = (1.0, 1.0, 1.0)


def _action_fcurves(action, slot):
    # Action.fcurves works for Blender 4.x legacy and single-slot actions.
    # The layer route also covers slotted actions where that facade is empty.
    found = set()
    for curve in action.fcurves:
        found.add(curve.as_pointer())
        yield curve
    if slot is None:
        return
    for layer in getattr(action, "layers", ()):
        for strip in layer.strips:
            bag = strip.channelbag(slot, ensure=False)
            if bag is not None:
                for curve in bag.fcurves:
                    if curve.as_pointer() not in found:
                        yield curve


def _bake_child(child, parent, frames, samples):
    _disable_old_transform_source(child)
    child.parent = parent
    child.parent_type = 'OBJECT'
    child.matrix_parent_inverse = Matrix.Identity(4)
    _reset_delta_transforms(child)
    child.rotation_mode = 'QUATERNION'

    for frame, (location, rotation, scale) in zip(frames, samples):
        child.location = location
        child.rotation_quaternion = rotation
        child.scale = scale
        for path in ("location", "rotation_quaternion", "scale"):
            if not child.keyframe_insert(data_path=path, frame=frame, group="Renew Parent Animation"):
                raise BakeError(f"{child.name}: failed to key {path} at frame {frame}")

    anim = child.animation_data
    if anim is None or anim.action is None:
        raise BakeError(f"{child.name}: no native Action was created")
    for curve in _action_fcurves(anim.action, getattr(anim, "action_slot", None)):
        for point in curve.keyframe_points:
            point.interpolation = 'LINEAR'
    return anim.action


def _restore_child(child, state, new_action):
    anim = child.animation_data
    if anim:
        # A failed _bake_child may already have inserted keys before it could
        # return its Action to the caller.
        new_action = new_action or anim.action
        anim.action = None
    child.parent = state["parent"]
    child.parent_type = state["parent_type"]
    child.parent_bone = state["parent_bone"]
    child.matrix_parent_inverse = state["parent_inverse"]
    child.rotation_mode = state["rotation_mode"]
    child.matrix_basis = state["basis"]
    child.delta_location = state["delta_location"]
    child.delta_rotation_euler = state["delta_rotation_euler"]
    child.delta_rotation_quaternion = state["delta_rotation_quaternion"]
    child.delta_scale = state["delta_scale"]
    for constraint, mute in state["constraints"]:
        constraint.mute = mute
    if anim:
        for track, mute in state["nla"]:
            track.mute = mute
        for curve, mute in state["drivers"]:
            curve.mute = mute
        anim.action = state["action"]
        if state["action_slot"] is not None and hasattr(anim, "action_slot"):
            anim.action_slot = state["action_slot"]
        if not state["anim_existed"] and anim.action is None and not anim.nla_tracks and not anim.drivers:
            child.animation_data_clear()
    if new_action is not None and new_action.users == 0:
        bpy.data.actions.remove(new_action)


def _validate_world_motion(context, frames, children, original_world):
    scene = context.scene
    max_position = 0.0
    max_rotation = 0.0
    per_child = {}
    for child in children:
        per_child[child.name] = [0.0, 0.0]
    for frame in frames:
        scene.frame_set(frame)
        depsgraph = context.evaluated_depsgraph_get()
        for child in children:
            current = _world_matrix(child, depsgraph)
            original = original_world[child][frame]
            position_error = (current.translation - original.translation).length
            original_rotation = original.to_quaternion()
            current_rotation = current.to_quaternion()
            rotation_error = math.degrees(original_rotation.rotation_difference(current_rotation).angle)
            max_position = max(max_position, position_error)
            max_rotation = max(max_rotation, rotation_error)
            per_child[child.name][0] = max(per_child[child.name][0], position_error)
            per_child[child.name][1] = max(per_child[child.name][1], rotation_error)
    return max_position, max_rotation, per_child


def _check_selection(context):
    parent = context.view_layer.objects.active
    if parent is None:
        raise BakeError("No active object. Select children first, then make the parent active")
    selected = list(context.selected_objects)
    if len(selected) == 1 and selected[0] == parent:
        raise BakeError("Only the parent is selected; select at least one child")
    if parent not in selected:
        raise BakeError("The active parent must also be selected")
    children = [obj for obj in selected if obj != parent]
    if not children:
        raise BakeError("No child objects selected")
    if any(child == parent for child in children):
        raise BakeError("Parent and child cannot be the same object")
    for child in children:
        ancestor = parent
        while ancestor is not None:
            if ancestor == child:
                raise BakeError(f"Parent cycle: {child.name} is an ancestor of {parent.name}")
            ancestor = ancestor.parent
    return parent, children


class OBJECT_OT_renew_parent_animation(bpy.types.Operator):
    bl_idname = "object.renew_parent_animation"
    bl_label = "Renew Parent Animation"
    bl_description = "Bake selected children's evaluated world motion relative to the active parent"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        scene = context.scene
        original_frame = scene.frame_current
        original_selection = tuple(context.selected_objects)
        original_active = context.view_layer.objects.active
        states = {}
        new_actions = {}
        mutation_started = False
        try:
            parent, children = _check_selection(context)
            frames = list(range(scene.frame_start, scene.frame_end + 1))
            if not frames:
                raise BakeError("Scene frame range is empty")

            # Phase A: the hierarchy, source constraints, actions and transforms
            # remain untouched until every evaluated source matrix is captured.
            parent_world = {}
            original_world = {child: {} for child in children}
            for frame in frames:
                scene.frame_set(frame)
                depsgraph = context.evaluated_depsgraph_get()
                parent_world[frame] = _world_matrix(parent, depsgraph)
                for child in children:
                    original_world[child][frame] = _world_matrix(child, depsgraph)

            # Compute and reject non-invertible/sheared locals before mutation.
            local_samples = {
                child: _local_samples(parent_world, original_world[child], frames, child.name)
                for child in children
            }
            states = {child: _snapshot_child(child) for child in children}
            mutation_started = True
            for child in children:
                new_actions[child] = _bake_child(child, parent, frames, local_samples[child])

            max_position, max_rotation, per_child = _validate_world_motion(
                context, frames, children, original_world
            )
            passed = (max_position <= POSITION_TOLERANCE
                      and max_rotation <= ROTATION_TOLERANCE_DEG)
            print("Renew Parent Animation complete")
            print(f"Children: {len(children)}")
            print(f"Frames: {len(frames)} ({frames[0]}-{frames[-1]})")
            print(f"Max position error: {max_position:.9f}")
            print(f"Max rotation error: {max_rotation:.9f} deg")
            for name, (position, rotation) in per_child.items():
                print(f"  {name}: position {position:.9f}, rotation {rotation:.9f} deg")
            print("PASS" if passed else "WARNING: sampled world motion exceeds tolerance")
            summary = (f"{len(children)} children, {len(frames)} frames; "
                       f"position {max_position:.6g}, rotation {max_rotation:.6g} deg")
            self.report({'INFO'} if passed else {'WARNING'}, summary)
            return {'FINISHED'}
        except Exception as exc:
            if mutation_started:
                for child, state in reversed(list(states.items())):
                    try:
                        _restore_child(child, state, new_actions.get(child))
                    except Exception as rollback_exc:
                        print(f"Renew Parent Animation rollback failed for {child.name}: {rollback_exc}")
            self.report({'ERROR'}, str(exc))
            print(f"Renew Parent Animation failed: {exc}")
            return {'CANCELLED'}
        finally:
            scene.frame_set(original_frame)
            # Selection normally remains unchanged, but explicitly restore it
            # if a Blender update or future implementation changed it.
            if set(context.selected_objects) != set(original_selection):
                selected = set(original_selection)
                for obj in context.view_layer.objects:
                    obj.select_set(obj in selected)
            if context.view_layer.objects.active != original_active:
                context.view_layer.objects.active = original_active


class VIEW3D_PT_renew_parent_animation(bpy.types.Panel):
    bl_label = "Animation Tools"
    bl_idname = "VIEW3D_PT_renew_parent_animation"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Animation Tools"

    def draw(self, context):
        self.layout.operator(OBJECT_OT_renew_parent_animation.bl_idname)


CLASSES = (OBJECT_OT_renew_parent_animation, VIEW3D_PT_renew_parent_animation)


def register():
    for cls in CLASSES:
        bpy.utils.register_class(cls)


def unregister():
    for cls in reversed(CLASSES):
        bpy.utils.unregister_class(cls)


if __name__ == "__main__":
    register()
