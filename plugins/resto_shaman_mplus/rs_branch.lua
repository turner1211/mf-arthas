local M={last=nil,checked_at=-math.huge}
local function call(owner,name,...)
    local fn=owner and owner[name]
    if type(fn)~="function" then return nil end
    local ok,value=pcall(fn,...)
    if ok then return value end
end
local function known(id)
    return call(core.spell_book,"is_spell_known",id)==true
end
local function version_text()
    local values={
        call(core,"get_game_version"),call(core,"get_client_version"),
        call(core,"get_build_info"),call(core.game,"get_version"),
        call(core.game,"get_build_info")}
    local out={}
    for _,value in pairs(values) do
        if type(value)=="table" then
            for _,v in pairs(value) do out[#out+1]=tostring(v) end
        elseif value~=nil then out[#out+1]=tostring(value) end
    end
    return table.concat(out," "):lower()
end
local function talent_names()
    local names={}
    local list=call(core.game_ui,"get_active_talents")
    if type(list)=="table" then
        for _,talent in pairs(list) do
            if (tonumber(talent.rank) or 0)>0 and talent.name then names[tostring(talent.name):lower()]=true end
        end
    end
    return names
end
local function has_name(names,needle)
    needle=needle:lower()
    for name in pairs(names) do if name:find(needle,1,true) then return true end end
    return false
end
function M.detect()
    local now=type(core.time)=="function" and core.time() or 0
    if M.last and now-M.checked_at<1 then return M.last end
    M.checked_at=now
    local raw=call(core.spell_book,"get_specialization_id")
    local text=version_text()
    local forever=text:find("forever",1,true)~=nil or text:find("1.60.",1,true)~=nil
    if not forever and raw==nil and require("rs_settings").get("forever_auto_detect") then
        -- Spellbook fingerprints are a fallback only. Avoid DB2-backed spell
        -- probes while the client is still publishing a Retail spec ID.
        local retail_fingerprint=known(444995) or known(452201) or known(191634) or known(192058)
        local forever_fingerprint=known(66842) or known(408341) or known(408490) or known(408510) or known(408521)
        forever=forever_fingerprint and not retail_fingerprint
    end
    local names=talent_names()
    local spec
    if forever then
        if has_name(names,"riptide") or has_name(names,"mana tide") or has_name(names,"water shield") or known(408521) then spec="restoration"
        elseif has_name(names,"maelstrom weapon") or has_name(names,"mental quickness") or has_name(names,"rage of the farseer") or known(425336) then spec="enhancement"
        elseif has_name(names,"lava burst") or has_name(names,"lightning overload") or known(408490) then spec="elemental"
        else
            local override=tonumber(require("rs_settings").get("forever_tree")) or 0
            spec=({[1]="elemental",[2]="enhancement",[3]="restoration"})[override] or "elemental"
        end
    else
        spec=({[1]="elemental",[262]="elemental",[2]="enhancement",[263]="enhancement",[3]="restoration",[264]="restoration"})[raw]
    end
    M.last={family=forever and "forever" or "retail",spec=spec or "unknown",raw_spec=raw,
        version=text~="" and text or "version API unavailable",evidence=forever and (text~="" and text or "Forever spell fingerprint") or "Retail specialization/API"}
    return M.last
end
function M.label()
    local value=M.last or M.detect()
    return (value.family=="forever" and "WoW Forever" or "Retail / Midnight").." • "..value.spec:gsub("^%l",string.upper)
end
return M
