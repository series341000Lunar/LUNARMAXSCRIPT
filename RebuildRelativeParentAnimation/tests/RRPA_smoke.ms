/* Run only in a disposable 3ds Max scene or 3dsmaxbatch. */
global RRPA_TEST_REPORT = "C:\\Users\\user\\Documents\\MAXSCRIPT\\RebuildRelativeParentAnimation\\tests\\RRPA-smoke-result.txt"
global RRPA_TEST_PASSED = 0
global RRPA_TEST_FAILED = 0
global rrpaRebuild

fn rrpaTestLine message =
(
    local output = openFile RRPA_TEST_REPORT mode:"a"
    format "%\n" message to:output
    close output
)

fn rrpaAssert conditionValue message =
(
    if conditionValue then
    (
        RRPA_TEST_PASSED += 1
        rrpaTestLine ("PASS: " + message)
    )
    else
    (
        RRPA_TEST_FAILED += 1
        rrpaTestLine ("FAIL: " + message)
    )
)

fn rrpaSetSourceKey nodeValue frameValue positionValue eulerValue =
(
    at time frameValue with animate on
    (
        nodeValue.position = positionValue
        nodeValue.rotation = eulerToQuat eulerValue order:1
    )
)

fn rrpaCaseA =
(
    resetMaxFile #noPrompt
    animationRange = interval 0f 10f
    local p = box name:"A_Parent" pos:[0,0,0]
    local c = box name:"A_Child" pos:[2,0,0]
    local originalBase = c.baseObject
    local originalOffset = c.objectOffsetPos
    local parentController = p.transform.controller
    rrpaSetSourceKey p 0f [0,0,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey p 10f [10,0,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey c 0f [2,0,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey c 10f [12,0,0] (eulerAngles 0 0 0)
    local report = rrpaRebuild p #(c)
    rrpaAssert report[1] ("A translation PASS: " + report[9])
    rrpaAssert (c.parent == p) "A hierarchy created"
    rrpaAssert (classOf c.transform.controller == PRS) "A native PRS controller"
    rrpaAssert (classOf c.rotation.controller == Euler_XYZ) "A editable Euler XYZ"
    at time 0f rrpaAssert (distance c.transform.controller.value.translationPart [2,0,0] < 0.001) "A frame 0 relative offset"
    at time 10f rrpaAssert (distance c.transform.controller.value.translationPart [2,0,0] < 0.001) "A frame 10 relative offset"
    rrpaAssert (c.baseObject == originalBase and c.objectOffsetPos == originalOffset) "A geometry and object offset unchanged"
    rrpaAssert (p.transform.controller == parentController) "A parent controller unchanged"
)

fn rrpaCaseB =
(
    resetMaxFile #noPrompt
    animationRange = interval 0f 10f
    local p = box name:"B_Parent"
    local c = box name:"B_Child"
    rrpaSetSourceKey p 0f [0,0,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey p 10f [10,0,0] (eulerAngles 0 0 90)
    rrpaSetSourceKey c 0f [2,0,0] (eulerAngles 0 0 20)
    rrpaSetSourceKey c 10f [10,2,0] (eulerAngles 0 0 120)
    local report = rrpaRebuild p #(c)
    rrpaAssert report[1] ("B parent rotation and child orbit PASS: " + report[9])
    rrpaAssert (report[1] and report[3] <= 0.0001 and report[4] <= 0.01) "B numeric world TR within tolerance"
)

fn rrpaCaseC =
(
    resetMaxFile #noPrompt
    animationRange = interval 0f 10f
    local p = box name:"C_Parent"
    local children = #()
    rrpaSetSourceKey p 0f [0,0,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey p 10f [5,2,0] (eulerAngles 0 0 30)
    for i = 1 to 3 do
    (
        local c = box name:("C_Child_" + i as string)
        rrpaSetSourceKey c 0f [i*2,0,0] (eulerAngles 0 0 (i*10))
        rrpaSetSourceKey c 10f [i*2+5,2,0] (eulerAngles 0 0 (i*10+30))
        append children c
    )
    local report = rrpaRebuild p children
    rrpaAssert report[1] ("C three children PASS: " + report[9])
    for c in children do rrpaAssert (c.parent == p) ("C hierarchy " + c.name)
)

fn rrpaCaseD =
(
    resetMaxFile #noPrompt
    animationRange = interval 0f 10f
    local p = box name:"D_Parent"
    local target = point name:"D_ConstraintTarget"
    local c = box name:"D_Child"
    rrpaSetSourceKey p 0f [0,0,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey p 10f [3,0,0] (eulerAngles 0 0 45)
    rrpaSetSourceKey target 0f [2,0,0] (eulerAngles 0 0 15)
    rrpaSetSourceKey target 10f [4,4,0] (eulerAngles 0 0 75)
    c.position.controller = Position_Constraint()
    c.position.controller.constraints.appendTarget target 100.0
    c.rotation.controller = Orientation_Constraint()
    c.rotation.controller.constraints.appendTarget target 100.0
    local report = rrpaRebuild p #(c)
    rrpaAssert report[1] ("D Position/Orientation Constraint source PASS: " + report[9])
    rrpaAssert (classOf c.position.controller == Position_XYZ and classOf c.rotation.controller == Euler_XYZ) "D constraint source replaced with editable PRS"
)

fn rrpaCaseE =
(
    resetMaxFile #noPrompt
    animationRange = interval 0f 10f
    local body = box name:"E_Body"
    local turret = box name:"E_Turret"
    local gun = box name:"E_Gun"
    local sensor = box name:"E_Sensor"
    local nodes = #(body,turret,gun,sensor)
    for i = 1 to nodes.count do
    (
        rrpaSetSourceKey nodes[i] 0f [i*2,0,0] (eulerAngles 0 0 (i*5))
        rrpaSetSourceKey nodes[i] 10f [i*2+5,i,0] (eulerAngles 0 0 (i*10+40))
    )
    local report1 = rrpaRebuild body #(turret)
    local report2 = rrpaRebuild turret #(gun)
    local report3 = rrpaRebuild gun #(sensor)
    rrpaAssert (report1[1] and report2[1] and report3[1]) "E three sequential rebuilds PASS"
    rrpaAssert (turret.parent == body and gun.parent == turret and sensor.parent == gun) "E four-level hierarchy"
)

fn rrpaCaseScale =
(
    resetMaxFile #noPrompt
    animationRange = interval 0f 10f
    local p = box name:"Scale_Parent"
    local c = box name:"Scale_Child" pos:[2,0,0]
    p.scale = [2,2,2]
    c.scale = [3,3,3]
    rrpaSetSourceKey p 0f [0,0,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey p 10f [10,0,0] (eulerAngles 0 0 30)
    rrpaSetSourceKey c 0f [2,0,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey c 10f [12,0,0] (eulerAngles 0 0 30)
    local report = rrpaRebuild p #(c) bakeScale:true
    rrpaAssert report[1] ("Scale ON full basis PASS: " + report[9])
    rrpaAssert (c.parent == p and classOf c.scale.controller == linear_scale) "Scale ON native controller"
)

fn rrpaCaseEuler =
(
    resetMaxFile #noPrompt
    animationRange = interval 0f 10f
    local p = box name:"Euler_Parent"
    local c = box name:"Euler_Child"
    rrpaSetSourceKey c 0f [2,0,0] (eulerAngles 0 0 179)
    rrpaSetSourceKey c 10f [2,0,0] (eulerAngles 0 0 181)
    local report = rrpaRebuild p #(c)
    local z0 = 0.0
    local z10 = 0.0
    at time 0f (z0 = c.rotation.controller.z_rotation)
    at time 10f (z10 = c.rotation.controller.z_rotation)
    rrpaAssert report[1] ("Euler 180 boundary PASS: " + report[9])
    rrpaAssert (abs (z10 - z0) < 180.0) ("Euler continuity: " + (z0 as string) + " to " + (z10 as string))
)

fn rrpaCaseExistingParent =
(
    resetMaxFile #noPrompt
    animationRange = interval 0f 10f
    local oldParent = box name:"Old_Parent"
    local newParent = box name:"New_Parent"
    local c = box name:"Reparent_Child" pos:[2,0,0]
    c.parent = oldParent
    rrpaSetSourceKey oldParent 0f [0,0,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey oldParent 10f [3,0,0] (eulerAngles 0 0 20)
    rrpaSetSourceKey newParent 0f [1,1,0] (eulerAngles 0 0 0)
    rrpaSetSourceKey newParent 10f [4,1,0] (eulerAngles 0 0 20)
    local report = rrpaRebuild newParent #(c)
    rrpaAssert report[1] ("Existing Parent replacement PASS: " + report[9])
    rrpaAssert (c.parent == newParent) "Existing Parent replaced"
)

fn rrpaCaseSingular =
(
    resetMaxFile #noPrompt
    animationRange = interval 0f 10f
    local p = box name:"Singular_Parent"
    local c = box name:"Singular_Child"
    p.scale = [0,1,1]
    local oldController = c.transform.controller
    local report = rrpaRebuild p #(c)
    rrpaAssert (not report[1]) ("Singular Parent rejected: " + report[9])
    rrpaAssert (c.parent == undefined and c.transform.controller == oldController) "Singular rejection leaves Child unchanged"
)

try (deleteFile RRPA_TEST_REPORT) catch()
rrpaTestLine "Rebuild Relative Parent Animation smoke - 3ds Max 2027"
try
(
    fileIn "C:\\Users\\user\\Documents\\MAXSCRIPT\\RebuildRelativeParentAnimation\\src\\LG_RebuildRelativeParentAnimation.ms"
    rrpaTestLine "Source loaded"
    rrpaCaseA()
    rrpaCaseB()
    rrpaCaseC()
    rrpaCaseD()
    rrpaCaseE()
    rrpaCaseScale()
    rrpaCaseEuler()
    rrpaCaseExistingParent()
    rrpaCaseSingular()
)
catch
(
    RRPA_TEST_FAILED += 1
    rrpaTestLine ("FATAL: " + getCurrentException() as string)
)
rrpaTestLine ("Passed: " + RRPA_TEST_PASSED as string)
rrpaTestLine ("Failed: " + RRPA_TEST_FAILED as string)
