local _, ns = ...
local ta = ns.ta

do
    local EJ_GetEncounterInfoByIndex, EJ_GetCurrentTier, EJ_SelectInstance, EJ_SelectTier, EJ_GetTierInfo, EJ_GetInstanceByIndex =
          EJ_GetEncounterInfoByIndex, EJ_GetCurrentTier, EJ_SelectInstance, EJ_SelectTier, EJ_GetTierInfo, EJ_GetInstanceByIndex

    local encounterById = {}

    local function encounters(instanceId)
        EJ_SelectInstance(instanceId)
        
        local es = {}
        
        local index = 1
        while true do
            local info = { EJ_GetEncounterInfoByIndex(index, instanceId) }
            if not info[1] then break end
            local encounter = encounterById[info[3]] or {
                name = info[1],
                desc = info[2],
                encounterId = info[3],
                rootSectionID = info[4],
                link = info[5],
            }
            encounter.instanceId = instanceId
            es[index] = encounter
            encounterById[encounter.encounterId] = encounterById[encounter.encounterId] or encounter
            index = index + 1
        end

        return es
    end

    local instancesById = {} -- Useful for finding out which instance we're currently in

    local function instances(tier, isRaid)
        local instances = {}
        local index = 1
        while true do
            local info = { EJ_GetInstanceByIndex(index, isRaid) }
            if not info[1] then break end
            local instance = {
                instanceId = info[1],
                name = info[2],
                desc = info[3],
                mapId = info[7],
                link = info[8],
                tier = tier,
            }
            instance.encounters = encounters(instance.instanceId)
            instances[index] = instance
            instancesById[instance.instanceId] = instance
            index = index + 1
        end
        return instances
    end

    local tiers = {}
        
    function ns:GetTier(index)
        local tier = tiers[index]
        if not tier then
            local info = { EJ_GetTierInfo(index) }
            if not info[1] then return end
            tier = {
                index = index,
                name = info[1],
                link = info[2],
            }
            tiers[index] = tier
            
            local old = EJ_GetCurrentTier()
            EJ_SelectTier(index)
            tier.dungeons = instances(index, false)
            tier.raids = instances(index, true)
            if old then
                EJ_SelectTier(old)
            end
        end
        return tier
    end

    function ns:LoadEncounters()
        for i=1,EJ_GetNumTiers() do
            self:GetTier(i)
        end
    end

    function ns:GetInstanceById(id)
        return instancesById[id]
    end

    function ns:GetEncounterById(id)
        local encounter = encounterById[id]
        if not encounter then
            local info = { EJ_GetEncounterInfo(id) }
            if info[1] then
                encounter = {
                    name = info[1],
                    desc = info[2],
                    encounterId = info[3],
                    rootSectionID = info[4],
                    link = info[5],
                }
                encounterById[encounter.encounterId] = encounterById[encounter.encounterId] or encounter
            end
        end
        return encounter
    end
end
