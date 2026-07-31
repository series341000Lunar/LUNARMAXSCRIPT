# Lunar Transform Assistant

Lunar Transform Assistant is a MAXScript-only production utility for Autodesk 3ds Max 2026. It captures a Source and Targets explicitly, copies or instances supported transform channels, copies or instances Base Objects, manages transform locks, and clears node-level hidden state.

The implementation favors predictable behavior and preservation of existing scene data. Unsupported controller structures are skipped rather than converted.

## Files

```text
src/LunarTransformAssistant.ms
macros/LunarTransformAssistant.mcr
README.md
```

## Installation

### Recommended user-scripts layout

1. Create this folder under the 3ds Max user scripts directory:

   ```text
   <3ds Max user scripts>\LunarTransformAssistant
   ```

2. Copy the project folders so the result is:

   ```text
   <3ds Max user scripts>\LunarTransformAssistant\src\LunarTransformAssistant.ms
   <3ds Max user scripts>\LunarTransformAssistant\macros\LunarTransformAssistant.mcr
   ```

3. In 3ds Max, choose **Scripting > Run Script** and run:

   ```text
   <3ds Max user scripts>\LunarTransformAssistant\macros\LunarTransformAssistant.mcr
   ```

Running the `.mcr` registers or refreshes the MacroScript action. The MacroScript contains only launcher logic and loads the main `.ms` file when executed.

### Register the MacroScript in the UI

1. Open **Customize > Customize User Interface**.
2. Choose the toolbar, menu, quad menu, or keyboard tab where the action should appear.
3. Select category **Lunar Tools**.
4. Add **Lunar Transform Assistant**.

MacroScript metadata:

```text
Category: Lunar Tools
Internal name: LunarTransformAssistant
Tooltip: Lunar Transform Assistant
```

The launcher first looks for `..\src\LunarTransformAssistant.ms` relative to its own file. It then checks the recommended user-scripts installation path.

If the rollout is already open, launching the MacroScript focuses the existing dialog instead of creating a duplicate or resetting the captured Source and Targets. If the existing rollout was closed, it is reopened with its stored rollout state.

For a one-off launch without registering the action, run `src/LunarTransformAssistant.ms` directly from **Scripting > Run Script**.

## Source and Target workflow

Selection array order is never interpreted as click order.

1. Select exactly one scene node.
2. Press **Set Source**.
3. Select one or more intended Target nodes.
4. Press **Set Targets**.
5. Choose an operation.

The Source is automatically excluded if it is present when Targets are captured. Stored nodes are validated before every Source/Target operation. Deleted or invalid Targets are removed safely, and a deleted Source is cleared.

**Clear Targets** clears only the stored Target list. Transform Lock and Visibility operations use the current 3ds Max selection and do not use stored Source or Targets.

## Copy versus Instance

**Copy** writes the current evaluated value or creates an independent Base Object copy:

- Selected transform channels copy values only at the current frame.
- Full Transform Copy assigns the Source world transform matrix.
- Base Object Copy assigns an independent copy of the Source Base Object.
- Later Source changes do not automatically update copied Targets.

**Instance** shares an animation controller or Base Object:

- Selected-channel Instance shares the corresponding component controller.
- Full Transform Instance shares the complete transform controller.
- Base Object Instance shares the Source Base Object.
- The relationship is bidirectional. Editing either side may affect every node sharing that controller or Base Object.

Instance operations are intentionally explicit and can replace the Target controller at the exact requested scope. No controller is converted merely to make an operation available.

## Transform channel behavior

The checkbox matrix addresses:

```text
Position X, Y, Z
Rotation X, Y, Z
Scale X, Y, Z
```

Transform Copy checkboxes and Transform Lock checkboxes are separate controls.

### Current-value Copy

For independent component tracks, the tool reads the current Source component-controller value and writes it to the corresponding Target component controller at `currentTime`.

Supported independent component structures:

- Position: `Position_XYZ`
- Rotation: `Euler_XYZ`
- Scale: `ScaleXYZ`

Source and Target `Euler_XYZ` controllers must use the same axis order. A mismatch is skipped because the same X/Y/Z angle does not have the same coordinate interpretation under a different axis order.

The ordinary default `Bezier_Scale` controller has no separately assignable X/Y/Z subcontrollers. For **Copy Selected Channels** only, a Source/Target `Bezier_Scale` pair is supported by composing one current scale value: checked components come from the Source and unchecked components retain the Target's evaluated values. This does not replace the scale controller or copy keys. Because `Bezier_Scale` stores a composite scale value, writing at an animated frame may update or create a composite scale key according to the current 3ds Max animation state.

