local _, ns = ...
local ta = ns.ta

local plugin, CL

local function EncounterOptions(encounterid)
  for name, module in BigWigs:IterateBossModules() do
  end
end

function ns:LoadBigWigs()
  plugin, CL = BigWigs:NewPlugin("ToshAssignments")
  ta.EncounterOptions = EncounterOptions
  ta:Print("Tosh |cff327da3Assignments|r plugin loaded")
end
