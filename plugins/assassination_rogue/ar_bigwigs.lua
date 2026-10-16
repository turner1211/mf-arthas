-- Host bridge used by the existing Shaman and Guardian plugins.
-- Match exact configured mechanic names / keys; never infer spell school from a label.
local M={status="Waiting for BigWigs",rules=require("ar_encounters")}
local discovered={}
local function read(fn,...)
 if type(fn)~="function" then return nil end
 local ok,v=pcall(fn,...);if ok then return v end
end
local function clean_label(value)
 if type(value)~='string' then return value end
 return (value:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('^%s+',''):gsub('%s+$',''))
end
function M.scan(enabled,lead,pvp)
 if not enabled then M.status="BigWigs disabled";return end
 if pvp then M.status="PvP: focus / cast prediction active";return end
 local addons=core.addons or {}
 local sources={}
 local function add_source(name,bridge,spell_keys)
  if not bridge or read(bridge.is_loaded)~=true then return end
  if type(bridge.has_active_bars)=='function' and read(bridge.has_active_bars)==false then return end
  local rows=read(bridge.get_bars)
  if type(rows)=='table' then sources[#sources+1]={name=name,bars=rows,spell_keys=spell_keys} end
 end
 add_source('BigWigs',addons.bigwigs,false)
 add_source('ExBoss',addons.exboss,true)
 if #sources==0 then M.status="BigWigs / ExBoss unavailable or no active bars";return end
 local instance=read(core.get_instance_name) or "*"
 local rules=M.rules[instance] or M.rules["*"] or {}
 local nearest,selected
 local source_names={}
 for _,source in ipairs(sources) do
 source_names[#source_names+1]=source.name
 for _,bar in pairs(source.bars) do
  if type(bar)=="table" and type(bar.remaining)=="number" and bar.remaining>=0 then
   if not nearest or bar.remaining<nearest.remaining then nearest=bar end
   local label=clean_label(bar.text)
   local rule=(source.spell_keys and rules[tonumber(bar.key)]) or rules[bar.text] or rules[label]
   if not rule and bar.is_emphasized==true then
    rule={kind="unknown"}
    local signature=tostring(instance)..':'..tostring(bar.key or bar.text)
    if not discovered[signature] then
     discovered[signature]=true;M.new_discovery={instance=instance,key=bar.key,text=bar.text}
    end
   end
   if rule and bar.remaining<=lead and (rule.kind=="aoe" or rule.kind=="magic" or rule.kind=="physical" or rule.kind=="unknown") then
    if not selected or bar.remaining<selected.remaining then
     selected={text=label or tostring(bar.key),remaining=bar.remaining,kind=rule.kind,
      targeted=rule.targeted==true,key=bar.key,radius=tonumber(rule.radius),center=rule.center}
    end
   end
  end end
 end
 M.status=nearest and string.format("%s: %s / %.1fs",table.concat(source_names,'+'),tostring(nearest.text or nearest.key),nearest.remaining) or table.concat(source_names,'+')..": no active bars"
 return selected
end
function M.take_discovery() local row=M.new_discovery;M.new_discovery=nil;return row end
return M
