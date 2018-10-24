local _, ns = ...
local ta = ns.ta

do
    local EJ_GetNumTiers, EJ_GetInstanceByIndex, EJ_GetEncounterInfoByIndex = EJ_GetNumTiers, EJ_GetInstanceByIndex, EJ_GetEncounterInfoByIndex
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

    function ta:NotifyConfigChange()
        AceConfigRegistry:NotifyChange("ToshAssignments")
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
                assignments = {
                    name = "Assignments",
                    type = 'group',
                    inline = true,
                    args = {
                        description = {
                            name = "Click on an assignment to open its configuration",
                            type = 'description',
                            order = 1,
                        },
                    },
                    order = 4,
                },
            },
        }
        local assignments = noteOptions.args.assignments

        local addAssignment = function(assignment)
            assignments.args["assign"..assignment.id] = {
                name = function() return assignment.name end,
                type = 'execute',
                func = function()
                    ta:ShowAssignment(note, assignment)
                end,
                width = 'full',
                order = 10+assignment.id,
            }
            assignment.removeOptions = function()
                assignments.args["assign"..assignment.id] = nil
                ta:NotifyConfigChange()
            end
        end

        assignments.args.addAssignment = {
            name = "Add Assignment",
            type = 'execute',
            func = function()
                local assignment = {
                    id = (#note.assignments+1),
                    trigger = {},
                    actions = {},
                }
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
        for _, note in pairs(ta.db.profile.encounters[encounter.encounterId]) do
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
                    encounterId = encounter.encounterId,
                    assignments = {},
                }
                ta.db.profile.encounters[encounter.encounterId][name] = note
                loadNoteOptions(note, notes)
            end,
        }

        return encounterOptions
    end

    local function loadEncounterOptions(options)
        local loaded, reason = LoadAddOn("Blizzard_EncounterJournal")
        if not loaded then
            ta:Printf("Could not load EncounterJournal: %s", reason)
            return
        end

        local legacy = {
            name = "Legacy Tiers",
            type = 'group',
            order = 1000,
            args = {},
        }
        options.args.legacy = legacy

        local maxTiers = EJ_GetNumTiers()
        for i=1,maxTiers do
            local tier = ns:GetTier(i)
            if not tier then 
                ta:Printf("No tier info for tier %d", i)
                break
            end
            local tierOptions = {
                name = tier.name,
                type = 'group',
                order = (maxTiers - tier.index),
                args = {},
            }
            local maxraids = #tier.raids
            for idx, raid in pairs(tier.raids) do
                local instanceOptions = {
                    name = raid.name,
                    type = 'group',
                    args = {},
                    order = (maxraids - idx),
                }
                for eIdx, encounter in ipairs(raid.encounters) do
                    local eo = encounterOptions(encounter)
                    eo.order = eIdx
                    instanceOptions.args[tostring(encounter.encounterId)] = eo
                end
                if i == maxTiers then
                    options.args[tostring(raid.instanceId)] = instanceOptions
                else
                    tierOptions.args[tostring(raid.instanceId)] = instanceOptions
                end
            end

            local dungeonOptions = {
                name = "Dungeons",
                type = 'group',
                order = 500,
                args = {},
            }
            for idx, dungeon in ipairs(tier.dungeons) do
                local instanceOptions = {
                    name = dungeon.name,
                    type = 'group',
                    args = {},
                    order = idx,
                }
                for eIdx, encounter in ipairs(dungeon.encounters) do
                    local eo = encounterOptions(encounter)
                    eo.order = eIdx
                    instanceOptions.args[tostring(encounter.encounterId)] = eo
                end
                dungeonOptions.args[tostring(dungeon.instanceId)] = instanceOptions
            end

            if i == maxTiers then
                options.args.dungeons = dungeonOptions
            else
                tierOptions.args.dungeons = dungeonOptions
                legacy.args[tostring(i)] = tierOptions
            end
        end
    end

    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local AceTimer = LibStub("AceTimer-3.0")
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
            -- AceConfigDialog:SelectGroup("ToshAssignments", tostring(EJ_GetCurrentTier()))
        else
            ta:NotifyConfigChange()
        end
    end
end
