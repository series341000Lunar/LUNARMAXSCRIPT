/* Read-only V-Ray MAXScript property probe for the installed 3ds Max build. */

global LVMBO_PROBE_REPORT = "C:\\tmp\\lvmbo-vray-property-probe.txt"

fn lvmboProbeWrite textValue =
(
    local stream = openFile LVMBO_PROBE_REPORT mode:"a"
    format "%\n" textValue to:stream
    close stream
)

try (deleteFile LVMBO_PROBE_REPORT) catch()

fn lvmboRunPropertyProbe =
(
    try
    (
        local probeMaterial = execute "VRayMtl()"
        lvmboProbeWrite ("Class: " + (classOf probeMaterial as string))
        lvmboProbeWrite ("SuperClass: " + (superClassOf probeMaterial as string))
        lvmboProbeWrite "Properties:"
        for propertyName in (getPropNames probeMaterial) do
        (
            local valueText = "<unreadable>"
            try (valueText = getProperty probeMaterial propertyName as string) catch()
            lvmboProbeWrite ((propertyName as string) + " = " + valueText)
        )
    )
    catch
    (
        lvmboProbeWrite ("ERROR: " + (getCurrentException() as string))
    )
)

lvmboRunPropertyProbe()

quitMAX #noPrompt
