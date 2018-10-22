local addonName, ns = ...
local ta = LibStub("AceAddon-3.0"):NewAddon("ToshAssignments", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
ns.ta = ta

do
    local defaultProfile = {
        global = {
        },
        profile = {
        },
    }

    function ta:OnInitialize()
        self.db = LibStub("AceDB-3.0"):New("ToshAssignmentsDB", defaultProfile, true)
        if IsAddOnLoaded("BigWigs_Core") then
            ns:LoadBigWigs()
        end
        ta:RegisterEvent('ADDON_LOADED')
        ta:RegisterEvent('PLAYER_ENTERING_WORLD')
    end
end

function ta:ADDON_LOADED(self, event, addon)

    if addon == "BigWigs_Core" then
        ns:LoadBigWigs()
    end
end

function ta:PLAYER_ENTERING_WORLD()
    ta:InitializeOptions()
end

do
    ta:RegisterChatCommand("ta", "SlashTA")
end

do
    local EJ_GetNumTiers, EJ_GetInstanceByIndex, EJ_GetEncounterInfoByIndex = EJ_GetNumTiers, EJ_GetInstanceByIndex, EJ_GetEncounterInfoByIndex

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
            local encounter = {}
            encounter.name, _, encounter.id = EJ_GetEncounterInfoByIndex(index, instanceId)
            if not encounter.name then break end
            table.insert(encounters, encounter)
            index = index + 1
        end
        return encounters
    end

    local function encounterOptions(encounter)
        local encounterOptions = {
            name = encounter.name,
            type = 'group',
            childGroups = 'tab',
            args = {},
        }
        local name
        encounterOptions.args.name = {
            name = "Name",
            type = 'input',
            -- width = 'half',
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
            -- width = 'half',
            order = 20,
            func = function()
                self.db.profile[encounter.id] = self.db.profile[encounter.id] or {}
                self.db.profile[encounter.id][name] = {
                    name = name,
                }
            end,
        }
        local notes = {
            name = "Notes",
            type = 'group',
            args = {},
        }
        encounterOptions.args.notes = notes

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

    function ta:InitializeOptions()
        if self.options then return end

        local options = {
            name = "Tosh Assignments",
            type = 'group',
            args = {},
        }

        options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
        options.args.profile.order = -1

        loadEncounterOptions(options)

        LibStub("AceConfig-3.0"):RegisterOptionsTable("ToshAssignments", options)
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ToshAssignments", "Tosh Assignments")
        self.options = options
    end
end

function ta:SlashTA()
    LibStub("AceConfigDialog-3.0"):Open("ToshAssignments")
end

-- Boss Mod functions
function ta:EncounterOptions(encounterid)
    return {}
end
