/*
    Real SME regression test for the Property Compatibility Layer.
    Creates 12 actual VRayMtl nodes in a disposable Slate view, selects them,
    and applies each override parameter independently through the production core.
*/

global LVMBO_SME_TEST_PASSED = 0
global LVMBO_SME_TEST_FAILED = 0
global LVMBO_SME_TEST_REPORT = "C:\\tmp\\lvmbo-sme-regression-report.txt"
global LunarVRayMtlBatchOverrideRollout
global LunarVRayMtlBatchOverrideCore

fn lvmboSmeWrite textValue =
(
    local stream = openFile LVMBO_SME_TEST_REPORT mode:"a"
    format "%\n" textValue to:stream
    close stream
)

fn lvmboSmeAssert condition label =
(
    if condition then
    (
        LVMBO_SME_TEST_PASSED += 1
        lvmboSmeWrite ("PASS: " + label)
    )
    else
    (
        LVMBO_SME_TEST_FAILED += 1
        lvmboSmeWrite ("FAIL: " + label)
    )
)

fn lvmboSmeColorsEqual leftColor rightColor =
(
    leftColor != undefined and rightColor != undefined and
    (abs (leftColor.r - rightColor.r)) <= 0.01 and
    (abs (leftColor.g - rightColor.g)) <= 0.01 and
    (abs (leftColor.b - rightColor.b)) <= 0.01
)

fn lvmboSmeFloatEqual leftValue rightValue =
(
    (abs (leftValue - rightValue)) <= 0.0001
)

fn lvmboSmeMakeVRay materialName =
(
    local materialValue = execute "VRayMtl()"
    materialValue.name = materialName
    materialValue
)

fn lvmboSmeResultText label resultValue semanticName =
(
    local rowValue = LunarVRayMtlBatchOverrideCore.findResultRow resultValue.rows semanticName
    if rowValue == undefined then
        label + " : Missing result row"
    else
        label + " : Success " + (rowValue[2] as string) + " | Unsupported " + (rowValue[3] as string) + " | Errors " + (rowValue[4] as string)
)

fn lvmboSmeRowPassed resultValue semanticName expectedCount =
(
    local rowValue = LunarVRayMtlBatchOverrideCore.findResultRow resultValue.rows semanticName
    rowValue != undefined and rowValue[2] == expectedCount and rowValue[3] == 0 and rowValue[4] == 0
)

try (deleteFile LVMBO_SME_TEST_REPORT) catch()
lvmboSmeWrite "Lunar VRayMtl Batch Override - real SME per-parameter regression"

smeTestViewIndex = 0

