/*
    Lunar VRayMtl Batch Override
    Autodesk 3ds Max 2026 / V-Ray / MAXScript

    Purpose:
    - Read only the nodes selected in the active Slate Material Editor view.
    - Modify only explicitly enabled parameters on unique existing VRayMtl references.
    - Never inspect scene object selection, material assignments, Material IDs, or Multi/Sub children.
*/

global LunarVRayMtlBatchOverrideRollout
global LunarVRayMtlBatchOverrideCore

if LunarVRayMtlBatchOverrideRollout != undefined do
(
    try (destroyDialog LunarVRayMtlBatchOverrideRollout) catch()
)

struct LVMBOSelectionResult
(
    ok = false,
    selectedNodeCount = 0,
    materials = #(),
    skippedNodeCount = 0,
    duplicateNodeCount = 0,
    errorText = ""
)

struct LVMBOOverrideSettings
(
    baseColorEnabled = false,
    baseColor = (color 180 180 180),
    reflectionColorEnabled = false,
    reflectionColor = (color 255 255 255),
    surfaceEnabled = false,
    surfaceMode = #glossiness,
    surfaceValue = 0.8,
    metalnessEnabled = false,
    metalnessValue = 0.0,
    refractionColorEnabled = false,
    refractionColor = (color 255 255 255),
    refractionGlossinessEnabled = false,
    refractionGlossinessValue = 1.0,
    mapMode = #keep
)

struct LVMBOApplyResult
(
    materialCount = 0,
    skippedMaterials = 0,
    rows = #(),
    mapMode = #keep
)

