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
    LibStub("AceConfigDialog-3.0"):Open("ToshAssignments")
end

do -- Add metatables/functions
    function ta:DecorateNote(note)
        for _, assign in pairs(note.assignments) do
            self:DecorateAssignment(assign)
        end
    end

    function ta:DecorateAssignment(assignment)
        if assignment.trigger.type == 'cast' or assignment.trigger.type == 'aura' then
            assignment.trigger.type = 'spell'
        end
        for _, action in pairs(assignment.actions) do
            self:DecorateAction(action)
        end
    end

    local defaultBarConfig = {
        duration = 10
    }

    function ta:DecorateAction(action)
        action.bar = setmetatable(action.bar or {}, {__index = defaultBarConfig})
    end
end

-- Boss Mod functions
