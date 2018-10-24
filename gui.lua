local _, ns = ...
local ta = ns.ta

do
    local gui = LibStub("AceGUI-3.0")

    local triggerTypes = {
        time = 'Time',
        spell = 'Spell',
        add = 'Add',
    }

    local windows = {}

    local function sectionBreak()
        local b = gui:Create("Label")
        b:SetFullWidth(true)
        return b
    end

    local function dynamicSlider()
        local s = gui:Create("Slider")
        s._SetValue = s.SetValue
        function s:SetValuefunction(value)
            local m = self.max
            while value > (0.8 * m) do
                m = math.ceil(1.5 * m)
            end
            self:SetSliderValues(self.min, m, self.step)
            self:_SetValue(value)
        end
        s._OnRelease = s.OnRelease
        function s:OnRelease()
            s.SetValue, s._SetValue = s._SetValue, nil
            s.OnRelease, s._OnRelease = s._OnRelease, nil
            if s.OnRelease then s.OnRelease() end
        end

        return s
    end

    local GetSpellInfo = GetSpellInfo

    local function generalGroup(window, note, assignment)
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
            window:Hide()
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

        local spellsinputC = gui:Create('FlipContainer')
        spellsinputC:SetLayout("Flow")
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
            if key == 'spell' then
                spells:SetDisabled(false)
            else
                spells:SetDisabled(true)
            end
            assignment.trigger.type = key
        end)

        ttype:SetValue(assignment.trigger.type)
        if assignment.trigger.type == 'spell' then
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

        trigger:AddChild(sectionBreak())

        local timing = dynamicSlider()
        timing:SetValue(assignment.trigger.before or 0)
        timing:SetLabel("Seconds Before")
        timing:SetCallback("OnMouseUp", function(widget, event, value)
            assignment.trigger.before = value
        end)
        trigger:AddChild(timing)

        return trigger
    end

    local actionTypes = {
        bar = "Bar",
        marker = "Marker",
    }
    
    local function actionGroup(note, assignment)
        local a = gui:Create("DropdownGroup")
        a:SetLayout("Fill")
        a:SetTitle("Type")
        a:SetGroupList(actionTypes)

        local container = gui:Create("SimpleGroup")
        container:SetLayout("Flow")
        a:AddChild(container)

        local delete = gui:Create("Button")
        delete:SetText("Delete")
        delete:SetCallback("OnClick", function(widget)
            local action = a:GetUserData("action")
            if not action then
                return
            end
            assignment.actions[action.id] = nil
            action.removeOptions()
        end)
        container:AddChild(delete)

        local flip = gui:Create('FlipContainer')
        flip:SetFullWidth(true)
        flip:SetFullHeight(true)
        container:AddChild(flip)
        
        local bar = gui:Create("SimpleGroup")
        bar:SetLayout("Flow")
        flip:AddPage('bar', bar)

        local barDuration = dynamicSlider()
        barDuration:SetLabel("Duration")
        barDuration:SetCallback("OnMouseUp", function(widget, event, value)
            local action = a:GetUserData("action")
            if not action then
                return
            end
            action.bar.duration = value
        end)
        bar:AddChild(barDuration)

        local marker = gui:Create("SimpleGroup")
        marker:SetLayout("Flow")
        flip:AddPage('marker', marker)
        
        a:SetCallback("OnGroupSelected", function(widget, event, group)
            if not group or group == "" then
                flip:Hide()
                return
            end
            local action = widget:GetUserData("action")
            if not action then
                flip:Hide()
                return
            end

            flip:ShowPage(group)
            action.type = group

            ta:DecorateAction(action)
            barDuration:SetSliderValues(0, 30, 0.1)
            barDuration:SetValue(action.bar.duration)
        end)
        a:SetGroup('bar')

        a.SetAction = function(self, action)
            self:SetUserData("action", action)

            if not action.type then
                action.type = 'bar'
            end
            a:SetGroup(action.type)
        end

        return a
    end

    local function actionTreeGroup(note, assignment)
        local t = gui:Create("TreeGroup")
        t:SetLayout("Fill")

        local tree = {}
        local actionMap = {}
        for k, action in pairs(assignment.actions) do
            local value = "action"..action.id
            local idx = #tree+1
            tree[idx] = {
                value = value,
                text = "Action "..action.id,
            }
            actionMap[value] = action
            action.removeOptions = function()
                table.remove(tree, idx)
                actionMap[value] = nil
                t:RefreshTree()
            end
        end
        tree[#tree+1] = {
            value = "add",
            text = "Add Action",
        }
        t:SetTree(tree)

        local content = actionGroup(note, assignment)
        t:AddChild(content)

        t:SetCallback("OnGroupSelected", function(widget, event, group)
            if not group then
                return
            elseif group == "add" then
                local action = {
                    id = (#assignment.actions + 1),
                }
                assignment.actions[action.id] = action
                local value = "action"..action.id
                local idx = #tree
                table.insert(tree, idx, {
                    value = value,
                    text = "Action "..action.id,
                })
                actionMap[value] = action
                action.removeOptions = function()
                    table.remove(tree, idx)
                    actionMap[value] = nil
                    t:RefreshTree()
                end
                t:SelectByValue(value)
            else
                local action = actionMap[group]
                if not action then return end
                content:SetAction(action)
            end
        end)
        if tree[1] then
            t:SelectByValue(tree[1].value)
        else
            content:SetGroup()
        end

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
        w:SetLayout("Fill")
        w:SetTitle(assignment.name)
        w:SetCallback("OnClose", function(widget)
            gui:Release(widget)
            windows[windowKey] = nil
        end)
        windows[windowKey] = w

        local tab = gui:Create('TabGroup')
        tab:SetLayout("fill")
        tab:SetTabs({
            {value = 'general', text = 'General'},
            {value = 'trigger', text = 'Trigger'},
            {value = 'actions', text = 'Actions'},
        })

        local flip = gui:Create('FlipContainer')
        flip:SetLayout("Fill")
        tab:AddChild(flip)

        flip:AddPage('general', generalGroup(w, note, assignment))
        flip:AddPage('trigger', triggerGroup(note, assignment))
        flip:AddPage('actions', actionTreeGroup(note, assignment))

        tab:SetCallback("OnGroupSelected", function(widget, event, group)
            flip:ShowPage(group)
        end)
        tab:SelectTab('general')

        w:AddChild(tab)

        w:Show()
        return w
    end
end
