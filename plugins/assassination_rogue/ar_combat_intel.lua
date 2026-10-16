-- Persistent opponent memory and per-tick tactical recommendations.
local S=require('ar_spells')
local M={}
local memory={}
local trinkets={[42292]=true,[336126]=true}
local fixed_cc_breaks={[59752]=90,[336135]=60,[336145]=60}
local bleed_cleanses={[20594]=120,[265221]=120}
local targeted_bleed_removals={[374251]=0,[212640]=0,[1022]=10}
local self_bleed_removals={[20594]=0,[265221]=0,[642]=8,[45438]=10}
local bleed_cleanse_races={[3]=true,[34]=true,dwarf=true,['dark iron dwarf']=true,darkirondwarf=true}
-- Major healer externals are remembered on their actual recipient.  Cast
-- callbacks are more dependable than protected aura reads on hostile players.
local externals={
 [33206]=8,  -- Pain Suppression
 [102342]=12,-- Ironbark
 [6940]=12,  -- Blessing of Sacrifice
 [116849]=12,-- Life Cocoon
 [47788]=10, -- Guardian Spirit
 [357170]=8, -- Time Dilation
 [1022]=10,  -- Blessing of Protection
}
local defensives={
 [642]=8,[45438]=10,[186265]=3,[31224]=5,[5277]=10,[22812]=12,[871]=8,[48792]=8,[61336]=6,
 [196555]=6, -- Netherwalk
 [47585]=6,  -- Dispersion
 [118038]=8, -- Die by the Sword
 [122278]=10,-- Dampen Harm
 [122783]=6, -- Diffuse Magic
 [104773]=8, -- Unending Resolve
 [108271]=8, -- Astral Shift
 [363916]=8, -- Obsidian Scales
 [48707]=5,  -- Anti-Magic Shell
 [198589]=10,-- Blur
 [122470]=10,-- Touch of Karma
 [115203]=15,-- Fortifying Brew
}
local mobility={[1953]=2,[212653]=2,[190784]=4,[100]=4,[6544]=4,[48265]=4,[1044]=8,[2983]=8}
local bursts={[1719]=12,[51271]=12,[31884]=20,[13750]=20,[107574]=20,[12472]=20,[190319]=10,[360194]=16}
local function key(u,guid)
 if not u then return nil end
 if type(guid)=='function' then return tostring(guid(u)) end
 if type(u.get_guid)=='function' then local ok,v=pcall(u.get_guid,u);if ok and v~=nil then return tostring(v) end end
 return nil
end
function M.reset() memory={} end
function M.observe_spell(data,n,guid,is_enemy)
 if type(data)~='table' or not data.caster or not is_enemy(data.caster) then return end
 local id=tonumber(data.spell_id);if not id then return end
 local k=key(data.caster,guid);if not k then return end
 local row=memory[k] or {};memory[k]=row
 if trinkets[id] then
  row.trinket_used=n;row.trinket_ready=n+120;row.trinket_fixed_ready=nil;row.trinket_kind='Medallion'
 end
 if fixed_cc_breaks[id] then
  row.trinket_used=n;row.trinket_fixed_ready=n+fixed_cc_breaks[id]
  row.trinket_kind=id==59752 and 'Will to Survive' or 'Adaptation'
 end
 if bleed_cleanses[id] then row.bleed_cleanse_used=n;row.bleed_cleanse_ready=n+bleed_cleanses[id] end
 if defensives[id] then row.defensive_until=n+defensives[id] end
 if mobility[id] then row.mobility_until=n+mobility[id];row.mobility_used=n end
 if bursts[id] then row.burst_until=n+bursts[id] end
 row.last_spell=id;row.last_seen=n
 local removal_delay=targeted_bleed_removals[id]
 local cleaned_unit=removal_delay~=nil and data.target or self_bleed_removals[id]~=nil and data.caster or nil
 if cleaned_unit and is_enemy(cleaned_unit) then
  removal_delay=removal_delay or self_bleed_removals[id]
  local cleaned_key=key(cleaned_unit,guid)
  if cleaned_key then
   local cleaned=memory[cleaned_key] or {};memory[cleaned_key]=cleaned
   cleaned.bleeds_removed_at=n;cleaned.bleeds_removed_spell=id
   cleaned.bleeds_reapply_after=n+removal_delay;cleaned.last_seen=n
  end
 end
 local external_duration=externals[id]
 if external_duration and data.target and is_enemy(data.target) then
  row.external_used=n;row.external_spell_used=id
  local target_key=key(data.target,guid)
  if target_key then
   local target_row=memory[target_key] or {};memory[target_key]=target_row
   target_row.external_until=n+external_duration
   target_row.external_spell=id
   target_row.last_seen=n
  end
 end
