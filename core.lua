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
        
        ta:RegisterMessage("ToshAssignments_UpdateConfig", function() ta:InitializeOptions(true) end)
		self.db.RegisterCallback(ta, "OnProfileChanged", profileUpdate)
		self.db.RegisterCallback(ta, "OnProfileCopied", profileUpdate)
		self.db.RegisterCallback(ta, "OnProfileReset", profileUpdate)

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

function ta:SlashTA()
    LibStub("AceConfigDialog-3.0"):Open("ToshAssignments")
end

-- Boss Mod functions