struct LVMBOCoreStruct
(
    /*
        Property specifications are semanticName, value property, map property, map-enable property.
        These exact names were obtained from getPropNames on the installed VRayMtl build.
        No prefix/suffix/fuzzy property search is performed.
    */
    propertySpecs = #(
        #(#baseColor, "Diffuse", "texmap_diffuse", "texmap_diffuse_on"),
        #(#reflectionColor, "Reflection", "texmap_reflection", "texmap_reflection_on"),
        #(#surface, "reflection_glossiness", "texmap_reflectionGlossiness", "texmap_reflectionGlossiness_on"),
        #(#metalness, "reflection_metalness", "texmap_metalness", "texmap_metalness_on"),
        #(#refractionColor, "Refraction", "texmap_refraction", "texmap_refraction_on"),
        #(#refractionGlossiness, "refraction_glossiness", "texmap_refractionGlossiness", "texmap_refractionGlossiness_on")
    ),

    fn newSettings =
    (
        LVMBOOverrideSettings()
    ),

    fn exceptionText =
    (
        local message = getCurrentException() as string
        message = substituteString message "\r" " "
        substituteString message "\n" " "
    ),

    fn vrayClassIsAvailable =
    (
        local available = false
        try
        (
            for classValue in material.classes while not available do
                if (classValue as string) == "VRayMtl" do available = true
        )
        catch (available = false)
        available
    ),

    fn isVRayMtl materialValue =
    (
        local supported = false
        if materialValue != undefined do
        (
            try
            (
                supported = (superClassOf materialValue == material) and ((classOf materialValue as string) == "VRayMtl")
            )
            catch (supported = false)
        )
        supported
    ),

    fn collectUniqueVRayMaterials referenceValues =
    (
        local result = LVMBOSelectionResult selectedNodeCount:referenceValues.count materials:#()

        for materialReference in referenceValues do
        (
            if isVRayMtl materialReference then
            (
                if (findItem result.materials materialReference) == 0 then
                    append result.materials materialReference
                else
                    result.duplicateNodeCount += 1
            )
            else
                result.skippedNodeCount += 1
        )

        result.ok = true
        result
    ),

    fn getSMESelection =
    (
        local result = LVMBOSelectionResult materials:#()

        try
        (
            if not sme.IsOpen() then
                result.errorText = "Slate Material Editor is not open."
            else
            (
                local activeIndex = sme.activeView
                if activeIndex < 1 or activeIndex > sme.GetNumViews() then
                    result.errorText = "The active Slate Material Editor view is unavailable."
                else
                (
                    local activeView = sme.GetView activeIndex
                    if activeView == undefined then
                        result.errorText = "The active Slate Material Editor view could not be read."
                    else
                    (
                        local selectedNodes = activeView.GetSelectedNodes()
                        local selectedReferences = #()
                        for selectedNode in selectedNodes do
                        (
                            local materialReference = undefined
                            try (materialReference = selectedNode.reference) catch (materialReference = undefined)
                            append selectedReferences materialReference
                        )
                        result = collectUniqueVRayMaterials selectedReferences
                    )
                )
            )
        )
        catch
        (
            result.ok = false
            result.errorText = "Unable to read the active Slate Material Editor selection: " + exceptionText()
        )

        result
    ),

    fn getSpec semanticName =
    (
        local result = undefined
        for specValue in propertySpecs while result == undefined do
            if specValue[1] == semanticName do result = specValue
        result
    ),

    fn resolveExactProperty propertyNames exactName =
    (
        local result = undefined
        local wantedName = toLower exactName
        for propertyName in propertyNames while result == undefined do
            if (toLower (propertyName as string)) == wantedName do result = propertyName
        result
    ),

    fn clampUnit value =
    (
        amax 0.0 (amin 1.0 value)
    ),

    fn valueInUnitRange value =
    (
        value >= 0.0 and value <= 1.0
    ),

    fn hasAnyOverride settings =
    (
        settings.baseColorEnabled or
        settings.reflectionColorEnabled or
        settings.surfaceEnabled or
        settings.metalnessEnabled or
        settings.refractionColorEnabled or
        settings.refractionGlossinessEnabled
    ),

    fn validateSettings settings =
    (
        local errorText = ""
        if settings.surfaceEnabled and not valueInUnitRange settings.surfaceValue do
            errorText = "Reflection Surface value must be between 0.0 and 1.0."
        if errorText == "" and settings.metalnessEnabled and not valueInUnitRange settings.metalnessValue do
            errorText = "Metalness value must be between 0.0 and 1.0."
        if errorText == "" and settings.refractionGlossinessEnabled and not valueInUnitRange settings.refractionGlossinessValue do
            errorText = "Refraction Glossiness value must be between 0.0 and 1.0."
        if errorText == "" and settings.surfaceEnabled and settings.surfaceMode != #glossiness and settings.surfaceMode != #roughness do
            errorText = "Reflection Surface mode is invalid."
        if errorText == "" and settings.mapMode != #keep and settings.mapMode != #disable and settings.mapMode != #remove do
            errorText = "Map Handling mode is invalid."
        errorText
    ),

    fn handleAffectedMap materialValue propertyNames specValue mapMode =
    (
        if mapMode == #keep then return #none

        local mapProperty = resolveExactProperty propertyNames specValue[3]
        if mapProperty == undefined then return #unsupported

        local mapReference = undefined
        try (mapReference = getProperty materialValue mapProperty) catch (return #error)
        if mapReference == undefined then return #none

        if mapMode == #disable then
        (
            local enableProperty = resolveExactProperty propertyNames specValue[4]
            if enableProperty == undefined then return #unsupported
            try
            (
                setProperty materialValue enableProperty false
                #disabled
            )
            catch (#error)
        )
        else if mapMode == #remove then
        (
            try
            (
                setProperty materialValue mapProperty undefined
                #removed
            )
            catch (#error)
        )
        else
            #unsupported
    ),

    fn setSimpleParameter materialValue propertyNames semanticName newValue mapMode =
    (
        local specValue = getSpec semanticName
        if specValue == undefined then return #(#unsupported, #none)

        local valueProperty = resolveExactProperty propertyNames specValue[2]
        if valueProperty == undefined then return #(#unsupported, #none)

        local valueSet = false
        try
        (
            setProperty materialValue valueProperty newValue
            valueSet = true
        )
        catch (valueSet = false)

        if not valueSet then return #(#error, #none)
        #(#success, handleAffectedMap materialValue propertyNames specValue mapMode)
    ),

    fn setReflectionSurface materialValue propertyNames surfaceMode surfaceValue mapMode =
    (
        local specValue = getSpec #surface
        local valueProperty = resolveExactProperty propertyNames specValue[2]
        local modeProperty = resolveExactProperty propertyNames "brdf_useRoughness"
        if valueProperty == undefined or modeProperty == undefined then return #(#unsupported, #none)

        local oldValue = undefined
        local oldMode = undefined
        local valueSet = false
        try
        (
            oldValue = getProperty materialValue valueProperty
            oldMode = getProperty materialValue modeProperty

            /* V-Ray exposes one value whose meaning is selected by this switch.
               Set the requested mode first, then write the user's value directly. */
            setProperty materialValue modeProperty (surfaceMode == #roughness)
            setProperty materialValue valueProperty (clampUnit surfaceValue)
            valueSet = true
        )
        catch
        (
            try (if oldMode != undefined do setProperty materialValue modeProperty oldMode) catch()
            try (if oldValue != undefined do setProperty materialValue valueProperty oldValue) catch()
            valueSet = false
        )

        if not valueSet then return #(#error, #none)
        #(#success, handleAffectedMap materialValue propertyNames specValue mapMode)
    ),

    fn setRefractionGlossiness materialValue propertyNames glossinessValue mapMode =
    (
        local specValue = getSpec #refractionGlossiness
        local valueProperty = resolveExactProperty propertyNames specValue[2]
        if valueProperty == undefined then return #(#unsupported, #none)

        local storedValue = clampUnit glossinessValue
        local modeProperty = resolveExactProperty propertyNames "brdf_useRoughness"

        /* In the installed/verified V-Ray API, brdf_useRoughness changes all
           glossiness values to roughness interpretation. Preserve that mode,
           but store its inverse so this UI's Refraction Glossiness remains a
           glossiness-semantic input. If the switch is absent, use the explicit
           refraction_glossiness property directly. */
        if modeProperty != undefined do
        (
            local roughnessMode = false
            try (roughnessMode = getProperty materialValue modeProperty) catch (roughnessMode = false)
            if roughnessMode do storedValue = 1.0 - storedValue
        )

        setSimpleParameter materialValue propertyNames #refractionGlossiness storedValue mapMode
    ),

    fn makeResultRows =
    (
        #(
            #(#baseColor, 0, 0, 0, 0, 0, 0, 0),
            #(#reflectionColor, 0, 0, 0, 0, 0, 0, 0),
            #(#surface, 0, 0, 0, 0, 0, 0, 0),
            #(#metalness, 0, 0, 0, 0, 0, 0, 0),
            #(#refractionColor, 0, 0, 0, 0, 0, 0, 0),
            #(#refractionGlossiness, 0, 0, 0, 0, 0, 0, 0)
        )
    ),

    fn findResultRow rows semanticName =
    (
        local result = undefined
        for rowValue in rows while result == undefined do
            if rowValue[1] == semanticName do result = rowValue
        result
    ),

    fn recordOutcome rows semanticName outcome =
    (
        local rowValue = findResultRow rows semanticName
        if rowValue == undefined then return false

        case outcome[1] of
        (
            #success: rowValue[2] += 1
            #unsupported: rowValue[3] += 1
            #error: rowValue[4] += 1
        )

        case outcome[2] of
        (
            #disabled: rowValue[5] += 1
            #removed: rowValue[6] += 1
            #unsupported: rowValue[7] += 1
            #error: rowValue[8] += 1
        )
        true
    ),

    fn applyOverrides materialValues settings =
    (
        local result = LVMBOApplyResult materialCount:materialValues.count rows:(makeResultRows()) mapMode:settings.mapMode

        for materialValue in materialValues do
        (
            if not isVRayMtl materialValue then
                result.skippedMaterials += 1
            else
            (
                local propertyNames = #()
                local propertiesReadable = true
                try (propertyNames = getPropNames materialValue) catch (propertiesReadable = false)

                if not propertiesReadable then
                    result.skippedMaterials += 1
                else
                (
                    if settings.baseColorEnabled do
                        recordOutcome result.rows #baseColor (setSimpleParameter materialValue propertyNames #baseColor settings.baseColor settings.mapMode)

                    if settings.reflectionColorEnabled do
                        recordOutcome result.rows #reflectionColor (setSimpleParameter materialValue propertyNames #reflectionColor settings.reflectionColor settings.mapMode)

                    if settings.surfaceEnabled do
                        recordOutcome result.rows #surface (setReflectionSurface materialValue propertyNames settings.surfaceMode settings.surfaceValue settings.mapMode)

                    if settings.metalnessEnabled do
                        recordOutcome result.rows #metalness (setSimpleParameter materialValue propertyNames #metalness (clampUnit settings.metalnessValue) settings.mapMode)

                    if settings.refractionColorEnabled do
                        recordOutcome result.rows #refractionColor (setSimpleParameter materialValue propertyNames #refractionColor settings.refractionColor settings.mapMode)

                    if settings.refractionGlossinessEnabled do
                        recordOutcome result.rows #refractionGlossiness (setRefractionGlossiness materialValue propertyNames settings.refractionGlossinessValue settings.mapMode)
                )
            )
        )

        result
    ),

    fn inspectMaterial materialValue =
    (
        if materialValue == undefined then
            format "[LVMBO] No material to inspect.\n"
        else
        (
            format "\n[LVMBO] VRayMtl diagnostic\n"
            format "Name: %\n" materialValue.name
            format "Class: %\n" (classOf materialValue)
            format "SuperClass: %\n" (superClassOf materialValue)
            format "Properties:\n"
            try
            (
                for propertyName in (getPropNames materialValue) do
                (
                    local valueText = "<unreadable>"
                    try (valueText = getProperty materialValue propertyName as string) catch()
                    format "  % = %\n" propertyName valueText
                )
            )
            catch (format "  ERROR: %\n" (exceptionText()))
            format "[LVMBO] End diagnostic\n\n"
        )
        true
    )
)

LunarVRayMtlBatchOverrideCore = LVMBOCoreStruct()

rollout LunarVRayMtlBatchOverrideRollout "VRayMtl Batch Override" width:520 height:790
(
    groupBox gbSelection "SLATE MATERIAL EDITOR SELECTION" pos:[8,8] width:504 height:112
    label lblSelectedNodes "Selected Nodes : 0" pos:[20,30] width:160 height:18
    label lblVRayCount "Unique VRayMtl : 0" pos:[180,30] width:160 height:18
    label lblSkipped "Skipped : 0" pos:[348,30] width:140 height:18
    button btnLVMBORefreshSelection "Refresh Selection" pos:[20,62] width:226 height:32
    button btnLVMBOInspectMaterial "Inspect First VRayMtl" pos:[266,62] width:226 height:32

    groupBox gbColor "COLOR" pos:[8,128] width:504 height:116
    checkbox chkBaseColor "Base / Diffuse Color" pos:[20,152] width:210 height:20 checked:false
    colorPicker cpBaseColor "RGB:" pos:[270,148] width:222 height:24 color:(color 180 180 180) enabled:false
    checkbox chkReflectionColor "Reflection Color" pos:[20,196] width:210 height:20 checked:false
    colorPicker cpReflectionColor "RGB:" pos:[270,192] width:222 height:24 color:(color 255 255 255) enabled:false

    groupBox gbSurface "SURFACE" pos:[8,252] width:504 height:142
    checkbox chkSurface "Reflection Surface" pos:[20,276] width:190 height:20 checked:false
    radioButtons rbSurfaceMode "Mode" labels:#("Glossiness", "Roughness") columns:2 default:1 pos:[220,268] width:272 enabled:false
    spinner spnSurface "Value:" pos:[300,330] width:192 height:20 range:[0.0,1.0,0.8] type:#float scale:0.01 fieldwidth:70 enabled:false
    checkbox chkMetalness "Metalness" pos:[20,354] width:190 height:20 checked:false
    spinner spnMetalness "Value:" pos:[300,352] width:192 height:20 range:[0.0,1.0,0.0] type:#float scale:0.01 fieldwidth:70 enabled:false

    groupBox gbRefraction "REFRACTION" pos:[8,402] width:504 height:116
    checkbox chkRefractionColor "Refraction Color" pos:[20,426] width:210 height:20 checked:false
    colorPicker cpRefractionColor "RGB:" pos:[270,422] width:222 height:24 color:(color 255 255 255) enabled:false
    checkbox chkRefractionGlossiness "Refraction Glossiness" pos:[20,470] width:210 height:20 checked:false
    spinner spnRefractionGlossiness "Value:" pos:[300,468] width:192 height:20 range:[0.0,1.0,1.0] type:#float scale:0.01 fieldwidth:70 enabled:false

    groupBox gbMaps "MAP HANDLING" pos:[8,526] width:504 height:74
    radioButtons rbMapMode "" labels:#("Keep Existing Maps", "Disable Affected Maps", "Remove Affected Maps") columns:1 default:1 pos:[20,546] width:470

    button btnLVMBOApplyOverride "Apply to Selected VRayMtl" pos:[8,610] width:504 height:42
    groupBox gbStatus "STATUS" pos:[8,660] width:504 height:122
    editText txtStatus "" pos:[18,680] width:484 height:92 readOnly:true multiLine:true text:"Ready."

    local isApplying = false

    fn setStatus message =
    (
        txtStatus.text = message
    )

    fn updateControlStates =
    (
        cpBaseColor.enabled = chkBaseColor.checked
        cpReflectionColor.enabled = chkReflectionColor.checked
        rbSurfaceMode.enabled = chkSurface.checked
        spnSurface.enabled = chkSurface.checked
        spnMetalness.enabled = chkMetalness.checked
        cpRefractionColor.enabled = chkRefractionColor.checked
        spnRefractionGlossiness.enabled = chkRefractionGlossiness.checked
    )

    fn updateSelectionLabels selectionResult =
    (
        lblSelectedNodes.text = "Selected Nodes : " + (selectionResult.selectedNodeCount as string)
        lblVRayCount.text = "Unique VRayMtl : " + (selectionResult.materials.count as string)
        lblSkipped.text = "Skipped : " + (selectionResult.skippedNodeCount as string)
    )

    fn refreshSelection showStatus:true =
    (
        local selectionResult = LunarVRayMtlBatchOverrideCore.getSMESelection()
        updateSelectionLabels selectionResult
        if showStatus do
        (
            if selectionResult.ok then
            (
                local duplicateText = ""
                if selectionResult.duplicateNodeCount > 0 do
                    duplicateText = " | Duplicate nodes: " + (selectionResult.duplicateNodeCount as string)
                setStatus ("Selection refreshed. VRayMtl: " + (selectionResult.materials.count as string) + duplicateText)
            )
            else
                setStatus ("ERROR: " + selectionResult.errorText)
        )
        selectionResult
    )

    on chkBaseColor changed state do updateControlStates()
    on chkReflectionColor changed state do updateControlStates()
    on chkSurface changed state do updateControlStates()
    on chkMetalness changed state do updateControlStates()
    on chkRefractionColor changed state do updateControlStates()
    on chkRefractionGlossiness changed state do updateControlStates()

    on btnLVMBORefreshSelection pressed do
    (
        refreshSelection showStatus:true
    )

    on btnLVMBOInspectMaterial pressed do
    (
        local selectionResult = refreshSelection showStatus:false
        if not selectionResult.ok then
            setStatus ("ERROR: " + selectionResult.errorText)
        else if selectionResult.materials.count == 0 then
            setStatus "No VRayMtl selected."
        else
        (
            LunarVRayMtlBatchOverrideCore.inspectMaterial selectionResult.materials[1]
            setStatus "Diagnostic written to the MAXScript Listener for the first selected VRayMtl."
        )
    )

    on btnLVMBOApplyOverride pressed do
    (
        if not isApplying do
        (
            isApplying = true
            btnLVMBOApplyOverride.enabled = false

            try
            (
                local selectionResult = refreshSelection showStatus:false
                local selectedMapMode = case rbMapMode.state of (2:#disable; 3:#remove; default:#keep)
                local settings = LunarVRayMtlBatchOverrideCore.newSettings()
                settings.baseColorEnabled = chkBaseColor.checked
                settings.baseColor = cpBaseColor.color
                settings.reflectionColorEnabled = chkReflectionColor.checked
                settings.reflectionColor = cpReflectionColor.color
                settings.surfaceEnabled = chkSurface.checked
                settings.surfaceMode = if rbSurfaceMode.state == 2 then #roughness else #glossiness
                settings.surfaceValue = spnSurface.value
                settings.metalnessEnabled = chkMetalness.checked
                settings.metalnessValue = spnMetalness.value
                settings.refractionColorEnabled = chkRefractionColor.checked
                settings.refractionColor = cpRefractionColor.color
                settings.refractionGlossinessEnabled = chkRefractionGlossiness.checked
                settings.refractionGlossinessValue = spnRefractionGlossiness.value
                settings.mapMode = selectedMapMode
                local validationError = LunarVRayMtlBatchOverrideCore.validateSettings settings
                local canApply = true

                if not selectionResult.ok then
                (
                    setStatus ("ERROR: " + selectionResult.errorText)
                    canApply = false
                )
                else if not LunarVRayMtlBatchOverrideCore.vrayClassIsAvailable() then
                (
                    setStatus "ERROR: VRayMtl class is not available."
                    canApply = false
                )
                else if selectionResult.materials.count == 0 then
                (
                    setStatus "No VRayMtl selected."
                    canApply = false
                )
                else if not LunarVRayMtlBatchOverrideCore.hasAnyOverride settings then
                (
                    setStatus "No override parameter enabled."
                    canApply = false
                )
                else if validationError != "" then
                (
                    setStatus ("ERROR: " + validationError)
                    canApply = false
                )

                if canApply do
                (
                    local applyResult = undefined
                    undo "VRayMtl Batch Override" on
                    (
                        applyResult = LunarVRayMtlBatchOverrideCore.applyOverrides selectionResult.materials settings
                    )
                    local summaryText = "Applied to " + (applyResult.materialCount as string) + " unique VRayMtl.\r\n"
                    local summarySpecs = #(
                        #(#baseColor, "Base Color", settings.baseColorEnabled),
                        #(#reflectionColor, "Reflection Color", settings.reflectionColorEnabled),
                        #(#surface, "Surface", settings.surfaceEnabled),
                        #(#metalness, "Metalness", settings.metalnessEnabled),
                        #(#refractionColor, "Refraction Color", settings.refractionColorEnabled),
                        #(#refractionGlossiness, "Refract Gloss", settings.refractionGlossinessEnabled)
                    )

                    for summarySpec in summarySpecs do
                    (
                        local rowText = summarySpec[2] + " : OFF"
                        if summarySpec[3] do
                        (
                            local resultRow = LunarVRayMtlBatchOverrideCore.findResultRow applyResult.rows summarySpec[1]
                            if resultRow == undefined then
                                rowText = summarySpec[2] + " : ERROR"
                            else
                            (
                                rowText = summarySpec[2] + " : Success " + (resultRow[2] as string)
                                if resultRow[3] > 0 do rowText += " | Unsupported " + (resultRow[3] as string)
                                if resultRow[4] > 0 do rowText += " | Errors " + (resultRow[4] as string)
                            )
                        )
                        summaryText += rowText + "\r\n"
                    )

                    local mapText = case applyResult.mapMode of
                    (
                        #disable: "Disable Affected Maps"
                        #remove: "Remove Affected Maps"
                        default: "Keep Existing Maps"
                    )
                    summaryText += "Maps: " + mapText

                    local mapDisabled = 0
                    local mapRemoved = 0
                    local mapUnsupported = 0
                    local mapErrors = 0
                    for resultRow in applyResult.rows do
                    (
                        mapDisabled += resultRow[5]
                        mapRemoved += resultRow[6]
                        mapUnsupported += resultRow[7]
                        mapErrors += resultRow[8]
                    )
                    if mapDisabled > 0 do summaryText += " | Disabled " + (mapDisabled as string)
                    if mapRemoved > 0 do summaryText += " | Removed " + (mapRemoved as string)
                    if mapUnsupported > 0 do summaryText += " | Unsupported " + (mapUnsupported as string) + " (kept)"
                    if mapErrors > 0 do summaryText += " | Errors " + (mapErrors as string) + " (kept)"
                    if applyResult.skippedMaterials > 0 do summaryText += "\r\nSkipped Materials: " + (applyResult.skippedMaterials as string)
                    setStatus summaryText
                    try (redrawViews()) catch()
                )
            )
            catch
            (
                setStatus ("ERROR: Apply failed safely. " + LunarVRayMtlBatchOverrideCore.exceptionText())
            )

            isApplying = false
            btnLVMBOApplyOverride.enabled = true
        )
    )

    on LunarVRayMtlBatchOverrideRollout open do
    (
        updateControlStates()
        if LunarVRayMtlBatchOverrideCore.vrayClassIsAvailable() then
            refreshSelection showStatus:true
        else
            setStatus "ERROR: VRayMtl class is not available."
    )
)

createDialog LunarVRayMtlBatchOverrideRollout style:#(#style_titlebar, #style_sysmenu, #style_toolwindow)