end
function M.evaluate(c,n,h)
 for k,v in pairs(memory) do if type(v.last_seen)=='number' and n-v.last_seen>180 then memory[k]=nil end end
 local row=memory[c.target_key] or {}
 if c.damage_reduced then row.defensive_until=math.max(row.defensive_until or 0,n+0.5);row.last_seen=n;memory[c.target_key]=row end
 local target_trinket_ready=row.trinket_fixed_ready or (type(row.trinket_used)=='number' and row.trinket_used+(h.healer and h.healer(c.target) and 90 or 120) or row.trinket_ready)
 c.enemy_trinket_down=type(target_trinket_ready)=='number' and n<target_trinket_ready
 c.enemy_trinket_remaining=c.enemy_trinket_down and target_trinket_ready-n or 0
 c.trinket_recent=c.enemy_trinket_down
 c.enemy_trinket_kind=row.trinket_kind or 'Medallion'
 local race=c.target_race
 local race_key=type(race)=='string' and race:lower() or tonumber(race)
 local racial_cleanse=bleed_cleanse_races[race_key]==true
 c.bleed_cleanse_seen=type(row.bleed_cleanse_used)=='number'
 c.bleed_cleanse_available=racial_cleanse and not (type(row.bleed_cleanse_ready)=='number' and n<row.bleed_cleanse_ready)
 c.bleed_cleanse_remaining=type(row.bleed_cleanse_ready)=='number' and math.max(0,row.bleed_cleanse_ready-n) or nil
 c.bleeds_removed_at=row.bleeds_removed_at
 c.bleeds_removed_spell=row.bleeds_removed_spell
 c.bleeds_reapply_after=row.bleeds_reapply_after
 c.enemy_defensive=type(row.defensive_until)=='number' and n<row.defensive_until
 c.enemy_external=type(row.external_until)=='number' and n<row.external_until
 c.enemy_external_spell=c.enemy_external and row.external_spell or nil
 c.enemy_external_remaining=c.enemy_external and math.max(0,row.external_until-n) or 0
 c.enemy_mobility_down=type(row.mobility_used)=='number' and n-row.mobility_used<15
 c.enemy_burst=type(row.burst_until)=='number' and n<row.burst_until
 local focus=c.control_focus
 local focus_row=focus and memory[key(focus,h.guid)] or nil
 local focus_trinket_ready=focus_row and (focus_row.trinket_fixed_ready or (type(focus_row.trinket_used)=='number' and focus_row.trinket_used+90 or focus_row.trinket_ready)) or nil
 c.healer_trinket_down=type(focus_trinket_ready)=='number' and n<focus_trinket_ready
 c.healer_trinket_remaining=c.healer_trinket_down and focus_trinket_ready-n or 0
 c.healer_trinket_kind=focus_row and (focus_row.trinket_kind or 'Medallion') or nil
 c.healer_external_spent_recent=focus_row and type(focus_row.external_used)=='number' and n-focus_row.external_used<=30 or false
 c.healer_external_spent_spell=c.healer_external_spent_recent and focus_row.external_spell_used or nil
 c.healer_external_spent_age=c.healer_external_spent_recent and n-focus_row.external_used or nil
 c.healer_distance=focus and h.dist(c.player,focus) or nil
 c.healer_los=focus and h.los(c.player,focus) or false
 c.enemy_healer_to_target=focus and h.dist(focus,c.target) or nil
 local isolated=not c.healer_present or c.healer_cc or c.healer_distance and c.healer_distance>30 or not c.healer_los
 c.position_score=(isolated and 2 or 0)+(c.target_hp<=45 and 2 or 0)+(c.enemy_trinket_down and 1 or 0)
  +(c.healer_external_spent_recent and 1 or 0)
  -(c.enemy_defensive and 3 or 0)-(c.enemy_external and 3 or 0)
 c.enemy_vulnerable=c.position_score>=2
 c.cc_chain_next=c.healer_cc and 'hold: healer already controlled'
  or c.enemy_trinket_down and 'Gouge/Blind healer, then Sap if combat drops'
  or c.target_stunned and 'Blind or Gouge healer during target stun'
  or 'Kidney kill target after off-target control'
 c.mobility_plan=c.enemy_mobility_down and 'enemy mobility recently spent; preserve final Shadowstep'
  or c.kill_window and 'commit Shadowstep if target escapes' or 'reserve one Shadowstep charge'
 local class=c.target_class
 c.matchup_school=({[1]='physical',[3]='physical',[4]='physical',[5]='magic',[7]='magic',[8]='magic',[9]='magic',[13]='magic'})[class]
 c.matchup_defense=c.enemy_burst and ('enemy offensive cooldown remembered; '..(c.matchup_school or 'mixed')..' response primed') or 'normal predictive thresholds'
 c.healing_risk=c.friendly_healer_present and not c.friendly_healer_available and 'friendly healer unavailable' or 'healing support available or solo'
 c.intel_status=string.format('position=%d vulnerable=%s trinket_down=%s trinket_s=%.1f healer_trinket_down=%s healer_trinket_s=%.1f defensive=%s external=%s external_s=%.1f healer_save_spent=%s healer_save_age=%s bleed_cleanse=%s cleanse_cd=%s mobility=%s cc=%s',
  c.position_score,tostring(c.enemy_vulnerable),tostring(c.enemy_trinket_down),c.enemy_trinket_remaining,tostring(c.healer_trinket_down),c.healer_trinket_remaining,tostring(c.enemy_defensive),
  tostring(c.enemy_external),c.enemy_external_remaining,tostring(c.healer_external_spent_recent),tostring(c.healer_external_spent_age),
  tostring(c.bleed_cleanse_available),tostring(c.bleed_cleanse_remaining),c.mobility_plan,c.cc_chain_next)..' healing='..c.healing_risk
 return c
end
function M.memory_for(k) return memory[tostring(k)] end
return M
