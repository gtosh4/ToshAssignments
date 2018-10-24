local _, ns = ...
local ta = ns.ta

local plugin, CL

do
    local loaded = false

    function ns:LoadBigWigs()
        if not loaded then
            plugin, CL = BigWigs:NewPlugin("ToshAssignments")

            plugin.displayName = "Tosh |cff327da3Assignments|r"
            
            function plugin:OnPluginEnable()
                self:RegisterMessage("BigWigs_OnBossEngage")
                self:RegisterMessage("BigWigs_OnBossWin")
                self:RegisterMessage("BigWigs_OnBossWipe", "BigWigs_OnBossWin")
            end

            local boss
            function plugin:BigWigs_OnBossEngage(bwBoss)
                boss = bwBoss
                self:RegisterMessage("BigWigs_StartBar")
            end
        
            function plugin:BigWigs_OnBossWin()
                boss = nil
                self:UnregisterMessage("BigWigs_StartBar")
            end
        
            function plugin:BigWigs_StartBar(_, module, key, text, time, icon, isApprox)
                if type(key) ~= 'number' then return end
                local endTime = GetTime() + time
                for _, note in pairs(ta.db.profile.encounters[boss.engageId]) do
                    for _, assign in pairs(note.assignments) do
                        local tspellId = assign.trigger.spellId
                        if tspellId then
                            for _, action in pairs(assign.actions) do
                                if action.type == 'bar' then
                                    if action.duration >= time then
                                        self:SendMessage("BigWigs_StartBar", self, assign.name, assign.name, time)
                                    else
                                        self:ScheduleTimer(
                                            function()
                                                self:SendMessage("BigWigs_StartBar", self, assign.name, assign.name, action.duration)
                                            end,
                                            time - action.duration
                                        )
                                    end
                                end
                            end
                        end
                    end
                end
            end

            ta:Print("Tosh |cff327da3Assignments|r plugin loaded")
            loaded = true
        end
    end
end