### Selected-channel Instance

Selected-channel Instance is available only when both Source and Target expose a compatible, writable independent component controller:

- `Position_XYZ`
- `Euler_XYZ` with matching axis order
- `ScaleXYZ`

The tool inspects the actual category controller and component subAnim. It assigns the Source component controller to only the checked Target component. Unchecked components remain untouched.

The tool does not replace a controller with Position XYZ, Euler XYZ, or Scale XYZ to force compatibility.

## Controller limitations

The following cases are intentionally unsupported for selected-channel Copy or Instance unless they expose the exact supported safe structure described above:

- Quaternion and TCB Rotation
- Rotation List, Position List, and Scale List
- LookAt and Path constraints
- Script controllers
- CAT and Biped controllers
- plugin-specific controllers
- controller structures with missing or non-writable component subAnims
- different Euler axis orders

`Bezier_Scale` supports current-value Copy as described above, but not individual-axis controller Instance.

Unsupported cases are skipped with `[LTA][WARN]` or `[LTA][ERROR]` details in the MAXScript Listener. The tool never automatically changes controller type, removes keys, or creates constraints or Wire Parameters.

## Full Transform

**Copy Full Transform** assigns the Source world transform to each Target. Target parenting is not changed. After assignment, the evaluated Target world matrix is compared with the Source matrix; a rejected or partial result is reported rather than counted as success.

**Instance Full Transform** explicitly assigns the complete Source transform controller to each Target. If Source and Target parents differ, the operation is allowed but a warning explains that the same shared local controller can produce a different world-space result. Parenting is never changed to compensate.

Full-transform operations can fail or produce a rejected verification result when transform locks, constraints, special rigs, or unsupported controllers prevent assignment.

## Base Object

Initial Base Object support is limited to ordinary Geometry Base Objects, including primitives and common Editable Poly-compatible geometry.

**Copy Base Object** performs the conceptual operation:

```maxscript
target.baseObject = copy source.baseObject
```

**Instance Base Object** performs the conceptual operation:

```maxscript
target.baseObject = source.baseObject
```

Both operations assign only `baseObject`. They do not clone whole nodes, copy the Source modifier stack, collapse either stack, change parenting, rename Targets, or copy materials. Existing Target modifiers remain above the replacement Base Object when 3ds Max accepts the stack combination.

Unsupported Base Object cases include:

- non-Geometry Base Objects
- XRef Base Objects
- group heads
- incompatible object/modifier stack combinations rejected by 3ds Max

## Transform locks

Lock operations use the current selection. The checked-lock matrix is independent from the transform-copy matrix.

The 3ds Max transform-lock bit order is:

```text
1 Position X
2 Position Y
3 Position Z
4 Rotation X
5 Rotation Y
6 Rotation Z
7 Scale X
8 Scale Y
9 Scale Z
```

**Lock Checked** and **Unlock Checked** read the existing bitarray, change only checked bits, and verify that unchecked bits retained their state. **Lock All** and **Unlock All** set and verify all nine bits. Controller types and animation keys are not changed.

## Visibility

**Unhide Selected Nodes** uses the current selection and sets only:

```maxscript
node.isNodeHidden = false
```

It does not unhide the node's Layer. If the Layer remains hidden, the Listener reports a warning. Other objects on the Layer are never modified.

## Undo, diagnostics, and status

- Each scene-changing button executes its batch in one named undo block.
- One button press is intended to be reversible with one Undo where 3ds Max supports undo for that property/controller assignment.
- Multiple Targets are processed as a batch.
- One Target failure does not stop the remaining Targets.
- `redrawViews()` is called at most once after a batch, and only when at least one change was verified.
- The UI status line gives a concise result.
- Per-node reasons and batch summaries are printed with `[LTA][INFO]`, `[LTA][WARN]`, and `[LTA][ERROR]` prefixes.

## Supported object types

Primary scope:

- ordinary Geometry nodes
- Standard PRS transform controllers
- Position XYZ
- Euler XYZ
- Scale XYZ
- ordinary Bezier Scale current-value copying
- primitive Base Objects
- Editable Poly-compatible Geometry Base Objects
- multiple Targets

Special rigs, XRefs, group heads, non-Geometry Base Objects, and plugin-specific controllers are outside V1 support.

## Known limitations

