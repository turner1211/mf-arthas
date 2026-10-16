local U=require('hh_util');local S=require('hh_spells');local A=require('hh_aura');local F={}
function F.level(c,n)return(U.number(c.level)or 60)>=n end
local function has_any(c,ids,debuff)for _,id in ipairs(ids or{})do local active,left=(debuff and c.debuff or c.buff)(id);if active==true then return true,left end end;return false end
function F.has(unit,ids)
 for _,id in ipairs(ids or{})do if A.read(unit,id)==true then return true end end
 return false
end
function F.mark_and_sting(c,e)
 local a
 if F.level(c,6)and not has_any(c,S.aura.mark,true)then a=c.pick('hunters_mark','apply Hunter Mark before damage');if a then return a end end
 if c.settings.forever_stings==false then return end
 if not F.level(c,4)then return end
 local class=U.number(U.call(c.target,'get_class'))
 local physical_pvp=c.pvp and(class==1 or class==3 or class==4 or c.physical==true)
 if physical_pvp then
  if has_any(c,S.aura.scorpid,true)then return end
  a=c.pick('scorpid_sting','reduce physical PvP pressure with Forever Scorpid Sting');if a then return a end
 elseif F.level(c,36)and c.pvp and c.target_mana_pct and c.target_mana_pct>25 then
  if has_any(c,S.aura.viper,true)then return end
  -- Viper starts at level 36, above the current cap. If it is not learned,
  -- keep evaluating so a mana target still receives Serpent Sting.
  a=c.pick('viper_sting','drain a mana target with the Forever 15-second Viper cooldown');if a then return a end
 end
 if (not c.target_hp or c.target_hp>35)and not has_any(c,S.aura.serpent,true)then
  a=c.pick('serpent_sting','maintain efficient Serpent Sting on a durable target');if a then return a end
 end
end
function F.aspect(c,key,aura,why)
 if not has_any(c,aura,false)then return c.pick(key,why)end
end
function F.open(c,e)
 local a
 if F.level(c,10)then a=F.aspect(c,'aspect_hawk',S.aura.hawk,'maintain ranged Aspect of the Hawk');if a then return a end end
 return F.mark_and_sting(c,e)
end
function F.mana(c)return c.resource_pct or 0 end
function F.can_spend(c,key,reserve)
 if c.settings.forever_mana_pool==false then return true end
 local cost=c.cost and c.cost(key)
 if not cost or not c.focus_max or c.focus_max<=0 then return F.mana(c)>=reserve end
 return ((c.focus-cost)/c.focus_max*100)>=reserve
end
function F.hawks(c,e)
 local list=e.forever_hawks or{};local active={}
 local count=0
 for _,row in ipairs(list)do
  local at=type(row)=='table'and row.time or row
  local target=type(row)=='table'and row.target or c.target_guid
  if at and c.now-at<18 then active[#active+1]=row;if target==c.target_guid then count=count+1 end end
 end
 e.forever_hawks=active;return count
end
function F.multi_threshold(c)return c.pvp and 3 or 2 end
function F.rapid_fire(c)
 if not F.level(c,26)or not c.burst then return false end
 return c.pvp or F.mana(c)<95
end
function F.pet_first(c,e)
 if c.pvp or c.settings.forever_pet_first==false or not c.target_engaged or not U.valid(c.pet)or c.pet_on_target then
  e.forever_pet_wait=nil;return false
 end
 local row=e.forever_pet_wait
 if not row or row.guid~=c.target_guid then row={guid=c.target_guid,time=c.now};e.forever_pet_wait=row end
 return c.now-row.time<1.25
end
function F.durable(c,seconds,hp)
 if c.ttd then return c.ttd>=seconds end
 return not c.target_hp or c.target_hp>hp
end
function F.pvp_tracking(c,e)
 if c.spec~=255 or not c.pvp or c.settings.forever_pvp_tracking==false then return end
 local active=c.buff(S.aura.track_humanoids[1])
 -- Some hosts expose tracking as an aura; others do not. A confirmed local
 -- cast is a safe fallback that prevents repeated GCD requests on nil data.
 if active==true or active==nil and e.history.track_humanoids then return end
 return c.pick('track_humanoids','enable Improved Tracking damage against PvP humanoids')
end
function F.burst_reset(c,keys,why)
 if c.settings.forever_readiness==false or not c.burst or c.ttd and c.ttd<15 then return end
 for _,key in ipairs(keys or{})do
  if c.known(key)and c.cd(key)>10 then return c.pick('readiness',why)end
 end
end
return F
