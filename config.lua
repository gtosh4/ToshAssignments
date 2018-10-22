local _, ns = ...
local ta = ns.ta

do
    local EJ_GetNumTiers, EJ_GetInstanceByIndex, EJ_GetEncounterInfoByIndex = EJ_GetNumTiers, EJ_GetInstanceByIndex, EJ_GetEncounterInfoByIndex
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

    function ta:NotifyConfigChange()
        AceConfigRegistry:NotifyChange("ToshAssignments")
    end

    local function tiers()
        local tiers = {}
        local current = EJ_GetCurrentTier()
        for i=1,EJ_GetNumTiers() do
            local tier = {
                index = i,
                current = (i == current),
            }
            tier.name = EJ_GetTierInfo(i)
            table.insert(tiers, tier)
        end
        return tiers
    end

    local function raids()
        local instances = {}
        local index = 1
        while true do
            local instance = {}
            instance.id, instance.name = EJ_GetInstanceByIndex(index, true)
            if not instance.name then break end
            table.insert(instances, instance)
            index = index + 1
        end
        return instances
    end
        
    local function dungeons()
        local instances = {}
        local index = 1
        while true do
            local instance = {}
            instance.id, instance.name = EJ_GetInstanceByIndex(index, false)
            if not instance.name then break end
            table.insert(instances, instance)
            index = index + 1
        end
        return instances
    end

    local function encounters(instanceId)
        local encounters = {}
        local index = 1
        while true do
            local encounter = {instanceId = instanceId}
            encounter.name, _, encounter.id = EJ_GetEncounterInfoByIndex(index, instanceId)
            if not encounter.name then break end
            table.insert(encounters, encounter)
            index = index + 1
        end
        return encounters
    end

    local function loadNoteOptions(note, noteGroup)
        note.assignments = note.assignments or {}

        local noteOptions = {
            name = note.name,
            type = 'group',
            args = {
                delete =  {
                    name = "Delete",
                    type = 'execute',
                    confirm = function() return "Delete "..note.name.."?" end,
                    func = function()
                        ta.db.profile.encounters[note.encounterId][note.name] = nil
                        noteGroup.args[note.name] = nil
                    end,
                    order = 1,
                },
                enabled = {
                    name = "Enabled",
                    type = 'toggle',
                    get = function() return note.enabled end,
                    set = function(info, value) note.enabled = value end,
                    order = 2,
                },
                break1 = {
                    name = "",
                    type = 'description',
                    width = 'full',
                    order = 3,
                },
            },
        }

        local addAssignment = function(assignment)
            noteOptions.args["assign"..assignment.id] = {
                name = function() return assignment.name end,
                type = 'execute',
                func = function()
                    ta:ShowAssignment(note, assignment)
                end,
                width = 'full',
                order = 10+assignment.id,
            }
            assignment.removeOptions = function()
                noteOptions.args["assign"..assignment.id] = nil
                ta:NotifyConfigChange()
            end
        end

        noteOptions.args.addAssignment = {
            name = "Add Assignment",
            type = 'execute',
            func = function()
                local assignment = { id=(#note.assignments+1) }
                assignment.name = assignment.name or "Assignment "..assignment.id
                note.assignments[assignment.id] = assignment
                addAssignment(assignment)
                ta:ShowAssignment(note, assignment)
            end,
            order = -1,
        }

        for _, assignment in ipairs(note.assignments) do
            addAssignment(assignment)
        end
        
        noteGroup.args[note.name] = noteOptions
    end

    local function encounterOptions(encounter)
        local encounterOptions = {
            name = encounter.name,
            type = 'group',
            childGroups = 'tab',
            args = {},
        }
        local notes = {
            name = "Notes",
            type = 'group',
            args = {},
            order = -1,
        }
        encounterOptions.args.notes = notes
        for _, note in pairs(ta.db.profile.encounters[encounter.id]) do
            loadNoteOptions(note, notes)
        end

        local name
        encounterOptions.args.name = {
            name = "Name",
            type = 'input',
            order = 10,
            get = function(info)
                return name
            end,
            set = function(info, value)
                name = value
            end,
        }
        encounterOptions.args.add = {
            name = function()
                return "Create "..(name or "new")
            end,
            type = 'execute',
            disabled = function()
                return name == nil or name == ""
            end,
            order = 20,
            func = function()
                local note = {
                    name = name,
                    enabled = true,
                    encounterId = encounter.id,
                    assignments = {},
                }
                ta.db.profile.encounters[encounter.id][name] = note
                loadNoteOptions(note, notes)
            end,
        }

        return encounterOptions
    end

    local function loadEncounterOptions(options)
        local loaded, reason = LoadAddOn("Blizzard_EncounterJournal")
        if not loaded then
            print("Could not load EncounterJournal: ", reason)
            return
        end

        for _, tier in ipairs(tiers()) do
            local tierOptions = {
                name = tier.name,
                type = 'group',
                order = tier.index,
                args = {},
            }
            local load = {name="Load", type='execute'}
            load.func = function()
                tierOptions.args = {}

                EJ_SelectTier(tier.index)

                for idx, instance in ipairs(raids()) do
                    local instanceOptions = {
                        name = instance.name,
                        type = 'group',
                        args = {},
                        order = idx,
                    }
    
                    for eIdx, encounter in ipairs(encounters(instance.id)) do
                        local eo = encounterOptions(encounter)
                        eo.order = eIdx
                        instanceOptions.args[tostring(encounter.id)] = eo
                    end
                    tierOptions.args[tostring(instance.id)] = instanceOptions
                end

                local dungeonOptions = {
                    name = "Dungeons",
                    type = 'group',
                    args = {},
                    order = -1,
                }
                tierOptions.args["dungeons"] = dungeonOptions
                for idx, instance in ipairs(dungeons()) do
                    local instanceOptions = {
                        name = instance.name,
                        type = 'group',
                        args = {},
                        order = idx,
                    }

                    for eIdx, encounter in ipairs(encounters(instance.id)) do
                        local eo = encounterOptions(encounter)
                        eo.order = eIdx
                        instanceOptions.args[tostring(encounter.id)] = eo
                    end
                    dungeonOptions.args[tostring(instance.id)] = instanceOptions
                end

                EJ_SelectTier(EJ_GetCurrentTier())
            end
            tierOptions.args.load = load
            options.args[tostring(tier.index)] = tierOptions

            -- When we're loading this, for some reason not all the encounters are loaded.
            -- Maybe find some way to load it at the correct spot?
            -- if tier.current then
            --     load.func()
            -- end
        end
    end

    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    function ta:InitializeOptions(force)
        if self.options and not force then return end

        local fresh = self.options == nil

        self.options = self.options or {
            name = "Tosh Assignments",
            type = 'group',
        }
        self.options.args = {}

        self.options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
        self.options.args.profile.order = -1

        loadEncounterOptions(self.options)

        if fresh then -- do only once
            AceConfig:RegisterOptionsTable("ToshAssignments", self.options)
            AceConfigDialog:AddToBlizOptions("ToshAssignments", "Tosh Assignments")
            AceConfigDialog:SelectGroup("ToshAssignments", tostring(EJ_GetCurrentTier()))
        end
    end
end
