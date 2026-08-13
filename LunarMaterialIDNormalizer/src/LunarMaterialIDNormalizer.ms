/*
    Lunar Material ID Normalizer
    Autodesk 3ds Max 2026 / MAXScript

    Purpose:
    - Normalize Editable Poly face Material IDs to one Master Multi/Sub-Object material.
    - Match sub-materials by exact, case-sensitive material name.
    - Preserve existing Master IDs and append missing material references after max ID.
    - Analyze without scene changes; Apply in one undo block.
*/

global LunarMaterialIDNormalizerRollout

if LunarMaterialIDNormalizerRollout != undefined do
(
    try (destroyDialog LunarMaterialIDNormalizerRollout) catch()
)

rollout LunarMaterialIDNormalizerRollout "Lunar Material ID Normalizer" width:760 height:936
(
    groupBox gbPreprocess "PREPROCESS" pos:[8,8] width:744 height:118
    checkbox chkConvertUSD "Convert USD Preview Surface to VRayMtl" pos:[20,30] width:330 height:20 checked:true
    checkbox chkOverrideGlossiness "Override Glossiness" pos:[20,62] width:180 height:20 checked:true
    spinner spnGlossiness "Glossiness:" pos:[210,60] width:150 height:20 range:[0.0,1.0,0.8] type:#float scale:0.01 fieldwidth:60
    checkbox chkOverrideReflection "Override Reflection" pos:[390,62] width:170 height:20 checked:true
    colorPicker cpReflection "Reflection:" pos:[570,58] width:166 height:24 color:(color 255 255 255)
    label lblPreprocessHint "Constant diffuse only. Texture networks, roughness, metallic, opacity, emission, normal and displacement are ignored." pos:[20,94] width:710 height:18

    groupBox gbMaster "MASTER" pos:[8,134] width:744 height:68
    label lblMaster "Master Object: Not set" pos:[20,156] width:450 height:18
    button btnSetMaster "Set Master" pos:[520,152] width:104 height:28
    button btnClearMaster "Clear Master" pos:[632,152] width:104 height:28

    groupBox gbTargets "TARGETS" pos:[8,208] width:278 height:300
    multiListBox lbTargets "" pos:[18,230] width:258 height:12
    button btnAddTargets "Add Selected Targets" pos:[18,454] width:124 height:28
    button btnRemoveTargets "Remove Selected" pos:[148,454] width:128 height:28
    button btnClearTargets "Clear Targets" pos:[18,488] width:258 height:24

    groupBox gbCanonical "CANONICAL MATERIAL TABLE" pos:[294,208] width:458 height:300
    dotNetControl lvCanonical "System.Windows.Forms.ListView" pos:[304,230] width:438 height:268

    groupBox gbPreview "TARGET REMAP PREVIEW" pos:[8,516] width:744 height:294
    label lblPreviewTarget "Target: Select one target from the list" pos:[20,538] width:710 height:18
    dotNetControl lvRemap "System.Windows.Forms.ListView" pos:[18,560] width:724 height:240

    button btnAnalyze "Analyze" pos:[8,820] width:366 height:36
    button btnApply "Normalize / Apply" pos:[386,820] width:366 height:36

    label lblSummary "MASTER: None | Targets: 0 | Materials: 0 | Matched: 0 | Pending Append: 0" pos:[10,866] width:740 height:18
    label lblConversionSummary "USD: 0 | Existing VRay: 0 | Unsupported: 0 | Texture Ignored: 0 | Conflicts: 0" pos:[10,888] width:740 height:18
    label lblStatus "Status: Ready" pos:[10,910] width:740 height:18

    local DEBUG_MODE = false
    local masterNode = undefined
    local targetNodes = #()
    local canonicalRows = #()
    local targetAnalyses = #()
    local analysisReady = false
    local analysisHasConflict = false
    local matchedCount = 0
    local pendingCount = 0
    local scopedMaterials = #()
    local conversionPlan = #()
    local conversionCache = #()
    local diffuseConflictNames = #()
    local usdMaterialCount = 0
    local existingVRayCount = 0
    local unsupportedMaterialCount = 0
    local textureIgnoredCount = 0
    local preprocessConflictCount = 0
    local preprocessErrorText = ""
    local lastApplyConvertedCount = 0
    local lastApplyAppendedCount = 0

    /*
        Canonical row:
        #(materialID, materialName, materialReference, sourceText, state, sourceNode, slotIndex)

        Target analysis:
        #(node, overallStatus, detailText, remapRows, isApplicable)

        Remap row:
        #(oldID, materialName, newID, state, materialReference)
    */

    fn lmnLog level message =
    (
        if level != "DEBUG" or DEBUG_MODE do
            format "[LMN][%] %\n" level message
    )

    fn exceptionText =
    (
        local message = getCurrentException() as string
        message = substituteString message "\r" " "
        substituteString message "\n" " "
    )

    fn setStatus message =
    (
        lblStatus.text = "Status: " + message
    )

    fn isValidStoredNode nodeValue =
    (
        nodeValue != undefined and isValidNode nodeValue
    )

    fn isMultiMaterial materialValue =
    (
        materialValue != undefined and classOf materialValue == Multimaterial
    )

    fn isEditablePolyNode nodeValue =
    (
        local supported = false
        if isValidStoredNode nodeValue do
        (
            try (supported = classOf nodeValue.baseObject == Editable_Poly) catch (supported = false)
        )
        supported
    )

    fn exactNameEquals leftName rightName =
    (
        leftName != undefined and rightName != undefined and (leftName as string) == (rightName as string)
    )

    fn safeMaterialName materialValue =
    (
        if materialValue == undefined then "" else materialValue.name as string
    )

    /* USD Preview Surface -> VRayMtl preprocess layer.
       Property names below were verified in the installed 3ds Max 2026 / USD / V-Ray build. */

    fn materialClassText materialValue =
    (
        if materialValue == undefined then "Undefined" else classOf materialValue as string
    )

    fn isUSDPreviewMaterial materialValue =
    (
        materialValue != undefined and materialClassText materialValue == "MaxUsdPreviewSurface"
    )

    fn isVRayMaterial materialValue =
    (
        materialValue != undefined and materialClassText materialValue == "VRayMtl"
    )

    fn materialHasTextureDrivenDiffuse materialValue =
    (
        isUSDPreviewMaterial materialValue and
            isProperty materialValue #diffuseColor_map and
            getProperty materialValue #diffuseColor_map != undefined
    )

    fn readComparableDiffuse materialValue =
    (
        if isUSDPreviewMaterial materialValue and isProperty materialValue #diffuseColor then
            #(true, getProperty materialValue #diffuseColor)
        else if isVRayMaterial materialValue and isProperty materialValue #Diffuse then
            #(true, getProperty materialValue #Diffuse)
        else if materialValue != undefined and isProperty materialValue #diffuse then
            #(true, getProperty materialValue #diffuse)
        else
            #(false, undefined)
    )

    fn diffuseColorsEqual leftColor rightColor =
    (
        leftColor != undefined and rightColor != undefined and
        (abs (leftColor.r - rightColor.r)) <= 0.01 and
        (abs (leftColor.g - rightColor.g)) <= 0.01 and
        (abs (leftColor.b - rightColor.b)) <= 0.01
    )

    fn appendUniqueMaterial materialArray materialValue =
    (
        if materialValue != undefined and (findItem materialArray materialValue) == 0 do
            append materialArray materialValue
        materialArray
    )

    fn collectFromTopMaterial topMaterial =
    (
        if topMaterial != undefined do
        (
            if isMultiMaterial topMaterial then
            (
                for subMaterial in topMaterial.materialList where subMaterial != undefined do
                    appendUniqueMaterial scopedMaterials subMaterial
            )
            else
                appendUniqueMaterial scopedMaterials topMaterial
        )
    )

    fn collectScopedMaterials =
    (
        scopedMaterials = #()
        if isValidStoredNode masterNode do collectFromTopMaterial masterNode.material
        for nodeValue in targetNodes where isValidStoredNode nodeValue do
            collectFromTopMaterial nodeValue.material
        scopedMaterials
    )

    fn vrayClassIsAvailable =
    (
        local available = false
        for classValue in material.classes while not available do
        (
            if (classValue as string) == "VRayMtl" do available = true
        )
        available
    )

    fn isDiffuseConflictName materialName =
    (
        local found = false
        for conflictName in diffuseConflictNames while not found do
            if exactNameEquals conflictName materialName do found = true
        found
    )

    fn analyzePreprocess =
    (
        conversionPlan = #()
        diffuseConflictNames = #()
        usdMaterialCount = 0
        existingVRayCount = 0
        unsupportedMaterialCount = 0
        textureIgnoredCount = 0
        preprocessConflictCount = 0
        preprocessErrorText = ""
        collectScopedMaterials()

        for materialValue in scopedMaterials do
        (
            if isUSDPreviewMaterial materialValue then
            (
                usdMaterialCount += 1
                if chkConvertUSD.checked do append conversionPlan materialValue
                if materialHasTextureDrivenDiffuse materialValue do textureIgnoredCount += 1
            )
            else if isVRayMaterial materialValue then
                existingVRayCount += 1
            else
                unsupportedMaterialCount += 1
        )

        if scopedMaterials.count > 1 do
        (
            for leftIndex = 1 to (scopedMaterials.count - 1) do
            (
                local leftMaterial = scopedMaterials[leftIndex]
                local leftName = safeMaterialName leftMaterial
                local leftDiffuse = readComparableDiffuse leftMaterial

                for rightIndex = (leftIndex + 1) to scopedMaterials.count do
                (
                    local rightMaterial = scopedMaterials[rightIndex]
                    if exactNameEquals leftName (safeMaterialName rightMaterial) do
                    (
                        local rightDiffuse = readComparableDiffuse rightMaterial
                        if leftDiffuse[1] and rightDiffuse[1] and not diffuseColorsEqual leftDiffuse[2] rightDiffuse[2] do
                        (
                            if not isDiffuseConflictName leftName do append diffuseConflictNames leftName
                        )
                    )
                )
            )
        )

        preprocessConflictCount = diffuseConflictNames.count

        if chkConvertUSD.checked and usdMaterialCount > 0 and not vrayClassIsAvailable() then
        (
            preprocessErrorText = "ERROR: VRayMtl class is not available. USD conversion cancelled. Scene was not changed."
            setStatus preprocessErrorText
            false
        )
        else if preprocessConflictCount > 0 then
        (
            setStatus ("CONFLICT: " + (preprocessConflictCount as string) + " material name(s) have different diffuse colors.")
            false
        )
        else true
    )

    fn preprocessMaterialTypeText materialValue =
    (
        if isUSDPreviewMaterial materialValue then
        (
            if chkConvertUSD.checked then "USD -> VRAY" else "USD / KEEP"
        )
        else if isVRayMaterial materialValue then
            "VRAY"
        else
            "UNSUPPORTED"
    )

    fn canonicalStatusText rowValue =
    (
        local result = rowValue[4]
        local materialValue = rowValue[3]
        if isDiffuseConflictName rowValue[2] then
            result = "CONFLICT : SAME NAME / DIFFERENT DIFFUSE"
        else if materialHasTextureDrivenDiffuse materialValue then
            result += " / TEXTURE IGNORED"
        else if isVRayMaterial materialValue then
            result += " / KEEP"
        else if materialValue != undefined and not isUSDPreviewMaterial materialValue then
            result += " / KEEP"
        result
    )

    fn remapStatusText remapRow =
    (
        local materialValue = remapRow[5]
        local prefix = preprocessMaterialTypeText materialValue
        local result = prefix + " / " + remapRow[4]
        if materialHasTextureDrivenDiffuse materialValue do result += " / TEXTURE IGNORED"
        if isDiffuseConflictName remapRow[2] do result = "CONFLICT : SAME NAME / DIFFERENT DIFFUSE"
        result
    )

    fn validatePreprocessOptions =
    (
        if spnGlossiness.value < 0.0 or spnGlossiness.value > 1.0 then
            #(false, "Glossiness must be between 0.0 and 1.0.")
        else if chkConvertUSD.checked and usdMaterialCount > 0 and not vrayClassIsAvailable() then
            #(false, "ERROR: VRayMtl class is not available. USD conversion cancelled.")
        else
        (
            local probeMaterial = undefined
            if chkConvertUSD.checked and usdMaterialCount > 0 do
            (
                try (probeMaterial = execute "VRayMtl()") catch()
            )

            if chkConvertUSD.checked and usdMaterialCount > 0 and probeMaterial == undefined then
                #(false, "ERROR: VRayMtl could not be created. USD conversion cancelled.")
            else if probeMaterial != undefined and not isProperty probeMaterial #Diffuse then
                #(false, "ERROR: VRayMtl.Diffuse is unavailable in this V-Ray build.")
            else if probeMaterial != undefined and chkOverrideGlossiness.checked and
                (not isProperty probeMaterial #reflection_glossiness or not isProperty probeMaterial #brdf_useRoughness) then
                #(false, "ERROR: Safe Glossiness override properties are unavailable in this V-Ray build.")
            else if probeMaterial != undefined and chkOverrideReflection.checked and not isProperty probeMaterial #Reflection then
                #(false, "ERROR: VRayMtl.Reflection is unavailable in this V-Ray build.")
            else
                #(true, "")
        )
    )

    fn findConvertedMaterial originalMaterial =
    (
        local converted = undefined
        for cacheRow in conversionCache while converted == undefined do
            if cacheRow[1] == originalMaterial do converted = cacheRow[2]
        converted
    )

    fn createConvertedVRay originalMaterial =
    (
        local convertedMaterial = execute "VRayMtl()"
        convertedMaterial.name = originalMaterial.name
        setProperty convertedMaterial #Diffuse (copy (getProperty originalMaterial #diffuseColor))

        if chkOverrideGlossiness.checked do
        (
            setProperty convertedMaterial #brdf_useRoughness false
            setProperty convertedMaterial #reflection_glossiness spnGlossiness.value
        )

        if chkOverrideReflection.checked do
            setProperty convertedMaterial #Reflection (copy cpReflection.color)

        convertedMaterial
    )

    fn buildConversionCache =
    (
        conversionCache = #()
        for originalMaterial in conversionPlan do
        (
            local convertedMaterial = createConvertedVRay originalMaterial
            append conversionCache #(originalMaterial, convertedMaterial)
        )
        conversionCache.count
    )

    fn replaceUSDReferencesInTopMaterial nodeValue =
    (
        local replacedCount = 0
        local topMaterial = nodeValue.material
        if topMaterial != undefined do
        (
            if isMultiMaterial topMaterial then
            (
                for slotIndex = 1 to topMaterial.materialList.count do
                (
                    local originalMaterial = topMaterial.materialList[slotIndex]
                    local convertedMaterial = findConvertedMaterial originalMaterial
                    if convertedMaterial != undefined do
                    (
                        topMaterial.materialList[slotIndex] = convertedMaterial
                        replacedCount += 1
                    )
                )
            )
            else
            (
                local convertedMaterial = findConvertedMaterial topMaterial
                if convertedMaterial != undefined do
                (
                    nodeValue.material = convertedMaterial
                    replacedCount += 1
                )
            )
        )
        replacedCount
    )

    fn applyUSDConversions =
    (
        if not chkConvertUSD.checked or conversionPlan.count == 0 then
            0
        else
        (
            local convertedCount = buildConversionCache()
            replaceUSDReferencesInTopMaterial masterNode
            for nodeValue in targetNodes where isValidStoredNode nodeValue do
                replaceUSDReferencesInTopMaterial nodeValue
            convertedCount
        )
    )

    fn updatePreprocessControlStates =
    (
        chkOverrideGlossiness.enabled = chkConvertUSD.checked
        chkOverrideReflection.enabled = chkConvertUSD.checked
        spnGlossiness.enabled = chkConvertUSD.checked and chkOverrideGlossiness.checked
        cpReflection.enabled = chkConvertUSD.checked and chkOverrideReflection.checked
    )

    fn setPreprocessOptions convertEnabled glossinessEnabled glossinessValue reflectionEnabled reflectionColor =
    (
        local clampedGlossiness = glossinessValue
        if clampedGlossiness < 0.0 then clampedGlossiness = 0.0
        if clampedGlossiness > 1.0 then clampedGlossiness = 1.0

        chkConvertUSD.checked = convertEnabled
        chkOverrideGlossiness.checked = glossinessEnabled
        spnGlossiness.value = clampedGlossiness
        chkOverrideReflection.checked = reflectionEnabled
        cpReflection.color = reflectionColor
        updatePreprocessControlStates()
        canonicalRows = #()
        targetAnalyses = #()
        analysisReady = false
        btnApply.enabled = false
        true
    )

    fn getLastApplyStats =
    (
        #(lastApplyConvertedCount, lastApplyAppendedCount)
    )

    fn cleanStoredNodes =
    (
        if masterNode != undefined and not isValidStoredNode masterNode do
        (
            lmnLog "WARN" "The stored Master was deleted or became invalid."
            masterNode = undefined
            analysisReady = false
        )

        local cleanTargets = #()
        for nodeValue in targetNodes do
        (
            if isValidStoredNode nodeValue and nodeValue != masterNode and (findItem cleanTargets nodeValue) == 0 then
                append cleanTargets nodeValue
            else if nodeValue != undefined and not isValidStoredNode nodeValue do
                lmnLog "WARN" "A deleted or invalid Target was removed."
        )
        targetNodes = cleanTargets
    )

    fn clearListView viewControl =
    (
        viewControl.beginUpdate()
        viewControl.items.clear()
        viewControl.endUpdate()
    )

    fn addListViewRow viewControl values =
    (
        local item = dotNetObject "System.Windows.Forms.ListViewItem" (values[1] as string)
        for indexValue = 2 to values.count do item.subItems.add (values[indexValue] as string)
        viewControl.items.add item
        item
    )

    fn configureListView viewControl columnSpecs =
    (
        local viewEnum = dotNetClass "System.Windows.Forms.View"
        viewControl.view = viewEnum.details
        viewControl.fullRowSelect = true
        viewControl.gridLines = true
        viewControl.hideSelection = false
        viewControl.multiSelect = false
        viewControl.headerStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").nonclickable
        viewControl.columns.clear()
        for columnSpec in columnSpecs do viewControl.columns.add columnSpec[1] columnSpec[2]
    )

    fn findCanonicalRowByName materialName rows:canonicalRows =
    (
        local foundIndex = 0
        for indexValue = 1 to rows.count while foundIndex == 0 do
        (
            if exactNameEquals rows[indexValue][2] materialName do foundIndex = indexValue
        )
        foundIndex
    )

    fn findCanonicalRowByID materialID rows:canonicalRows =
    (
        local foundIndex = 0
        for indexValue = 1 to rows.count while foundIndex == 0 do
        (
            if rows[indexValue][1] == materialID do foundIndex = indexValue
        )
        foundIndex
    )

    fn sortCanonicalRowsByID rows =
    (
        local remainingRows = for rowValue in rows collect rowValue
        local sortedRows = #()
        while remainingRows.count > 0 do
        (
            local bestIndex = 1
            for indexValue = 2 to remainingRows.count where remainingRows[indexValue][1] < remainingRows[bestIndex][1] do
                bestIndex = indexValue
            append sortedRows remainingRows[bestIndex]
            deleteItem remainingRows bestIndex
        )
        sortedRows
    )

    fn maxCanonicalID rows =
    (
        local maximumID = 0
        for rowValue in rows where rowValue[1] > maximumID do maximumID = rowValue[1]
        maximumID
    )

    fn findTargetAnalysis nodeValue =
    (
        local foundIndex = 0
        for indexValue = 1 to targetAnalyses.count while foundIndex == 0 do
        (
            if targetAnalyses[indexValue][1] == nodeValue do foundIndex = indexValue
        )
        if foundIndex == 0 then undefined else targetAnalyses[foundIndex]
    )

    fn getUniqueFaceIDs nodeValue =
    (
        local faceIDs = #()
        local faceCount = polyop.getNumFaces nodeValue
        for faceIndex = 1 to faceCount do
        (
            local faceID = polyop.getFaceMatID nodeValue faceIndex
            if (findItem faceIDs faceID) == 0 do append faceIDs faceID
        )
        sort faceIDs
        faceIDs
    )

    fn getDefinedMultiRows materialValue =
    (
        local rows = #()
        local materialCount = materialValue.materialList.count
        local idCount = materialValue.materialIDList.count
        local safeCount = amin materialCount idCount

        for slotIndex = 1 to safeCount do
        (
            local subMaterial = materialValue.materialList[slotIndex]
            if subMaterial != undefined do
            (
                append rows #(
                    materialValue.materialIDList[slotIndex],
                    safeMaterialName subMaterial,
                    subMaterial,
                    slotIndex
                )
            )
        )
        rows
    )

    fn findMultiRowByID materialRows materialID =
    (
        local foundRows = #()
        for rowValue in materialRows where rowValue[1] == materialID do append foundRows rowValue
        foundRows
    )

    fn buildMasterCanonical =
    (
        canonicalRows = #()
        analysisHasConflict = false

        if not isValidStoredNode masterNode then
        (
            setStatus "Set a valid Master object."
            false
        )
        else if masterNode.material == undefined then
        (
            setStatus ("MASTER " + masterNode.name + " has no material.")
            false
        )
        else if not isMultiMaterial masterNode.material then
        (
            setStatus ("MASTER " + masterNode.name + " must use a Multi/Sub-Object material.")
            false
        )
        else
        (
            local masterMaterial = masterNode.material
            local materialCount = masterMaterial.materialList.count
            local idCount = masterMaterial.materialIDList.count

            if materialCount != idCount then
            (
                setStatus "MASTER materialList/materialIDList lengths do not match."
                analysisHasConflict = true
                false
            )
            else
            (
                for slotIndex = 1 to materialCount do
                (
                    local subMaterial = masterMaterial.materialList[slotIndex]
                    if subMaterial != undefined do
                    (
                        local materialID = masterMaterial.materialIDList[slotIndex]
                        local materialName = safeMaterialName subMaterial
                        local stateText = "MASTER"

                        if materialName.count == 0 then
                        (
                            stateText = "CONFLICT : EMPTY NAME"
                            analysisHasConflict = true
                        )
                        else if findCanonicalRowByName materialName rows:canonicalRows > 0 then
                        (
                            stateText = "DUPLICATE NAME"
                            analysisHasConflict = true
                            local previousIndex = findCanonicalRowByName materialName rows:canonicalRows
                            canonicalRows[previousIndex][4] = "DUPLICATE NAME"
                            canonicalRows[previousIndex][5] = #conflict
                        )

                        if findCanonicalRowByID materialID rows:canonicalRows > 0 then
                        (
                            stateText = "CONFLICT : DUPLICATE ID"
                            analysisHasConflict = true
                            local previousIDIndex = findCanonicalRowByID materialID rows:canonicalRows
                            canonicalRows[previousIDIndex][4] = "CONFLICT : DUPLICATE ID"
                            canonicalRows[previousIDIndex][5] = #conflict
                        )

                        append canonicalRows #(materialID, materialName, subMaterial, stateText,
                            (if stateText == "MASTER" then #master else #conflict), masterNode, slotIndex)
                    )
                )

                canonicalRows = sortCanonicalRowsByID canonicalRows
                if canonicalRows.count == 0 then
                (
                    setStatus "MASTER Multi/Sub-Object material has no defined sub-materials."
                    analysisHasConflict = true
                    false
                )
                else true
            )
        )
    )

    fn ensureVirtualCanonical materialName materialReference sourceNode =
    (
        local rowIndex = findCanonicalRowByName materialName
        if rowIndex > 0 then
        (
            #(canonicalRows[rowIndex][1], "MATCH")
        )
        else
        (
            local newID = (maxCanonicalID canonicalRows) + 1
            if newID > 60000 do
                throw "Cannot append a material because the next Material ID exceeds MAXScript's 60,000 limit."
            append canonicalRows #(newID, materialName, materialReference,
                ("PENDING APPEND : " + sourceNode.name), #pending, sourceNode, 0)
            pendingCount += 1
            #(newID, "PENDING APPEND")
        )
    )

    fn analyzeMultiTarget nodeValue materialValue =
    (
        local materialRows = getDefinedMultiRows materialValue
        local remapRows = #()
        local targetError = ""

        if materialValue.materialList.count != materialValue.materialIDList.count then
            targetError = "materialList/materialIDList lengths do not match."

        for materialRow in materialRows while targetError == "" do
        (
            local oldID = materialRow[1]
            local materialName = materialRow[2]
            local materialReference = materialRow[3]

            if materialName.count == 0 then
                targetError = "Material ID " + (oldID as string) + " has an empty material name."
            else
            (
                local sameIDRows = findMultiRowByID materialRows oldID
                if sameIDRows.count > 1 then
                    targetError = "Material ID " + (oldID as string) + " is assigned to multiple sub-material slots."
                else
                (
                    local canonicalResult = ensureVirtualCanonical materialName materialReference nodeValue
                    append remapRows #(oldID, materialName, canonicalResult[1], canonicalResult[2], materialReference)
                    if canonicalResult[2] == "MATCH" do matchedCount += 1
                )
            )
        )

        if targetError == "" do
        (
            local faceIDs = getUniqueFaceIDs nodeValue
            for faceID in faceIDs while targetError == "" do
            (
                if (findMultiRowByID materialRows faceID).count == 0 do
                    targetError = "Face Material ID " + (faceID as string) + " has no defined target sub-material."
            )
        )

        if targetError == "" then
            #(nodeValue, "READY", "Ready", remapRows, true)
        else
            #(nodeValue, "ERROR", targetError, remapRows, false)
    )

    fn analyzeSingleTarget nodeValue materialValue =
    (
        local materialName = safeMaterialName materialValue
        if materialName.count == 0 then
            #(nodeValue, "ERROR", "The single material has an empty name.", #(), false)
        else
        (
            local canonicalResult = ensureVirtualCanonical materialName materialValue nodeValue
            local remapRows = #()
            local faceIDs = getUniqueFaceIDs nodeValue
            for faceID in faceIDs do
                append remapRows #(faceID, materialName, canonicalResult[1], canonicalResult[2], materialValue)
            if canonicalResult[2] == "MATCH" do matchedCount += 1
            #(nodeValue, "READY", "Ready (single material)", remapRows, true)
        )
    )

    fn analyzeTarget nodeValue =
    (
        if not isValidStoredNode nodeValue then
            #(nodeValue, "INVALID", "The Target node is invalid.", #(), false)
        else if nodeValue.material == undefined then
            #(nodeValue, "NO MATERIAL", "Skipped: no material assigned.", #(), false)
        else if not isEditablePolyNode nodeValue then
            #(nodeValue, "UNSUPPORTED", "Skipped: the base object is not Editable Poly.", #(), false)
        else
        (
            try
            (
                if isMultiMaterial nodeValue.material then
                    analyzeMultiTarget nodeValue nodeValue.material
                else
                    analyzeSingleTarget nodeValue nodeValue.material
            )
            catch
            (
                #(nodeValue, "ERROR", ("Analysis failed: " + exceptionText()), #(), false)
            )
        )
    )

    fn refreshTargetList =
    (
        local selectedNodes = #()
        local previousSelection = lbTargets.selection
        for indexValue = 1 to targetNodes.count where previousSelection[indexValue] do
            append selectedNodes targetNodes[indexValue]

        cleanStoredNodes()
        local itemNames = #()
        for nodeValue in targetNodes do
        (
            local analysis = findTargetAnalysis nodeValue
            local suffix = if analysis == undefined then "" else "  [" + analysis[2] + "]"
            append itemNames (nodeValue.name + suffix)
        )
        lbTargets.items = itemNames

        local restoredSelection = #{}
        for indexValue = 1 to targetNodes.count where (findItem selectedNodes targetNodes[indexValue]) > 0 do
            restoredSelection[indexValue] = true
        lbTargets.selection = restoredSelection
    )

    fn refreshMasterUI =
    (
        cleanStoredNodes()
        lblMaster.text = if isValidStoredNode masterNode then
            "Master Object: " + masterNode.name
        else
            "Master Object: Not set"
    )

    fn refreshCanonicalTable =
    (
        clearListView lvCanonical
        canonicalRows = sortCanonicalRowsByID canonicalRows
        lvCanonical.beginUpdate()
        for rowValue in canonicalRows do
            addListViewRow lvCanonical #(
                (rowValue[1] as string),
                rowValue[2],
                preprocessMaterialTypeText rowValue[3],
                canonicalStatusText rowValue
            )
        lvCanonical.endUpdate()
    )

    fn refreshPreview targetIndex:0 =
    (
        clearListView lvRemap
        local selectedIndex = targetIndex
        if selectedIndex == 0 and lbTargets.selection.numberSet > 0 do
            selectedIndex = (lbTargets.selection as array)[1]

        if selectedIndex < 1 or selectedIndex > targetNodes.count then
            lblPreviewTarget.text = "Target: Select one target from the list"
        else
        (
            local nodeValue = targetNodes[selectedIndex]
            local analysis = findTargetAnalysis nodeValue
            if analysis == undefined then
                lblPreviewTarget.text = "Target: " + nodeValue.name + " (run Analyze)"
            else
            (
                lblPreviewTarget.text = "Target: " + nodeValue.name + " | " + analysis[2] + " | " + analysis[3]
                lvRemap.beginUpdate()
                for remapRow in analysis[4] do
                    addListViewRow lvRemap #((remapRow[1] as string), remapRow[2], (remapRow[3] as string), remapStatusText remapRow)
                lvRemap.endUpdate()
            )
        )
    )

    fn refreshSummary =
    (
        local masterName = if isValidStoredNode masterNode then masterNode.name else "None"
        lblSummary.text = "MASTER: " + masterName +
            " | Targets: " + (targetNodes.count as string) +
            " | Materials: " + (canonicalRows.count as string) +
            " | Matched: " + (matchedCount as string) +
            " | Pending Append: " + (pendingCount as string)
        lblConversionSummary.text = "USD: " + (usdMaterialCount as string) +
            " | Existing VRay: " + (existingVRayCount as string) +
            " | Unsupported: " + (unsupportedMaterialCount as string) +
            " | Texture Ignored: " + (textureIgnoredCount as string) +
            " | Conflicts: " + (preprocessConflictCount as string)
    )

    fn refreshAllUI =
    (
        refreshMasterUI()
        refreshTargetList()
        refreshCanonicalTable()
        refreshPreview()
        refreshSummary()
    )

    fn invalidateAnalysis message =
    (
        canonicalRows = #()
        targetAnalyses = #()
        matchedCount = 0
        pendingCount = 0
        scopedMaterials = #()
        conversionPlan = #()
        diffuseConflictNames = #()
        usdMaterialCount = 0
        existingVRayCount = 0
        unsupportedMaterialCount = 0
        textureIgnoredCount = 0
        preprocessConflictCount = 0
        preprocessErrorText = ""
        analysisReady = false
        analysisHasConflict = false
        refreshAllUI()
        if message != "" do setStatus message
    )

    fn setMasterNode nodeValue =
    (
        if not isValidStoredNode nodeValue then
        (
            setStatus "Select one valid object for Master."
            false
        )
        else
        (
            masterNode = nodeValue
            for indexValue = targetNodes.count to 1 by -1 where targetNodes[indexValue] == masterNode do
                deleteItem targetNodes indexValue
            invalidateAnalysis ("MASTER set: " + masterNode.name)
            true
        )
    )

    fn captureMasterFromSelection =
    (
        if selection.count != 1 then
        (
            setStatus "Select exactly one object, then press Set Master."
            false
        )
        else setMasterNode selection[1]
    )

    fn addTargetNodes nodesToAdd =
    (
        local addedCount = 0
        for nodeValue in nodesToAdd do
        (
            if isValidStoredNode nodeValue and nodeValue != masterNode and (findItem targetNodes nodeValue) == 0 do
            (
                append targetNodes nodeValue
                addedCount += 1
            )
        )
        invalidateAnalysis ("Added " + (addedCount as string) + " Target(s).")
        addedCount
    )

    fn addSelectedTargets =
    (
        addTargetNodes (for nodeValue in selection collect nodeValue)
    )

    fn removeSelectedTargets =
    (
        local selectedIndices = lbTargets.selection
        local removedCount = selectedIndices.numberSet
        for indexValue = targetNodes.count to 1 by -1 where selectedIndices[indexValue] do
            deleteItem targetNodes indexValue
        invalidateAnalysis ("Removed " + (removedCount as string) + " Target(s).")
        removedCount
    )

    fn clearTargetNodes =
    (
        targetNodes = #()
        invalidateAnalysis "Targets cleared."
        true
    )

    fn analyzeAll updateUI:true =
    (
        cleanStoredNodes()
        targetAnalyses = #()
        matchedCount = 0
        pendingCount = 0
        analysisReady = false

        local preprocessOK = analyzePreprocess()
        local masterOK = buildMasterCanonical()
        if not masterOK then
        (
            if updateUI do refreshAllUI()
            false
        )
        else if targetNodes.count == 0 then
        (
            setStatus "Add at least one Target."
            if updateUI do refreshAllUI()
            false
        )
        else
        (
            for nodeValue in targetNodes do append targetAnalyses (analyzeTarget nodeValue)
            canonicalRows = sortCanonicalRowsByID canonicalRows
            analysisReady = not analysisHasConflict and preprocessOK

            local readyTargets = 0
            local skippedTargets = 0
            local errorTargets = 0
            for analysis in targetAnalyses do
            (
                if analysis[5] then readyTargets += 1
                else if analysis[2] == "NO MATERIAL" or analysis[2] == "UNSUPPORTED" then skippedTargets += 1
                else errorTargets += 1
            )

            if readyTargets == 0 do analysisReady = false
            if errorTargets > 0 do analysisReady = false

            if preprocessConflictCount > 0 then
                setStatus ("CONFLICT: SAME NAME / DIFFERENT DIFFUSE in " + (preprocessConflictCount as string) + " material name(s). Apply is blocked.")
            else if not preprocessOK then
                setStatus (if preprocessErrorText != "" then preprocessErrorText else "ERROR: USD preprocess validation failed. Scene was not changed.")
            else if analysisHasConflict then
                setStatus "MASTER has duplicate/conflicting names or IDs. Apply is blocked."
            else if errorTargets > 0 then
                setStatus ("Analyze found " + (errorTargets as string) + " error Target(s). Apply is blocked.")
            else if readyTargets == 0 then
                setStatus "No applicable Target remains."
            else
                setStatus ("Analyze complete: " + (readyTargets as string) + " ready, " +
                    (skippedTargets as string) + " skipped, " + (pendingCount as string) + " pending append.")

            if updateUI do refreshAllUI()
            analysisReady
        )
    )

    fn appendPendingMaterials masterMaterial =
    (
        local appendedCount = 0
        for rowValue in canonicalRows where rowValue[5] == #pending do
        (
            local newSlot = masterMaterial.materialList.count + 1
            masterMaterial.materialList.count = newSlot
            masterMaterial.materialIDList.count = newSlot
            masterMaterial.names.count = newSlot
            masterMaterial.mapEnabled.count = newSlot
            masterMaterial.materialList[newSlot] = rowValue[3]
            masterMaterial.materialIDList[newSlot] = rowValue[1]
            masterMaterial.names[newSlot] = rowValue[2]
            masterMaterial.mapEnabled[newSlot] = true
            appendedCount += 1
        )
        appendedCount
    )

    fn remapTargetFaces nodeValue remapRows =
    (
        local faceCount = polyop.getNumFaces nodeValue
        local facesByMapping = #()
        for remapRow in remapRows do append facesByMapping #{}

        for faceIndex = 1 to faceCount do
        (
            local oldID = polyop.getFaceMatID nodeValue faceIndex
            local mappingIndex = 0
            for indexValue = 1 to remapRows.count while mappingIndex == 0 do
            (
                if remapRows[indexValue][1] == oldID do mappingIndex = indexValue
            )
            if mappingIndex == 0 then
                throw ("Face " + (faceIndex as string) + " uses unmapped Material ID " + (oldID as string) + ".")
            else
                facesByMapping[mappingIndex][faceIndex] = true
        )

        for indexValue = 1 to remapRows.count where facesByMapping[indexValue].numberSet > 0 do
            polyop.setFaceMatID nodeValue facesByMapping[indexValue] remapRows[indexValue][3]
        true
    )

    fn verifyTarget nodeValue remapRows masterMaterial =
    (
        local verified = nodeValue.material == masterMaterial
        if verified do
        (
            local faceCount = polyop.getNumFaces nodeValue
            for faceIndex = 1 to faceCount while verified do
            (
                local currentID = polyop.getFaceMatID nodeValue faceIndex
                local isExpected = false
                for remapRow in remapRows where remapRow[3] == currentID do
                (
                    isExpected = true
                    exit
                )
                if not isExpected do verified = false
            )
        )
        verified
    )

    fn applyNormalization =
    (
        if not analyzeAll updateUI:true then
        (
            lmnLog "WARN" "Normalize / Apply was blocked by validation."
            false
        )
        else
        (
            local preprocessValidation = validatePreprocessOptions()
            if not preprocessValidation[1] then
            (
                setStatus preprocessValidation[2]
                lmnLog "ERROR" preprocessValidation[2]
                false
            )
            else
            (
                local masterMaterial = masterNode.material
                local appendedCount = 0
                local normalizedCount = 0
                local convertedCount = 0
                local failedCount = 0
                local applicableAnalyses = for analysis in targetAnalyses where analysis[5] collect analysis

                undo "Convert USD and Normalize Material IDs" on
                (
                    try
                    (
                        convertedCount = applyUSDConversions()

                        if convertedCount > 0 do
                        (
                            if not analyzeAll updateUI:false do
                                throw "Post-conversion validation failed before Material ID normalization."
                            masterMaterial = masterNode.material
                            applicableAnalyses = for analysis in targetAnalyses where analysis[5] collect analysis
                        )

                        appendedCount = appendPendingMaterials masterMaterial

                        for analysis in applicableAnalyses do
                        (
                            local nodeValue = analysis[1]
                            try
                            (
                                remapTargetFaces nodeValue analysis[4]
                                nodeValue.material = masterMaterial
                                if verifyTarget nodeValue analysis[4] masterMaterial then
                                    normalizedCount += 1
                                else
                                (
                                    failedCount += 1
                                    lmnLog "ERROR" (nodeValue.name + ": post-apply verification failed.")
                                )
                            )
                            catch
                            (
                                failedCount += 1
                                lmnLog "ERROR" (nodeValue.name + ": " + exceptionText())
                            )
                        )
                    )
                    catch
                    (
                        failedCount += applicableAnalyses.count
                        lmnLog "ERROR" ("Apply failed: " + exceptionText())
                    )
                )

                lastApplyConvertedCount = convertedCount
                lastApplyAppendedCount = appendedCount
                redrawViews()
                analyzeAll updateUI:true

                local glossinessText = if chkConvertUSD.checked and chkOverrideGlossiness.checked then
                    formattedPrint spnGlossiness.value format:".2f"
                else "OFF"
                local reflectionText = if chkConvertUSD.checked and chkOverrideReflection.checked then
                    ((cpReflection.color.r as integer) as string) + "," +
                    ((cpReflection.color.g as integer) as string) + "," +
                    ((cpReflection.color.b as integer) as string)
                else "OFF"
                local resultMessage = "Normalized " + (normalizedCount as string) +
                    " object(s). Converted " + (convertedCount as string) +
                    " USD. Appended " + (appendedCount as string) +
                    ". Glossiness: " + glossinessText + " / Reflection: " + reflectionText
                if failedCount > 0 do resultMessage += " / " + (failedCount as string) + " failed"
                setStatus resultMessage
                lmnLog "INFO" resultMessage
                failedCount == 0 and normalizedCount > 0
            )
        )
    )

    on LunarMaterialIDNormalizerRollout open do
    (
        configureListView lvCanonical #(#("ID", 44), #("Material Name", 142), #("Type", 104), #("Source / Status", 142))
        configureListView lvRemap #(#("Old ID", 62), #("Material", 265), #("New ID", 62), #("Status", 310))
        updatePreprocessControlStates()
        refreshAllUI()
    )

    on chkConvertUSD changed state do
    (
        updatePreprocessControlStates()
        invalidateAnalysis "USD conversion option changed. Run Analyze again."
    )

    on chkOverrideGlossiness changed state do
    (
        updatePreprocessControlStates()
        invalidateAnalysis "Glossiness override option changed. Run Analyze again."
    )

    on spnGlossiness changed value do
        invalidateAnalysis "Glossiness override value changed. Run Analyze again."

    on chkOverrideReflection changed state do
    (
        updatePreprocessControlStates()
        invalidateAnalysis "Reflection override option changed. Run Analyze again."
    )

    on cpReflection changed colorValue do
        invalidateAnalysis "Reflection override color changed. Run Analyze again."

    on btnSetMaster pressed do captureMasterFromSelection()

    on btnClearMaster pressed do
    (
        masterNode = undefined
        invalidateAnalysis "MASTER cleared."
    )

    on btnAddTargets pressed do addSelectedTargets()
    on btnRemoveTargets pressed do removeSelectedTargets()

    on btnClearTargets pressed do
    (
        clearTargetNodes()
    )

    on lbTargets selected indexValue do refreshPreview targetIndex:indexValue
    on btnAnalyze pressed do analyzeAll updateUI:true
    on btnApply pressed do applyNormalization()
)

createDialog LunarMaterialIDNormalizerRollout style:#(#style_titlebar, #style_sysmenu, #style_minimizebox)
