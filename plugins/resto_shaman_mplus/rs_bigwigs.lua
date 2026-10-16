local C = require("rs_settings")
local profiles=require("rs_encounters")
local M = {}
local function normalize(text)
    return type(text)=="string" and text:lower():gsub(" %(%d+%)$",""):gsub("^%s+",""):gsub("%s+$","") or ""
end
local function remaining(bar)
    if type(bar)~="table" or bar.paused==true or bar.is_paused==true
        or bar.stopped==true or bar.active==false then return nil end
    local left=tonumber(bar.remaining or bar.time_left or bar.timeLeft)
    if not left then
        local ending=tonumber(bar.ends_at or bar.end_time)
        if ending then left=ending-core.time() end
    end
    return left and left>0 and left or nil
end
local function matches(text, configured)
    text=normalize(text)
    for label in (configured or ""):gmatch("[^;]+") do
        if text == normalize(label) then return true end
    end
    return false
end
function M.scan()
    local result={party=false, personal=false, prepare=false,soon=false,warning=false}
    local context=require("rs_context").get()
    if not context.dungeon and context.mode~="delve" then C.timer="Dungeon timers inactive in this content";return result end
    if not C.get("bigwigs") then C.timer="Disabled"; return result end
    local bw=core.addons and core.addons.bigwigs
    if not bw or type(bw.is_loaded)~="function" then C.timer="API unavailable"; return result end
    local ok,loaded=pcall(bw.is_loaded)
    if not ok or not loaded then C.timer="Not loaded"; return result end
    local success,bars=pcall(bw.get_bars)
    if not success or type(bars)~="table" then C.timer="Timers unavailable"; return result end
    local nearest,actionable
    local profile={}
    if C.get("profiles") and core.get_instance_name then
        local ok,name=pcall(core.get_instance_name)
        if ok then profile=profiles[name] or {} end
    end
    for _,bar in pairs(bars) do
        local left=remaining(bar)
        if left and left>0 and type(bar.text)=="string" then
            if not nearest or left<nearest.remaining then nearest={text=bar.text,remaining=left} end
            local rule=profile[normalize(bar.text)]
            local configured=matches(bar.text,C.text("party_bars")) or matches(bar.text,C.text("self_bars"))
            if (rule or configured or bar.is_emphasized==true) and (not actionable or left<actionable.remaining) then
                actionable={text=bar.text,remaining=left}
            end
            if left<=C.get("lead") then
                local party=matches(bar.text,C.text("party_bars")) or (rule and rule.party)
                result.party=result.party or party or false
                result.personal=result.personal or matches(bar.text,C.text("self_bars")) or (rule and rule.personal) or false
                result.soon=result.soon or (party and left<=1.5) or false
                result.prepare=result.prepare or result.party
                    or (bar.is_emphasized==true and C.get("preheal"))
                result.warning=result.warning or result.party or result.personal
                    or (bar.is_emphasized==true and C.get("preheal"))
            end
        end
    end
    C.timer=nearest and string.format("%s (%.1fs)",nearest.text,nearest.remaining) or "Loaded, no active bars"
    local guidance=actionable or nearest
    if guidance then result.nearest_text=guidance.text;result.nearest_remaining=guidance.remaining end
    return result
end
return M
