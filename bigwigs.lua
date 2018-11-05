local _, ns = ...
local ta = ns.ta

local plugin, CL

local hookPrototype = {}
local hooks = {}

local function initPlugin()
    plugin, CL = BigWigs:NewPlugin("ToshAssignments")
    if not plugin then return end

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

    function plugin:Log(boss, event, _, ...)
        if eid and plugin.encounter then
            local spells = ta.db.global.encounterSpells[boss.journalId]
            for i = 1, select("#", ...) do
                local id = select(i, ...)
                if id and GetSpellInfo(id) then
                    tinsert(spells, id)
                    -- ta:Print(boss.moduleName, "spell", id, GetSpellInfo(id))
                end
            end
            -- ViragDevTool_AddData(spells, boss.modeleName .. "_spells")
        end
    end

    function plugin:BigWigs_BossModuleRegistered(_, name, module)
        if not module.journalId then return end
        if hooks[name] then return end
        self:Hook(module, "Log", "Log", false)

        plugin.encounter = ns:GetEncounterById(module.journalId)
        if module.journalId == 1731 then
            ViragDevTool_AddData({name=name, module=module, encounter=plugin.encounter}, "bw_"..name.."_encounter")
        end
        if plugin.encounter then
            plugin.encounter.load = function()
                module:Enable()
            end
        end
        
        if module.journalId and ta.db.profile.encounters[module.journalId] then
            local hook = setmetatable({
                plugin = self,
                encounter = ta.db.profile.encounters[module.journalId],
                bossModule = module,

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
            self:RegisterMessage("BigWigs_OnBossWin", function(...) hook:EndEncounter(...) end)
            self:RegisterMessage("BigWigs_OnBossWipe", function(...) hook:EndEncounter(...) end)
            hook:RegisterEvent("ENCOUNTER_START", function(...) hook:ENCOUNTER_START(...) end)
            hook:RegisterEvent("ENCOUNTER_END", function(...) hook:ENCOUNTER_END(...) end)

            hooks[name] = hook

            ta:Print("Hooked", name)
        end
    end

    function plugin:CheckOption(key, option)
        return true
    end

    ta:Print("BigWigs plugin loaded")
    loaded = true
end

do
    local GetTime, UnitName = GetTime, UnitName

    function hookPrototype:ENCOUNTER_START(_, id)
        if id == self.bossModule.engageId then
            self.encounterStart = GetTime()
            
            for _, note in pairs(self.encounter) do
                if note.enabled then
                    for _, assign in pairs(note.assignments) do
                        if assign.trigger.type == 'time' and self:assignedToMe(note, assign) then
                            local assignEndTime = self.encounterStart + assign.trigger.time.encounterTime
                            self:handleAssign(note, assign, assignEndTime)
                        end
                    end
                end
            end
        end
    end

    function hookPrototype:ENCOUNTER_END(_, id)
        if id == self.bossModule.engageId then
            self.encounterStart = nil
        end
    end

    function hookPrototype:EndEncounter()
        self:CancelAllTimers()
        
        for _, note in pairs(self.encounter) do
            for _, assign in pairs(note.assignments) do
                for _, action in pairs(assign.actions) do
                    local key = {
                        note = note,
                        assign = assign,
                        action = action,
                    }
                    self:SendMessage("BigWigs_StopBar", self.plugin, key)
                    self:SendMessage("BigWigs_StopEmphasize", self.plugin, key)
                end
            end
        end
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

        for match in assignment.trigger.spell.eventNumber:gmatch("(.-),") do
            if matchFunc(elem) then
                return true
            end
        end
        return matchFunc(assignment.trigger.spell.eventNumber)
    end

    local SetRaidTarget = SetRaidTarget
    local function applyMarks(marks)
        for player, markerType in pairs(marks) do
            local iconId = tonumber(markerType:sub(7))
            SetRaidTarget(player, iconId)
        end
    end

    function hookPrototype:handleAssign(note, assign, assignEndTime)
        ViragDevTool_AddData(assign, note.name .. "-" .. assign.name)
        local now = GetTime()
        for _, action in pairs(assign.actions) do
            local key = {
                note = note,
                assign = assign,
                action = action,
            }

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
                    self:SendMessage("BigWigs_StartBar", self.plugin, key, assign.name, assignEndTime - now, actionIcon)
                else
                    self:ScheduleTimer(
                        function()
                            self:SendMessage("BigWigs_StartBar", self.plugin, key, assign.name, action.bar.duration, actionIcon)
                        end,
                        actionStartTime - now
                    )
                end

            elseif action.type == 'marker' then
                if assignEndTime <= now then
                    applyMarks(action.marker.marks)
                else
                    self:ScheduleTimer(applyMarks, assignEndTime - now, action.marker.marks)
                end

            elseif action.type == 'countdown' then
                self:SendMessage("BigWigs_StartEmphasize", self.plugin, key, assign.name, assignEndTime - now)
            end
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
                    if assign.trigger.type == 'spell' and self:assignedToMe(note, assign) and self:checkEventNumber(assign, key) then
                        local tspellId = assign.trigger.spell.spellId
                        if tspellId and tspellId == key then
                            local assignEndTime = barEndTime - assign.trigger.spell.before
                            self:handleAssign(note, assign, assignEndTime)
                        end
                    end 
                end
            end
        end
    end
end

local function loadInstance(instanceId)
    local instanceAddon = BigWigsLoader.zoneTbl[instanceId]
    if ns:IsAddOnEnabled(instanceAddon) then
        local loaded, reason = LoadAddOn(instanceAddon)
        if not loaded then
            ta:Printf("Could not load %s addon for %d: %s", instanceAddon, instanceId, reason)
            return
        end
    end
end

do
    local loaded = false
    local AceHook = LibStub("AceHook-3.0")

    local tinsert, GetSpellInfo = table.insert, GetSpellInfo

    function ns:LoadBigWigs_Core()
        if not loaded then
            initPlugin()
            ns.LoadInstance = loadInstance
        end
    end
end
