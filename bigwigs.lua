local _, ns = ...
local ta = ns.ta

local plugin, CL

local hookPrototype = {}
local hooks = {}

do
    local loaded = false
    local AceHook = LibStub("AceHook-3.0")

    local GetTime, UnitName = GetTime, UnitName

    function ns:LoadBigWigs()
        if not loaded then
            plugin, CL = BigWigs:NewPlugin("ToshAssignments")

            plugin.displayName = "Tosh |cff327da3Assignments|r"
            AceHook:Embed(plugin)
            AceHook:Embed(hookPrototype)
            hookPrototype.player = UnitName("player")
            local hookMeta = {__index = hookPrototype, __metatable = false }
            
            function plugin:OnPluginEnable()
                self:RegisterMessage("BigWigs_BossModuleRegistered")
                for name, module in BigWigs:IterateBossModules() do
                    self:BigWigs_BossModuleRegistered(nil, name, module)
                end
            end

            function plugin:BigWigs_BossModuleRegistered(_, name, module)
                if hooks[name] then return end
                
                if module.journalId and ta.db.profile.encounters[module.journalId] then
                    local hook = setmetatable({
                        plugin = self,
                        encounter = ta.db.profile.encounters[module.journalId],

                        -- Embed callback handler
                        RegisterMessage = self.RegisterMessage,
                        UnregisterMessage = self.UnregisterMessage,
                        SendMessage = self.SendMessage,
        
                        -- Embed event handler
                        RegisterEvent = self.RegisterEvent,
                        UnregisterEvent = self.UnregisterEvent,

                        -- Embed Timer
                        ScheduleTimer = self.ScheduleTimer,
                        CancelAllTimers = self.CancelAllTimers,
                        CancelTimer = self.CancelTimer,
                    }, hookMeta)

                    hook:Hook(module, "Bar", "StartBar", false)
                    hook:Hook(module, "CDBar", "StartBar", false)
                    self:RegisterMessage("BigWigs_OnBossWin", function() hook:EndEncounter() end)
                    self:RegisterMessage("BigWigs_OnBossWipe", function() hook:EndEncounter() end)

                    hooks[name] = hook
                end
            end

            ta:Print("BigWigs plugin loaded")
            loaded = true
        end
    end
end

do
    function hookPrototype:EndEncounter()
        self:CancelAllTimers()
    end

    function hookPrototype:assignedToMe(note, assign)
        if (not note.showOthers) and assign.players and (#assign.players > 0) then
            local hasMe = false
            for _, assignPlayer in ipairs(assign.players) do
                if assignPlayer == self.player then
                    return true
                end
            end 
            return false
        end
        return true
    end

    function hookPrototype:checkEventNumber(assignment, spellId)
        local print = assignment.name == "FB 2-3" and function(...) ta:Print(...) end or function() end
        local spellMeta = self.spellMeta[spellId]
        local matchFunc = function(part)
            for lower, upper in part:gmatch("(%d+)%-(%d+)") do
                lower, upper = tonumber(lower), tonumber(upper)
                if (lower and upper) and spellMeta.number >= lower and spellMeta.number <= upper then
                    return true
                end
            end
            if tonumber(part) then
                return spellMeta.number == tonumber(part)
            elseif part == "*" then
                return true
            end
            return false
        end

        for match in assignment.trigger.eventNumber:gmatch("(.-),") do
            if matchFunc(elem) then
                return true
            end
        end
        return matchFunc(assignment.trigger.eventNumber)
    end

    local SetRaidTarget = SetRaidTarget
    local function applyMarks(marks)
        for player, markerType in pairs(marks) do
            local iconId = tonumber(markerType:sub(7))
            SetRaidTarget(player, iconId)
        end
    end

    function hookPrototype:StartBar(boss, key, length, text, icon)
        if (type(key) ~= 'number') or (not self.encounter) then return end

        local now = GetTime()
        self.spellMeta = self.spellMeta or {}
        self.spellMeta[key] = self.spellMeta[key] or {}
        local spellMeta = self.spellMeta[key]
        spellMeta.number = (spellMeta.number or 0) + 1

        local barEndTime = now + length
        for _, note in pairs(self.encounter) do
            if note.enabled then
                for _, assign in pairs(note.assignments) do
                    if self:assignedToMe(note, assign) and self:checkEventNumber(assign, key) then

                        if assign.trigger.type == 'spell' then
                            local tspellId = assign.trigger.spellId
                            if tspellId and tspellId == key then
                                local assignEndTime = barEndTime - (assign.trigger.before or 0)

                                for _, action in pairs(assign.actions) do
                                    if action.type == 'bar' then
                                        local actionStartTime = assignEndTime - action.bar.duration
                                        local actionIcon
                                        if action.bar.icon == 'auto' then
                                            actionIcon = icon
                                        elseif action.bar.icon:sub(1,6) == "marker" then
                                            actionIcon = ns.raidIconNumbers[tonumber(action.bar.icon:sub(7))]
                                        elseif tonumber(action.bar.icon) then
                                            actionIcon = tonumber(action.bar.icon)
                                        end

                                        if actionStartTime <= now then
                                            self:SendMessage("BigWigs_StartBar", self.plugin, assign.name, assign.name, assignEndTime - now, actionIcon)
                                        else
                                            self:ScheduleTimer(
                                                function()
                                                    self:SendMessage("BigWigs_StartBar", self.plugin, assign.name, assign.name, action.bar.duration, actionIcon)
                                                end,
                                                actionStartTime - now
                                            )
                                        end
                                        -- end 'bar'
                                    elseif action.type == 'marker' then
                                        if assignEndTime > now then
                                            self:ScheduleTimer(applyMarks, assignEndTime - now, action.marker.marks)
                                        else
                                            applyMarks(action.marker.marks)
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
end
