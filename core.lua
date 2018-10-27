local addonName, ns = ...
local ta = LibStub("AceAddon-3.0"):NewAddon("ToshAssignments", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
ns.ta = ta

do
    local defaultProfile = {
        global = {
        },
        profile = {
            encounters = {
                ["*"] = {},
            },
        },
    }

	local function profileUpdate()
		ta:SendMessage("ToshAssignments_UpdateConfig")
	end

    function ta:OnInitialize()
        self.db = LibStub("AceDB-3.0"):New("ToshAssignmentsDB", defaultProfile, true)
        for _, encounter in pairs(self.db.profile.encounters) do
            for _, note in pairs(encounter) do
                self:DecorateNote(note)
            end
        end
        self:RegisterChatCommand("ta", "SlashTA")
    end

    function ta:OnEnable()
        ta:RegisterMessage("ToshAssignments_UpdateConfig", function() ta:InitializeOptions(true) end)
		self.db.RegisterCallback(ta, "OnProfileChanged", profileUpdate)
		self.db.RegisterCallback(ta, "OnProfileCopied", profileUpdate)
		self.db.RegisterCallback(ta, "OnProfileReset", profileUpdate)

        if IsAddOnLoaded("BigWigs_Core") then
            ns:LoadBigWigs()
        end
        self:RegisterEvent('ADDON_LOADED')
        self:RegisterEvent('PLAYER_ENTERING_WORLD')
        
        self:SetupSharing()
    end
end

function ta:ADDON_LOADED(event, addon)
    if addon == "BigWigs_Core" then
        ns:LoadBigWigs()
    end
end

function ta:PLAYER_ENTERING_WORLD()
    ta:InitializeOptions()
end


local testNote = {
    ["enabled"] = true,
    ["encounterId"] = 2168,
    ["name"] = "Test Note",
    ["assignments"] = {
        {
            ["name"] = "Tosh",
            ["trigger"] = {
                ["before"] = 2,
                ["type"] = "cast",
                ["spellId"] = 271296,
            },
            ["actions"] = {
                {
                    ["id"] = 1,
                    ["type"] = "bar",
                    ["bar"] = {
                    },
                }, -- [1]
                {
                    ["id"] = 2,
                    ["type"] = "bar",
                    ["bar"] = {
                        ["duration"] = 15,
                    },
                }, -- [2]
                {
                    ["id"] = 3,
                    ["type"] = "marker",
                    ["bar"] = {
                    },
                }, -- [3]
            },
            ["id"] = 1,
        }, -- [1]
        {
            ["name"] = "Assignment 2",
            ["trigger"] = {
            },
            ["actions"] = {
                {
                    ["id"] = 1,
                    ["type"] = "bar",
                    ["bar"] = {
                    },
                }, -- [1]
            },
            ["id"] = 2,
        }, -- [2]
    },
}

do
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    local GetBestMapForUnit, EJ_GetInstanceForMap, EJ_GetNumTiers, GetInstanceInfo = C_Map.GetBestMapForUnit, EJ_GetInstanceForMap, EJ_GetNumTiers, GetInstanceInfo

    local function getCurrentInstanceParams()
        local mapID = GetBestMapForUnit("player")
        local instanceID = mapID and EJ_GetInstanceForMap(mapID) or 0
        local _, instanceType = GetInstanceInfo()
        local instance = ns:GetInstanceById(instanceID)
        if instance then
            local maxTiers = EJ_GetNumTiers()
            local params = {}
            if instance.tier ~= maxTiers then
                params[#params+1] = "legacy"
                params[#params+1] = tostring(instance.tier)
            end
            if instanceType == "dungeon" then
                params[#params+1] = "dungeons"
            end
            params[#params+1] = tostring(instanceID)
            return params
        end
    end

    function ta:SlashTA(option)
        if option == "test_transmit" then
            self:SendNote(testNote, "WHISPER", GetUnitName("player", true))
            return
        elseif option == "bw" then
            for i=1,GetNumAddOns() do
                local name = GetAddOnInfo(i)
                if name:sub(1, 7) == "BigWigs" then
                    local loaded = IsAddOnLoaded(i)
                    self:Print(name or "nil", loaded or "nil")
                end
            end
        end

        local params = getCurrentInstanceParams()
        if params then
            AceConfigDialog:SelectGroup("ToshAssignments", unpack(params))
        end
        AceConfigDialog:Open("ToshAssignments")
    end
end

do -- Add metatables/functions
    function ta:DecorateNote(note)
        for _, assign in pairs(note.assignments) do
            self:DecorateAssignment(assign)
        end
    end

    local defaultSpellConfig = {
        eventNumber = "*",
        before = 0,
    }

    local defaultTimeConfig = {
        encounterTime = 0,
    }

    function ta:DecorateAssignment(assignment)
        assignment.trigger.spell = setmetatable(assignment.trigger.spell or {}, {__index = defaultSpellConfig})
        assignment.trigger.time = setmetatable(assignment.trigger.time or {}, {__index = defaultTimeConfig})
        for _, action in pairs(assignment.actions) do
            self:DecorateAction(action)
        end
    end

    local defaultBarConfig = {
        duration = 10,
        icon = 'none',
    }

    local defaultMarkerConfig = {
        type = 'auto',
    }

    function ta:DecorateAction(action)
        action.bar = setmetatable(action.bar or {}, {__index = defaultBarConfig})
        action.marker = setmetatable(action.marker or {}, {__index = defaultMarkerConfig})
    end
end

ns.raidIconStrings = {
    [1] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t",
    [2] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t",
    [3] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t",
    [4] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t",
    [5] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t",
    [6] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t",
    [7] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",
    [8] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t",
}

ns.raidIconNumbers = {}
do
    for k,_ in pairs(ns.raidIconStrings) do
        -- Texture id list for raid icons 1-8 is 137001-137008
        ns.raidIconNumbers[k] = k+137000
    end
end

function ta:DumpNote(note)
    if ViragDevTool_AddData then ViragDevTool_AddData(note, note.name) end
end
