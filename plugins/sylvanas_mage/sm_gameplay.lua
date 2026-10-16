local U,N,S=require('sm_util'),require('sm_snapshot'),require('sm_spells')
local G={}
local activities={
 world_pve='Follow your chosen target; avoid starting another pull.',
 delve='Let your companion establish pressure; keep recovery outside burst.',
 dungeon='Follow tank pulls and assignments; save control for dangerous casts.',
 mythic_plus='Use safe pack damage; follow assigned interrupts and priority adds.',
 raid='Follow encounter assignments; protect burst and movement windows.',
 arena='Coordinate healer control and kill target; major burst needs permission.',
 battleground='Stay with support; use pressure and control around objectives.',
 world_pvp='Keep an escape route; avoid extending beyond friendly support.'}
function G.advice(c)
 if not c or (c.spec~=62 and c.spec~=63 and c.spec~=64) or not c.identity or c.identity.id~=c.spec
  or (require('sm_modes').pvp[c.mode]==true)~=c.pvp then return 'Waiting for current gameplay data.' end
 local prompt
 if c.hp and math.min(c.hp,c.predicted_hp or c.hp)<=20 then prompt='Emergency pressure: use mitigation and move to safety.'
 elseif c.target and N.protected(c.target) then prompt='Protected target: preserve crowd control and choose another target manually.'
 elseif c.target and require('sm_aura').any(c.target,{23920,216890}) then prompt='Spell Reflection: hold direct spells until it fades.'
 elseif c.pvp and c.enemy_burst then prompt='Enemy burst: use barrier and defensive positioning.'
 elseif c.pvp and c.attackers>0 then prompt='Focused: kite toward support; use safe roots and instant pressure.'
 elseif c.pvp and c.ally_peel_target then prompt='Teammate pressured: control the confirmed melee attacker and preserve the teammate\'s escape route.'
 elseif c.pvp and c.defensive_poly_target then prompt='Critical teammate: a clean disruptive DPS is available for defensive Polymorph.'
 elseif c.pvp and c.distance and c.distance<20 then prompt='Range compressed: use spec control and movement to reopen 30-40 yards.'
 elseif c.pvp and c.distance and c.distance>40 then prompt='Target beyond spell range: close carefully while preserving an escape route.'
 elseif c.reduced then prompt='Strong target mitigation: save major burst and reassess pressure.'
 elseif c.casts and c.casts[1] and c.casts[1].interruptible and (c.casts[1].priority or 0)>=2 then prompt='Dangerous cast: respect interrupt assignment and Counterspell availability.'
 elseif not c.target_valid or not c.target_engaged then prompt='Choose an engaged, eligible target before damage.'
 elseif c.mana_pct and c.mana_pct<20 then prompt=c.spec==62 and 'Low mana: conserve with Barrage; recover outside Surge and Touch.' or 'Low mana: preserve resources and avoid unnecessary Spellsteal.'
 elseif c.pvp and not c.burst then prompt='Burst held: build pressure and coordinate a kill window.'
 elseif not c.aoe_clear then prompt='Crowd control or idle enemies nearby: avoid splash damage.'
 else prompt=activities[c.mode] or 'Follow the current activity assignments.' end
 local tip
 if c.pvp then
  if c.spec==62 then tip='Arcane PvP: build charges safely; use instant Barrage under pressure and align permitted Touch/Surge.'
  elseif c.spec==63 then tip='Fire PvP: spend Hot Streak promptly; use Meteor in confirmed control and preserve movement.'
  else tip='Frost PvP: spend Fingers for instant pressure; complete Ray only with space or control.' end
 elseif c.spec==62 then tip=c.talent('sunfury') and 'Sunfury: align Salvo spenders and Touch with Surge.' or 'Spellslinger: consume Prismatic procs and rebuild charges safely.'
 elseif c.spec==63 then tip=c.talent('frostfire') and 'Frostfire: reserve procs near Combustion; time Burnout Meteor late.' or 'Sunfury: spend Hot Streak and Scorch during Combustion.'
 else tip=c.talent('frostfire') and 'Frostfire: hold single Fingers outside Thermal Void; spend at 12 Freezing.' or 'Spellslinger: spend Fingers and 6 Freezing; manage Icicle overflow.' end
 return prompt..' '..tip
end
return G
