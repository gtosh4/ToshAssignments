local _, ns = ...
local ta = ns.ta

local protocolVersion = 1
local commPrefix = "ToshAssign"..protocolVersion

function ta:SetupSharing()
    ta:RegisterComm(commPrefix)
end

do
    local LibDeflate = LibStub("LibDeflate")
    local configForDeflate = {level = 9} -- Taken from WeakAura because "the biggest bottleneck by far is in transmission and printing; so use maximal compression"
    local LibSerialize = LibStub("AceSerializer-3.0")

    local gui = LibStub("AceGUI-3.0")
    local windows = {}

    local function ReceiveNote(self, note, channel, sender)
        local old = self.db.profile.encounters[note.encounterId][note.name]

        local w = windows[note.name]
        if w then
            gui:SetFocus(w)
            return
        end
        w = gui:Create('DialogFrame')
        w:SetWidth(400)
        w:SetHeight(200)
        w:SetLayout("List")
        w:SetTitle(note.name)
        w:SetOkayText("Import")
        w:SetCancelText("Cancel")
        w:SetCallback("OnClose", function(widget)
            gui:Release(widget)
            windows[note.name] = nil
        end)
        w:SetCallback("OnClick", function(widget, event, okay)
            if okay == true then
                self.db.profile.encounters[note.encounterId][note.name] = note
                self:InitializeOptions(true)
            end
        end)
        windows[note.name] = w

        local desc = gui:Create('Label')
        desc:SetFullWidth(true)
        local encounterName = EJ_GetEncounterInfo(note.encounterId)
        local replaceTxt
        if old ~= nil then
            replaceTxt = "update (replace) your"
        else
            replaceTxt = "send you"
        end
        desc:SetText(string.format(
            "%s would like to %s note %s for encounter %s",
            sender,
            replaceTxt,
            note.name,
            encounterName
        ))
        w:AddChild(desc)

        local assignGroup = gui:Create('InlineGroup')
        assignGroup:SetFullWidth(true)
        assignGroup:SetFullHeight(true)
        assignGroup:SetLayout("Fill")
        assignGroup:SetTitle("Assignments")
        w:AddChild(assignGroup)

        local assignScroll = gui:Create('ScrollFrame')
        assignGroup:AddChild(assignScroll)

        local assigns = gui:Create('Label')
        local txt
        for _, assign in pairs(note.assignments) do
            if not txt then
                txt = assign.name
            else
                txt = txt .. "|n" .. assign.name
            end
        end
        assigns:SetText(txt)
        assignScroll:AddChild(assigns)

        w:Show()
        return w
    end

    function ta:OnCommReceived(prefix, data, channel, sender)
        if prefix ~= commPrefix then return end

        local decoded = LibDeflate:DecodeForWoWAddonChannel(data)
        local decompressed = LibDeflate:DecompressDeflate(decoded)
        local success, deserialized = LibSerialize:Deserialize(decompressed)
        if not success then
            error("Error deserializing "..deserialized)
            return
        end

        ReceiveNote(self, deserialized, channel, sender)
    end

    local function SanitizeForSerialize(v)
        local t=type(v)
        
        if t=="string" then
            return v
        
        elseif t=="number" then
            return v
        
        elseif t=="table" then
            local cloned = {}
            for k,v in pairs(v) do
                k = SanitizeForSerialize(k)
                v = SanitizeForSerialize(v)
                if k ~= nil and v ~= nil then
                    cloned[k] = v
                end
            end
            return cloned
        
        elseif t=="boolean" then
            return v
        
        elseif t=="nil" then
            return v
        end
        return nil
    end

    function ta:SendNote(note, channel, target)
        if not channel then
            if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
                channel = "INSTANCE_CHAT"
            elseif IsInRaid() then
                channel = "RAID"
            elseif IsInGroup() then
                channel = "PARTY"
            end
        end
    
        if not channel then return end

        local serialized = LibSerialize:Serialize(SanitizeForSerialize(note))
        local compressed = LibDeflate:CompressDeflate(serialized, configForDeflate)
        local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
        
	    self:SendCommMessage(commPrefix, encoded, channel, target, "NORMAL")
    end

    local shareW
    function ta:ShareNote(note)
        if shareW then shareW:Release() end
        shareW = gui:Create('DialogFrame')
        shareW:SetWidth(400)
        shareW:SetHeight(200)
        shareW:SetTitle(note.name)
        shareW:SetOkayText("Share")

        local withValue
        local with = gui:Create('Dropdown')
        with:SetLabel("Share with...")
        with:SetList({
            group = "Group",
            player = "Player"
        })
        shareW:AddChild(with)

        local withTargetVal
        local withTarget = gui:Create("EditBox")
        withTarget:SetCallback("OnEnterPressed", function(widget, event, text)
            withTargetVal = text
        end)
        shareW:AddChild(withTarget)

        with:SetCallback("OnValueChanged", function(widget, event, value)
            withValue = value
            if value == 'player' then
                withTarget:SetDisabled(false)
            else
                withTarget:SetDisabled(true)
            end
        end)
        with:SetValue("group")

        shareW:SetCallback("OnClick", function(widget, event, okay)
            if okay == true then
                if withValue == "group" then
                    self:SendNote(note)
                elseif withValue == "player" then
                    self:SendNote(note, "WHISPER", withTargetVal)
                end
            end
        end)

        shareW:Show()
        return shareW
    end
end
