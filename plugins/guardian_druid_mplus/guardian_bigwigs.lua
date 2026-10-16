local Settings=require("guardian_settings")
local EncounterData=require("guardian_encounter_data")
local M={status="BigWigs not loaded",next=nil}
local generation=_G.__guardian_runtime_generation
local next_update=0
local TANK_WORDS={"tank","strike","smash","slam","crush","cleave","bite","claw","chop",
    "impale","sunder","maul","heavy","brutal","savage","mortal","buster"}
local PARTY_WORDS={"roar","nova","stomp","blast","eruption","upheaval","pulse","storm",
    "inferno","rattle","ritual","volley","howl","shout"}
local VERIFIED={{1295453,"infernal crush","party",1,"magic"},{473898,"legion strike","tank",2,"physical"}}
local MECHANICS={}
for _,boss in ipairs(EncounterData.bosses or {}) do
    for spell,mechanic in pairs(boss.mechanics or {}) do
        local previous=MECHANICS[spell]
        -- Conflicting classifications cannot establish a defensive job.
        MECHANICS[spell]=previous and previous~=mechanic.kind and "unknown" or mechanic.kind
    end
end
local function classify(text,key)
    text=tostring(text or ""):lower()
    for _,entry in ipairs(VERIFIED) do
        if tonumber(key)==entry[1] then return entry[3],entry[4],entry[5] end
    end
    local kind=MECHANICS[tonumber(key)]
    if kind then
        local school="unknown"
        if core.spell_book.get_spell_school then
            local ok,value=pcall(core.spell_book.get_spell_school,tonumber(key))
            value=ok and tonumber(value) or nil
            if value==1 then school="physical" elseif value and value>1 and value<=127 then school="magic" end
        end
        if kind=="tank" then return "tank",2,school end
        if kind=="party" then return "party",1,school end
        -- A known movement, spread, interrupt or phase mechanic must not
        -- become a tank buster merely because its localized label sounds so.
        return "unknown",1,"unknown"
    end
    for _,entry in ipairs(VERIFIED) do
        local name=entry[2]
        if core.spell_book.get_spell_name then
            local ok,value=pcall(core.spell_book.get_spell_name,entry[1])
            if ok and type(value)=="string" and #value>0 and text:find(value:lower(),1,true) then
                return entry[3],entry[4],entry[5]
            end
        end
        if text:find(name,1,true) then return entry[3],entry[4],entry[5] end
    end
    for _,word in ipairs(TANK_WORDS) do if text:find(word,1,true) then return "tank",2,"unknown" end end
    for _,word in ipairs(PARTY_WORDS) do if text:find(word,1,true) then return "party",1,"unknown" end end
    return "unknown",1,"unknown"
end

function M.scan(window)
    M.next=nil
    if not Settings.on("bigwigs_defensives") then M.status="Off"; return nil end
    local bigwigs=core.addons and core.addons.bigwigs or nil
    if not bigwigs then M.status="BigWigs API unavailable"; return nil end
    local loaded_ok,loaded=pcall(bigwigs.is_loaded)
    if not loaded_ok or not loaded then M.status="BigWigs not loaded"; return nil end
    local active_ok,active=pcall(bigwigs.has_active_bars)
    if active_ok and not active then M.status="Loaded - no active bars"; return nil end
    local bars_ok,bars=pcall(bigwigs.get_bars)
    if not bars_ok or type(bars)~="table" then M.status="Timer data unavailable"; return nil end
    local earliest,relevant
    local relevant_count,relevant_seen=0,{}
    for _,bar in pairs(bars) do
        local remaining=tonumber(bar.remaining)
        if remaining and remaining>=0 and bar.is_emphasized==true then
            local text=tostring(bar.text or "Upcoming mechanic")
            local kind,severity,school=classify(text,bar.key)
            local candidate={key=bar.key,text=text,remaining=remaining,duration=tonumber(bar.duration),
                is_emphasized=true,kind=kind,severity=severity,school=school}
            if not earliest or remaining<earliest.remaining then earliest=candidate end
            if kind~="unknown" and remaining<=window then
                local identity=bar.key~=nil and ("id:"..tostring(bar.key)) or ("text:"..text:lower())
                if not relevant_seen[identity] then relevant_seen[identity]=true; relevant_count=relevant_count+1 end
                -- Tank preparation must not be masked by a slightly earlier party bar.
                if not relevant or kind=="tank" and relevant.kind~="tank"
                    or kind==relevant.kind and remaining<relevant.remaining then relevant=candidate end
            end
        end
    end
    if relevant then relevant.overlap_count=relevant_count end
    M.next=earliest
    if earliest then
        M.status=string.format("%s in %.1fs",earliest.text,earliest.remaining)
    else M.status="Loaded - no emphasized timer" end
    -- Emphasis is presentation urgency, not proof that a mechanic deals damage.
    -- Unknown timers remain in the UI but cannot consume defensive cooldowns.
    return relevant and relevant.remaining<=window and relevant or nil
end

function M.update_status()
    local now=core.time()
    if now<next_update then return end
    next_update=now+0.2
    local ok,err=pcall(M.scan,Settings.value("bigwigs_lead"))
    if not ok then M.status="BigWigs error: "..tostring(err); M.next=nil end
    Settings.bigwigs_status=M.status
end
core.register_on_update_callback(function() if _G.__guardian_runtime_generation==generation then M.update_status() end end)
return M
