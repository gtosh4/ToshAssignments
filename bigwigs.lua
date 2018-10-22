local _, ns = ...
local ta = ns.ta

local plugin, CL

function ns:LoadBigWigs()
    plugin, CL = BigWigs:NewPlugin("ToshAssignments")
    ta:Print("Tosh |cff327da3Assignments|r plugin loaded")
end
