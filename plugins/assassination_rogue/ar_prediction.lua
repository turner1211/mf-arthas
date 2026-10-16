local B=require("ar_bigwigs")
local Learning=require('ar_threat_learning')
local prediction_ok,HealthPrediction=pcall(require,'common/modules/health_prediction')
if not prediction_ok then HealthPrediction=nil end
local M={}
local prev={}
local stun_casts={[30283]=true,[305483]=true,[853]=true,[107570]=true,[119381]=true}
local control_casts={[118]=true,[51514]=true,[5782]=true,[33786]=true,[20066]=true,[605]=true,[360806]=true}
local function call(o,k,...)
 if not o or type(o[k])~="function" then return nil end
 local ok,v=pcall(o[k],o,...);if ok then return v end
end
local function same(a,b)
 local x,y=call(a,"get_guid"),call(b,"get_guid");return x and y and x==y or false
end
local function incoming_damage(player,seconds)
 local unit_value=call(player,'get_incoming_damage',seconds)
 local module_value=call(HealthPrediction,'get_incoming_damage',player,seconds)
 unit_value=type(unit_value)=='number' and math.max(0,unit_value) or nil
 module_value=type(module_value)=='number' and math.max(0,module_value) or nil
 if unit_value and module_value then
  return math.max(unit_value,module_value),unit_value>=module_value and 'unit' or 'health_prediction'
 end
 if unit_value then return unit_value,'unit' end
 if module_value then return module_value,'health_prediction' end
 return 0,'unavailable'
end
function M.evaluate(c,use_timers)
 local p=c.player;local n=core.time()
 local h,m=call(p,"get_health"),call(p,"get_max_health")
 local r={current=c.self_hp,projected=c.self_hp,loss=0,acceleration=0,incoming=0,casts=0,stoppable_casts=0,reachable_stops=0,unstoppable_casts=0,untargeted_casts=0,physical=false,magic=false}
 if type(h)~="number" or type(m)~="number" or m<=0 then return r end
 local key=tostring(call(p,"get_guid") or p)
 local incoming,incoming_source=incoming_damage(p,2)
 local healing=call(p,"get_incoming_heals")
 local heal_absorb=call(p,'get_total_heal_absorbs')
 local shield=call(p,'get_total_shield')
 healing=type(healing)=="number" and math.max(0,healing) or 0
 heal_absorb=type(heal_absorb)=='number' and math.max(0,heal_absorb) or 0
 shield=type(shield)=='number' and math.max(0,shield) or 0
 local effective_healing=math.max(0,healing-heal_absorb)
 local shield_credit=math.min(shield,incoming*0.75)
 r.incoming_source=incoming_source
 r.incoming_heals=healing/m*100;r.heal_absorb=heal_absorb/m*100;r.shield=shield/m*100;r.shield_credit=shield_credit/m*100
 r.incoming=math.max(0,incoming-math.min(effective_healing,incoming*0.5)-shield_credit)/m*100
 if prev.key==key and prev.time and n-prev.time>0 and n-prev.time<=1 then
  local raw=math.max(0,(prev.hp-c.self_hp)/(n-prev.time))
  r.loss=math.min(30,(prev.rate or 0)*0.65+raw*0.35)
  r.acceleration=math.max(0,r.loss-(prev.rate or 0))
 end
 prev={key=key,time=n,hp=c.self_hp,rate=r.loss}
 -- Avoid double counting overlapping host forecasts and observed health loss.
 local drop=math.max(r.incoming,r.loss*1.5+r.acceleration*0.75);r.learned_pressure=0;r.learned_samples=0
 for _,u in ipairs(c.enemies or {}) do
  if call(u,"is_casting_spell")==true or call(u,"is_channelling_spell")==true then
   local channel=call(u,'is_channelling_spell')==true
   local finish=channel and call(u,'get_active_channel_cast_end_time') or call(u,"get_active_spell_cast_end_time")
   if type(finish)=="number" and finish>=n and finish-n<=2 then
    local spell_id=channel and call(u,'get_active_channel_spell_id') or call(u,"get_active_spell_id")
    local learned,samples=Learning.pressure(c.mode,spell_id,m)
    local cast_target=call(u,"get_active_spell_target")
    local targets_player=same(cast_target,p)
    -- A cast with no unit target may be an area event. Require repeated learned
    -- damage before pre-defending; a cast aimed at someone else never qualifies.
    local learned_area=cast_target==nil and samples>=3 and learned>=8
    if targets_player or learned_area then
     local impact=finish-n;r.impact_in=math.min(r.impact_in or math.huge,impact)
     r.casts=r.casts+1
     if call(u,'is_active_spell_interruptable')==true then
      r.stoppable_casts=r.stoppable_casts+1
      local range_ok,range_value=pcall(core.spell_book and core.spell_book.is_spell_in_range or function()end,1766,u,p)
      local los_ok,los_value=pcall(core.graphics and core.graphics.is_line_of_sight or function()return true end,p,u)
      local in_range=range_ok and range_value==true
      local los=los_ok and los_value==true
      if c.kick_ready and in_range and los then r.reachable_stops=r.reachable_stops+1 end
     else r.unstoppable_casts=r.unstoppable_casts+1 end
     if learned_area and not targets_player then r.untargeted_casts=r.untargeted_casts+1 end
     if learned>r.learned_pressure then r.learned_pressure=learned;r.learned_samples=samples;r.learned_spell=spell_id end
     if targets_player and stun_casts[spell_id] then r.stun=true end
     if targets_player and control_casts[spell_id] then r.control=true;r.control_spell=spell_id end
     local school=call(u,"get_active_spell_school")
     if not school and core.spell_book and type(core.spell_book.get_spell_school)=="function" then
      local ok,v=pcall(core.spell_book.get_spell_school,spell_id);if ok then school=v end
     end
     if type(school)=="number" then
      if school==1 then r.physical=true elseif school>1 then r.magic=true end
     end
    end
   end
  end
 end
 drop=math.max(drop,r.learned_pressure)
 if c.pvp then drop=math.min(18,drop) else drop=math.min(40,drop) end
 r.recovery_penalty=(drop>=5 or c.attackers>0 or r.casts>0) and math.min(10,r.heal_absorb*0.25) or 0
 r.projected=math.max(0,c.self_hp-drop-r.recovery_penalty)
 r.timer=B.scan(use_timers,2,c.pvp)
 r.focus_burst=c.focus_burst==true
 r.danger=drop>=10 or r.unstoppable_casts>0 or r.stoppable_casts>r.reachable_stops
  or c.attackers>=2 or r.timer~=nil or r.focus_burst
 r.reason=string.format("projected=%.1f current=%.1f incoming=%.1f source=%s heals=%.1f heal_absorb=%.1f recovery_penalty=%.1f shield=%.1f shield_credit=%.1f loss/s=%.1f acceleration=%.1f casts=%d stoppable=%d reachable=%d unstoppable=%d untargeted=%d impact=%s control=%s learned=%.1f%%/%d spell=%s attackers=%d burst=%s timer=%s",
  r.projected,r.current,r.incoming,r.incoming_source,r.incoming_heals,r.heal_absorb,r.recovery_penalty,r.shield,r.shield_credit,r.loss,r.acceleration,r.casts,r.stoppable_casts,r.reachable_stops,r.unstoppable_casts,r.untargeted_casts,r.impact_in and string.format('%.2f',r.impact_in) or 'none',tostring(r.control_spell),r.learned_pressure,r.learned_samples,tostring(r.learned_spell),c.attackers,tostring(r.focus_burst),r.timer and r.timer.text or "none")
 return r
end
function M.reset() prev={} end
return M