try
(
    resetMaxFile #noPrompt
    fileIn "C:\\Users\\user\\Documents\\MAXSCRIPT\\LunarVRayMtlBatchOverride\\src\\Lunar_VRayMtl_Batch_Override.ms"
    lvmboSmeWrite "STEP: source loaded"

    sme.Open()
    lvmboSmeWrite "STEP: SME opened"
    smeTestViewIndex = sme.CreateView "LVMBO_12_Material_Regression"
    lvmboSmeWrite ("STEP: view created, index=" + (smeTestViewIndex as string))
    sme.activeView = smeTestViewIndex
    smeTestView = sme.GetView smeTestViewIndex
    smeMaterials = #()
    lvmboSmeWrite "STEP: creating 12 nodes"

    for materialIndex = 1 to 12 do
    (
        smeMaterial = lvmboSmeMakeVRay ("LVMBO_SME_" + (materialIndex as string))
        lvmboSmeWrite ("STEP: material " + (materialIndex as string) + " created")
        append smeMaterials smeMaterial
        nodePosition = [0,0]
        lvmboSmeWrite ("STEP: creating node " + (materialIndex as string))
        smeTestView.CreateNode smeMaterial nodePosition
        lvmboSmeWrite ("STEP: node " + (materialIndex as string) + " created")
    )

    smeTestView.SetSelectedNodes smeMaterials
    lvmboSmeWrite "STEP: nodes selected"
    selectedResult = LunarVRayMtlBatchOverrideCore.getSMESelection()
    lvmboSmeAssert (selectedResult.ok and selectedResult.selectedNodeCount == 12 and selectedResult.materials.count == 12 and selectedResult.skippedNodeCount == 0) "SME selection: Selected 12 | Unique VRayMtl 12 | Skipped 0"

    directMaterial = selectedResult.materials[1]
    directProperties = #(#Diffuse, #Reflection, #reflection_glossiness, #brdf_useRoughness, #reflection_metalness, #Refraction, #refraction_glossiness)
    directPropertiesSupported = true
    for propertyName in directProperties while directPropertiesSupported do
        if not isProperty directMaterial propertyName do directPropertiesSupported = false
    lvmboSmeAssert directPropertiesSupported "Direct isProperty verification: all seven value/mode properties are supported"

    directOldValue = getProperty directMaterial #Diffuse
    setProperty directMaterial #Diffuse (color 123 45 67)
    directNewValue = getProperty directMaterial #Diffuse
    setProperty directMaterial #Diffuse directOldValue
    lvmboSmeAssert (lvmboSmeColorsEqual directNewValue (color 123 45 67) and lvmboSmeColorsEqual (getProperty directMaterial #Diffuse) directOldValue) "Direct set/get verification: Diffuse changed and restored"

    -- Test A: Base Color only.
    settingsA = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsA.baseColorEnabled = true
    settingsA.baseColor = color 120 130 140
    resultA = LunarVRayMtlBatchOverrideCore.applyOverrides selectedResult.materials settingsA
    valuesAOk = true
    for materialValue in selectedResult.materials while valuesAOk do
        if not lvmboSmeColorsEqual materialValue.Diffuse settingsA.baseColor do valuesAOk = false
    lvmboSmeWrite (lvmboSmeResultText "Base Color" resultA #baseColor)
    lvmboSmeAssert (lvmboSmeRowPassed resultA #baseColor 12 and valuesAOk) "Test A Base Color only"

    -- Test B: Reflection Color only.
    settingsB = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsB.reflectionColorEnabled = true
    settingsB.reflectionColor = color 210 220 230
    resultB = LunarVRayMtlBatchOverrideCore.applyOverrides selectedResult.materials settingsB
    valuesBOk = true
    for materialValue in selectedResult.materials while valuesBOk do
        if not lvmboSmeColorsEqual materialValue.Reflection settingsB.reflectionColor do valuesBOk = false
    lvmboSmeWrite (lvmboSmeResultText "Reflection Color" resultB #reflectionColor)
    lvmboSmeAssert (lvmboSmeRowPassed resultB #reflectionColor 12 and valuesBOk) "Test B Reflection Color only"

    -- Test C: Reflection Surface only, Glossiness 0.8.
    settingsC = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsC.surfaceEnabled = true
    settingsC.surfaceMode = #glossiness
    settingsC.surfaceValue = 0.8
    resultC = LunarVRayMtlBatchOverrideCore.applyOverrides selectedResult.materials settingsC
    valuesCOk = true
    for materialValue in selectedResult.materials while valuesCOk do
        if materialValue.brdf_useRoughness or not lvmboSmeFloatEqual materialValue.reflection_glossiness 0.8 do valuesCOk = false
    lvmboSmeWrite (lvmboSmeResultText "Surface" resultC #surface)
    lvmboSmeAssert (lvmboSmeRowPassed resultC #surface 12 and valuesCOk) "Test C Reflection Surface only"

    -- Test D: Metalness only.
    settingsD = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsD.metalnessEnabled = true
    settingsD.metalnessValue = 0.25
    resultD = LunarVRayMtlBatchOverrideCore.applyOverrides selectedResult.materials settingsD
    valuesDOk = true
    for materialValue in selectedResult.materials while valuesDOk do
        if not lvmboSmeFloatEqual materialValue.reflection_metalness 0.25 do valuesDOk = false
    lvmboSmeWrite (lvmboSmeResultText "Metalness" resultD #metalness)
    lvmboSmeAssert (lvmboSmeRowPassed resultD #metalness 12 and valuesDOk) "Test D Metalness only"

    -- Test E: Refraction Color only.
    settingsE = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsE.refractionColorEnabled = true
    settingsE.refractionColor = color 80 90 100
    resultE = LunarVRayMtlBatchOverrideCore.applyOverrides selectedResult.materials settingsE
    valuesEOk = true
    for materialValue in selectedResult.materials while valuesEOk do
        if not lvmboSmeColorsEqual materialValue.Refraction settingsE.refractionColor do valuesEOk = false
    lvmboSmeWrite (lvmboSmeResultText "Refraction Color" resultE #refractionColor)
    lvmboSmeAssert (lvmboSmeRowPassed resultE #refractionColor 12 and valuesEOk) "Test E Refraction Color only"

    -- Test F: Refraction Glossiness only. Preserve existing mode and store directly.
    for materialValue in selectedResult.materials do materialValue.brdf_useRoughness = true
    settingsF = LunarVRayMtlBatchOverrideCore.newSettings()
    settingsF.refractionGlossinessEnabled = true
    settingsF.refractionGlossinessValue = 0.7
    resultF = LunarVRayMtlBatchOverrideCore.applyOverrides selectedResult.materials settingsF
    valuesFOk = true
    for materialValue in selectedResult.materials while valuesFOk do
        if not materialValue.brdf_useRoughness or not lvmboSmeFloatEqual materialValue.refraction_glossiness 0.7 do valuesFOk = false
    lvmboSmeWrite (lvmboSmeResultText "Refract Gloss" resultF #refractionGlossiness)
    lvmboSmeAssert (lvmboSmeRowPassed resultF #refractionGlossiness 12 and valuesFOk) "Test F Refraction Glossiness only"
)
catch
(
    LVMBO_SME_TEST_FAILED += 1
    lvmboSmeWrite ("FATAL: " + (getCurrentException() as string))
)

if smeTestViewIndex > 0 do try (sme.DeleteView smeTestViewIndex false) catch()
try (sme.Close()) catch()
try (destroyDialog LunarVRayMtlBatchOverrideRollout) catch()

lvmboSmeWrite ("Passed: " + (LVMBO_SME_TEST_PASSED as string))
lvmboSmeWrite ("Failed: " + (LVMBO_SME_TEST_FAILED as string))

quitMAX #noPrompt
