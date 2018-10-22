local _, ns = ...
local ta = ns.ta

do
    local gui = LibStub("AceGUI-3.0")

    local triggerTypes = {
        time = 'Time',
        cast = 'Cast',
        aura = 'Aura',
        add = 'Add',
    }

    local windows = {}

    local function sectionBreak()
        local b = gui:Create("Label")
        b:SetRelativeWidth(1.0)
        return b
    end

    local GetSpellInfo = GetSpellInfo

    function ta:ShowAssignment(note, assignment)
        local windowKey = note.name .. "_" .. assignment.id
        local w = windows[windowKey]
        if w then
            gui:SetFocus(w)
            return
        end
        w = gui:Create('Frame')
        w:SetLayout("Flow")
        w:SetTitle(assignment.name)
        w:SetCallback("OnClose", function(widget)
            gui:Release(widget)
            windows[windowKey] = nil
        end)
        windows[windowKey] = w

        local name = gui:Create('EditBox')
        name:SetText(assignment.name)
        name:SetRelativeWidth(1.0)
        name:SetCallback("OnEnterPressed", function(widget, event, text)
            if text ~= "" then
                assignment.name = text
                w:SetTitle(assignment.name)
                ta:NotifyConfigChange()
            end
        end)
        w:AddChild(name)

        local delete = gui:Create("Button")
        delete:SetText("Delete")
        delete:SetCallback("OnClick", function(widget)
            note.assignments[assignment.id] = nil
            assignment.removeOptions()
            gui:Release(w)
            windows[windowKey] = nil
        end)
        w:AddChild(delete)

        w:AddChild(sectionBreak())

        local trigger = gui:Create("SimpleGroup")
        trigger:SetLayout("Flow")
        w:AddChild(trigger)
        assignment.trigger = assignment.trigger or {}

        local ttype = gui:Create("Dropdown")
        ttype:SetLabel("Trigger Type")
        ttype:SetList(triggerTypes)
        trigger:AddChild(ttype)

        local spellList = {}
        for _, i in ipairs(ns.encounterSpells[note.encounterId] or {}) do
            local name, _, icon = GetSpellInfo(i)
            spellList[i] = "|T"..icon..":0|t"..name
        end
        local spells = gui:Create("Dropdown")
        spells:SetList(spellList)
        spells:AddItem(0, "Manual")
        spells:SetDisabled(true)
        trigger:AddChild(spells)

        local spellsinput = gui:Create("EditBox")
        spellsinput:SetLabel("Spell Id")
        trigger:AddChild(spellsinput)
        spellsinput:SetDisabled(true)
        spellsinput:SetCallback("OnEnterPressed", function(widget, event, text)
            local n = tonumber(text)
            if n then
                assignment.trigger.spellId = n
            end
        end)

        spells:SetCallback("OnValueChanged", function(widget, event, key)
            if key == 0 then
                spellsinput:SetDisabled(false)
            else
                assignment.trigger.spellId = key
                spellsinput:SetDisabled(true)
            end
        end)

        ttype:SetCallback("OnValueChanged", function(widget, event, key)
            if key == 'cast' or key == 'aura' then
                spells:SetDisabled(false)
            else
                spells:SetDisabled(true)
            end
            assignment.trigger.type = key
        end)

        ttype:SetValue(assignment.trigger.type)
        if assignment.trigger.type == 'cast' or assignment.trigger.type == 'aura' then
            spells:SetDisabled(false)

            if assignment.trigger.spellId then
                if spellList[assignment.trigger.spellId] then
                    spells:SetValue(assignment.trigger.spellId)
                else
                    spells:SetValue(0)
                    spellsinput:SetDisabled(false)
                    spellsinput:SetText(tostring(assignment.trigger.spellId))
                end
            end
        end
        
        w:Show()
        return w
    end
end
