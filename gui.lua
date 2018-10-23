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
        b:SetFullWidth(true)
        return b
    end

    local GetSpellInfo = GetSpellInfo

    local function generalGroup(window, windowKey, note, assignment)
        local gen = gui:Create("SimpleGroup")
        gen:SetLayout("Flow")

        local name = gui:Create('EditBox')
        name:SetText(assignment.name)
        name:SetLabel("Name")
        name:SetFullWidth(true)
        name:SetCallback("OnEnterPressed", function(widget, event, text)
            if text ~= "" then
                assignment.name = text
                window:SetTitle(assignment.name)
                ta:NotifyConfigChange()
            end
        end)
        gen:AddChild(name)

        local delete = gui:Create("Button")
        delete:SetText("Delete")
        delete:SetCallback("OnClick", function(widget)
            note.assignments[assignment.id] = nil
            assignment.removeOptions()
            gui:Release(window)
            windows[windowKey] = nil
        end)
        gen:AddChild(delete)

        return gen
    end

    local function triggerGroup(note, assignment)
        local trigger = gui:Create("SimpleGroup")
        trigger:SetLayout("Flow")
        assignment.trigger = assignment.trigger or {}

        local ttype = gui:Create("Dropdown")
        ttype:SetLabel("Type")
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

        local spellsinputC = gui:Create('SimpleGroup')
        spellsinputC:SetLayout("fill")
        trigger:AddChild(spellsinputC)

        local function spellsinput()
            local si = gui:Create("EditBox")
            si:SetLabel("Spell Id")
            si:SetCallback("OnEnterPressed", function(widget, event, text)
                local n = tonumber(text)
                if n then
                    assignment.trigger.spellId = n
                end
            end)
            return si
        end

        spells:SetCallback("OnValueChanged", function(widget, event, key)
            if key == 0 then
                spellsinputC:AddChild(spellsinput())
            else
                assignment.trigger.spellId = key
                spellsinputC:ReleaseChildren()
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

        local timing = gui:Create("Slider")
        local timingBounds = {
            min=0,
            max=10,
        }
        timingBounds.set = function(value)
            timing:SetValue(value)
            while value > (0.8 * timingBounds.max) do
                timingBounds.max = math.ceil(1.5 * timingBounds.max)
            end
            timing:SetSliderValues(timingBounds.min, timingBounds.max, 0.1)
        end
        timingBounds.set(assignment.trigger.before or 0)
        timing:SetLabel("Seconds Before")
        timing:SetCallback("OnMouseUp", function(widget, event, value)
            assignment.trigger.before = value
            timingBounds.set(value)
        end)
        trigger:AddChild(timing)

        local 

        return trigger
    end

    local actionTypes = {
        marker = "Marker",
        bar = "Bar",
    }
    
    local function markerActionGroup(note, assignment, action)
    end

    local function barActionGroup(note, assignment, action)
    end
    
    local function actionGroup(note, assignment, action)
        local a = gui:Create("DropdownGroup")
        a:SetLayout("Fill")
        a:SetTitle("Type")
        a:SetGroupList(actionTypes)

        a:SetCallback("OnGroupSelected", function(widget, event, group)
            tab:ReleaseChildren()
            if group == 'marker' then
                a:AddChild(markerActionGroup(note, assignment, action))
            elseif group == 'bar' then
                a:AddChild(barActionGroup(note, assignment, action))
            end
        end)
        a:SetGroup('marker')

        return a
    end

    local function actionTreeGroup(note, assignment)
        local t = gui:Create("TreeGroup")
        t:SetFullWidth(true)
        t:SetFullHeight(true)
        t:SetLayout("Fill")

        local tree = {}
        local actionMap = {}
        for k, action in pairs(assignment.actions) do
            local value = "action"..action.id
            tree[#tree+1] = {
                value = value,
                text = "Action "..action.id,
            }
            actionMap[value] = action
        end
        tree[#tree+1] = {
            value = "add",
            text = "Add Action",
        }
        t:SetTree(tree)

        t:SetCallback("OnGroupSelected", function(widget, event, group)
            if not group then
                return
            elseif group == "add" then
                local action = {
                    id = (#assignment.actions + 1),
                }
                assignment.actions[action.id] = action
                local value = "action"..action.id
                table.insert(tree, #tree, {
                    value = value,
                    text = "Action "..action.id,
                })
                actionMap[value] = action
                t:SelectByValue("")
            else
                local action = actionMap[group]
                if not action then return end
                t:ReleaseChildren()
                t:AddChild(actionGroup(note, assignment, action))
            end
        end)

        return t
    end

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

        local tab = gui:Create('TabGroup')
        tab:SetFullWidth(true)
        tab:SetFullHeight(true)
        tab:SetTabs({
            {value = 'general', text = 'General'},
            {value = 'trigger', text = 'Trigger'},
            {value = 'actions', text = 'Actions'},
        })

        tab:SetCallback("OnGroupSelected", function(widget, event, group)
            tab:ReleaseChildren()
            if group == 'general' then
                tab:AddChild(generalGroup(w, windowKey, note, assignment))
            elseif group == 'trigger' then
                tab:AddChild(triggerGroup(note, assignment))
            elseif group == 'actions' then
                tab:AddChild(actionTreeGroup(note, assignment))
            end
        end)
        tab:SelectTab('general')

        w:AddChild(tab)

        w:Show()
        return w
    end
end