- An automated smoke test was completed in 3ds Max 2026.3.3 Batch, but the full interactive UI checklist below has not been completed by a human operator.
- Selected transform channels are controller-space components. The tool does not reinterpret components between different controller types or Euler axis orders.
- `Bezier_Scale` selected-channel Copy writes a composite current scale value while preserving unchecked evaluated components; it cannot instance individual axis controllers.
- Current-value assignment follows 3ds Max's animation state at the current frame. With animated controllers, 3ds Max may update/create a key according to its normal controller and Animate-mode behavior.
- Full Transform Instance shares local controller output. Different parents can therefore produce different world transforms.
- Base Object replacement compatibility is ultimately decided by 3ds Max. A Target modifier stack that cannot accept the new Base Object is skipped/failed by the host assignment.
- Node-level unhide cannot make an object visible when its Layer, category, or frozen-display state still hides it.
- Undo support for controller and Base Object assignments must be verified in the target 3ds Max 2026 build.

## Manual runtime test checklist

### Source and Target

- [ ] Set one valid Source.
- [ ] Set one Target.
- [ ] Set multiple Targets.
- [ ] Delete a stored Target and run an operation.
- [ ] Accidentally include Source in Target selection.

### Transform Copy

- [ ] Copy only Position X.
- [ ] Copy Position X and Z.
- [ ] Copy Rotation Y.
- [ ] Copy non-uniform Scale X only.
- [ ] Confirm unchecked channels remain unchanged.
- [ ] Test at a non-zero animation frame.

### Transform Instance

- [ ] Instance Position X with Position XYZ controllers.
- [ ] Confirm Source and Target share the controller.
- [ ] Modify the Target and confirm Source also changes.
- [ ] Test unsupported controller types.
- [ ] Confirm unsupported operations leave Target unchanged.

### Full Transform

- [ ] Copy full transform without parents.
- [ ] Copy full transform with identical parents.
- [ ] Copy full transform with different parents.
- [ ] Instance full transform with identical parents.
- [ ] Confirm different-parent warning appears.

### Base Object

- [ ] Sphere Source to Box Target.
- [ ] Confirm Target transform remains unchanged.
- [ ] Confirm Target material remains unchanged.
- [ ] Confirm Target modifiers remain.
- [ ] Confirm Copy produces independent geometry.
- [ ] Confirm Instance shares the Base Object.
- [ ] Test multiple Targets.

### Visibility

- [ ] Hide a selected node and unhide it.
- [ ] Hide its Layer and test the warning.
- [ ] Confirm other Layer objects remain unchanged.

### Transform Lock

- [ ] Lock Position X only.
- [ ] Add Rotation Y lock while preserving Position X.
- [ ] Unlock Position X while preserving Rotation Y.
- [ ] Lock All.
- [ ] Unlock All.
- [ ] Test multiple selected nodes.

### Undo

- [ ] Confirm each button press can be undone as one operation where supported.

## Verification

### Static code review completed

The implementation was reviewed for:

- explicit Source/Target capture without selection-order inference
- rollout-local state and a single intentional global rollout reference
- stale-node cleanup with `isValidNode`
- one undo context per scene-changing button path
- per-Target exception isolation and diagnostic summaries
- preservation of unchecked channel and lock states
- absence of controller conversion, stack collapse, `instanceReplace`, constraints, and Wire Parameters
- Base Object-only assignment with Target modifier-stack preservation
- one redraw at most after each changed batch
- duplicate MacroScript registration and dialog reopening behavior

### Runtime verification in 3ds Max completed (automated smoke scope)

The files were loaded in Autodesk 3ds Max 2026.3.3 Batch and the following checks passed:

- main rollout definition and open event
- MacroScript registration and launch/reopen
- Position X current-value Copy with Position XYZ
- Position X controller Instance with shared-controller verification
- partial X-only Copy for a default Bezier Scale pair while preserving Y/Z
- Lock Checked and Unlock Checked while preserving unchecked flags
- Base Object support validation
- Sphere Base Object Copy to a Box Target as an independent object
- Base Object Instance sharing
- Target Bend modifier preservation through Base Object Copy and Instance
- Full world-transform Copy with parent preservation
- Full transform-controller Instance with parent preservation

3ds Max Batch also reported unrelated errors from pre-existing third-party startup scripts (`nToolFloat` and `vexus_startup.ms`). No error was attributed to `LunarTransformAssistant.ms` or `LunarTransformAssistant.mcr`, and the Lunar smoke report completed all checks above.

### Manual interactive verification still required

Use the checklist above in the normal 3ds Max UI to verify button interaction, status-label presentation, Listener wording, one-step Undo behavior, non-zero-frame animation behavior, locked/constraint controller rejection, Layer-hidden warnings, unsupported rigs, and a wider range of production modifier stacks.

## License

This tool is licensed under the GNU General Public License v3.0.

See [../LICENSE](../LICENSE) for details.
