local addonName, ns = ...
local ta = ns.ta
local encoder = ta.encoder

local tconc = table.concat

encoder.NP = encoder.NewType(1)

local v1 = {version=1}
function v1:encode(args)
    return self.version, tconc({
        args.guid or "",
        args.spellid or "",
        args.duration or "",
    }, ";")
end

function v1:decode(msg)
    local matcher = msg:gmatch("([^;]*);?")
    
    return self.version, {
        guid = matcher(),
        spellid = tonumber(matcher()),
        duration = tonumber(matcher()),
    }
end

encoder.NP[v1.version] = v1
