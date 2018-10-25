local _, ns = ...
local ta = ns.ta

local plugin, CL

do
    local loaded = false

    local GetTime, UnitName = GetTime, UnitName

    function ns:LoadBigWigs()
        if not loaded then
            plugin, CL = BigWigs:NewPlugin("ToshAssignments")

            plugin.displayName = "Tosh |cff327da3Assignments|r"
            
            function plugin:OnPluginEnable()
                self:RegisterMessage("BigWigs_OnBossEngage")
                self:RegisterMessage("BigWigs_OnBossWin")
                self:RegisterMessage("BigWigs_OnBossWipe", "BigWigs_OnBossWin")
                self:RegisterMessage("BigWigs_StartBar")
            end

            function plugin:BigWigs_OnBossEngage(bwBoss)
            end
        
            function plugin:BigWigs_OnBossWin()
                self:CancelAllTimers()
            end
        
            local player = UnitName("player")
            local function assignedToMe(note, assign)
                if (not note.showOthers) and assign.players and (#assign.players > 0) then
                    local hasMe = false
                    for _, assignPlayer in ipairs(assign.players) do
                        if assignPlayer == player then
                            return true
                        end
                    end 
                    return false
                end
                return true
            end

            function plugin:BigWigs_StartBar(_, boss, key, text, time, icon, isApprox)
                if (boss == self) or (type(key) ~= 'number') or (not boss.journalId) then return end
                local encounter = ta.db.profile.encounters[boss.journalId]
                if not encounter then return end

                local now = GetTime()

                local barEndTime = now + time
                for _, note in pairs(encounter) do
                    if note.enabled then
                        for _, assign in pairs(note.assignments) do
                            if assignedToMe(note, assign) then

                                if assign.trigger.type == 'spell' then
                                    local tspellId = assign.trigger.spellId
                                    if tspellId and tspellId == key then
                                        local assignEndTime = barEndTime - (assign.trigger.before or 0)

                                        for _, action in pairs(assign.actions) do
                                            if action.type == 'bar' then
                                                local actionStartTime = assignEndTime - action.bar.duration

                                                if actionStartTime <= now then
                                                    self:SendMessage("BigWigs_StartBar", self, assign.name, assign.name, assignEndTime - now)
                                                else
                                                    self:ScheduleTimer(
                                                        function()
                                                            self:SendMessage("BigWigs_StartBar", self, assign.name, assign.name, action.bar.duration)
                                                        end,
                                                        actionStartTime - now
                                                    )
                                                end
                                            end
                                        end -- Action
                                    end
                                end -- Trigger 'spell'

                            end -- if assigned
                        end -- Assign
                    end
                end -- Note
            end

            ta:Print("Tosh |cff327da3Assignments|r plugin loaded")
            loaded = true
        end
    end
end
