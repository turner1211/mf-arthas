local U=require('ui_util')
local V,Color,E=require('common/geometry/vector_2'),require('common/color'),require('common/enums')
local T={choices={}}
T.labels={'Overview','Cooldowns','PvP','Meters'}
function T.default(mode)return (mode=='arena' or mode=='battleground' or mode=='world_pvp') and 3 or 1 end
function T.select(id,mode,page,C)
 T.choices[tostring(id)..':'..mode]=page
 C=C or require('ui_settings');C.for_mode(id,mode).view:set(page or 0)
end
function T.page(id,mode,C)
 local saved=C.for_mode(id,mode).view:get()
 return saved>0 and saved or (C.auto_view:get_state() and T.default(mode) or 1)
end
function T.render(R,S,C,image)
 R.toggle(C)
 local s=S.snapshot
 if not C.enabled:get_state() or not s or (C.combat_only:get_state() and not s.combat)then R.hide();return end
 local w=R.windows[s.profile.id];if not w then return end
 for id,other in pairs(R.windows)do if id~=s.profile.id then other:set_visibility(false)end end
 local cfg=C.for_mode(s.profile.id,s.mode);local page=T.page(s.profile.id,s.mode,C)
 local encounters=C.encounters:get_state() and s.encounters or {}
 local timers=C.encounter_timers:get_state() and s.timers or {}
 local H=page==1 and ((#encounters>0 and 520+math.min(5,#encounters)*58 or 480)+(#timers>0 and 90 or 0)) or page==2 and 510 or page==3 and 509+math.min(5,#encounters)*58 or 460
 local W=780;local screen=U.fn(core.graphics.get_screen_size) or {x=1920,y=1080}
 local sw,sh=U.num(screen.x) or 1920,U.num(screen.y) or 1080
 local scale=math.min(cfg.scale:get()/100*(C.compact:get_state() and 0.8 or 1),sw/W,sh/H)
 R.layouts=R.layouts or {}
 local signature=table.concat({s.mode,page,cfg.x:get(),cfg.y:get(),scale,sw,sh,H},':')
 if R.layouts[s.profile.id]~=signature then
  local pos=V.new(math.max(0,sw-W*scale)*cfg.x:get()/100,math.max(0,sh-H*scale)*cfg.y:get()/100)
  if w.force_next_begin_window_pos then w:force_next_begin_window_pos(pos)elseif w.set_position then w:set_position(pos)else w:set_initial_position(pos)end
  w:set_initial_size(V.new(W*scale,H*scale));R.layouts[s.profile.id]=signature
 elseif w.stop_forcing_position then w:stop_forcing_position()end
 if w.force_window_size then w:force_window_size(V.new(W*scale,H*scale))end
 w:set_visibility(true)
 local white=Color.new(255,255,255,255);local muted=Color.new(207,214,224,255)
 local red=Color.new(239,91,102,255);local green=Color.new(86,230,164,255)
 local panel=Color.new(17,15,23,246);local bg=Color.new(13,10,17,255)
 local rgb=s.class.color;local accent=Color.new(rgb[1],rgb[2],rgb[3],255)
 local function v(x,y)return V.new(x*scale,y*scale)end
 local function rect(x,y,ww,hh,c)w:render_rect_filled(v(x,y),v(x+ww,y+hh),c or panel,5*scale)end
 local function text(value,x,y,size,c)
  if w.render_text_custom_size then w:render_text_custom_size(7,v(x,y),c or white,math.max(14,(size or 18)*scale),U.text(value,90))
  else w:render_text(7,v(x,y),c or white,U.text(value,90))end
 end
 local function button(label,x,y,ww,action,active)
  local over=w.is_mouse_hovering_rect and w:is_mouse_hovering_rect(v(x,y),v(x+ww,y+36))
  rect(x,y,ww,36,active and Color.new(136,39,53,255) or over and Color.new(97,32,45,255) or panel)
  rect(x,y,ww,2,active and red or muted);text(label,x+10,y+9,18)
  if w.is_rect_clicked and w:is_rect_clicked(v(x,y),v(x+ww,y+36))then action()end
 end
 local function health(u,label,x,y,ww)
  text(label,x,y,16,muted);rect(x,y+24,ww,32)
  if u and u.pct then rect(x,y+24,ww*u.pct,32,u.pct<0.35 and red or green)end
  text(U.text(u and u.name or 'No target',22),x+8,y+32,17)
  text(u and (u.dead and 'DEAD' or u.pct and string.format('%.0f%%',u.pct*100) or '--') or '--',x+ww-76,y+32,17)
  if u and u.cast then text(U.text(u.cast.name,20)..' '..string.format('%.1fs',u.cast.left)..(u.cast.interruptible==false and ' / protected' or ''),x,y+64,16,accent)end
  if u and u.heal_absorb and u.heal_absorb>0 then text('HEAL ABSORB '..require('ui_meters').format(u.heal_absorb),x,y+84,15,red)
  elseif u and u.shield and u.shield>0 then text('SHIELD '..require('ui_meters').format(u.shield),x,y+84,15,accent)
  elseif u and u.incoming and u.incoming>0 then text('INCOMING '..require('ui_meters').format(u.incoming),x,y+84,15,green)end
 end
 local function encounter(y)
  for i=1,math.min(5,#encounters)do
   local u=encounters[i];rect(18,y+(i-1)*58,742,52)
   text(U.text(u.name,22),28,y+8+(i-1)*58,18)
   text(u.pct and string.format('%.0f%%',u.pct*100) or '--',300,y+8+(i-1)*58,18)
   text(u.label or '',405,y+8+(i-1)*58,16,muted)
   if u.cast then text(U.text(u.cast.name,25)..string.format(' %.1fs',u.cast.left)..(u.cast.interruptible==false and ' / protected' or ''),28,y+30+(i-1)*58,16,accent)end
  end
 end
 local we=E.window_enums or E
 w:begin((we.window_resizing_flags or {}).RESIZE_BOTH_AXIS or 0,false,bg,red,(we.window_cross_visuals or {}).NO_CROSS or 9,function()
  rect(0,0,W,H,bg)
  if C.pvp_theme:get_state()then image(w,'background',0,0,W*scale,H*scale);rect(0,0,W,H,Color.new(10,8,14,70))end
  rect(12,10,756,65);image(w,'control',18*scale,15*scale,54*scale,54*scale)
  text('SYLVANAS / '..s.mode_label:upper(),88,17,17)
  text(s.profile.name..' '..s.class.name,88,40,24,accent)
  button('HIDE',670,15,90,function()C.enabled:set(false)end)
  for i,label in ipairs(T.labels)do local index=i;button(label,18+(i-1)*156,85,148,function()T.select(s.profile.id,s.mode,index,C)end,page==i)end
  button('AUTO',642,85,118,function()T.select(s.profile.id,s.mode,nil,C);C.auto_view:set(true)end,cfg.view:get()==0 and C.auto_view:get_state())
  if page==1 then
   health(s.player,'PLAYER',18,135,355);health(s.target,'TARGET',405,135,355)
   for i,r in ipairs(s.resources)do
    local y=235+(i-1)*34;rect(18,y,742,28)
    if r.pct then rect(18,y,742*r.pct,28,accent)end
    text(r.name,28,y+5,17);text(r.value and (r.stack and r.value..' stacks' or tostring(r.value)..' / '..tostring(r.max or '--')) or '--',600,y+5,17)
   end
   local pages=math.max(1,math.ceil(#s.party/8));local group_page=math.min(cfg.page:get(),pages)
   local low,dead,offline=0,0,0
   for _,member in ipairs(s.party)do
    if member.online==false then offline=offline+1 elseif member.dead then dead=dead+1 elseif member.pct and member.pct<0.35 then low=low+1 end
   end
   local alert=(low>0 and ' / '..low..' LOW' or '')..(dead>0 and ' / '..dead..' DEAD' or '')..(offline>0 and ' / '..offline..' OFFLINE' or '')
   text('GROUP / '..group_page..' of '..pages..alert..(s.partial_roster and ' / loaded members' or ''),18,315,17,low+dead>0 and red or white)
   if C.party:get_state()then
    for i=(group_page-1)*8+1,math.min(group_page*8,#s.party)do
     local u=s.party[i];local slot=(i-1)%8;local x=18+(slot%4)*186;local y=344+math.floor(slot/4)*36
     rect(x,y,178,32);if u.pct then rect(x,y,178*u.pct,32,u.pct<0.35 and red or green)end
     text(U.text(u.name,10),x+6,y+8,16)
     text(u.online==false and 'OFF' or not u.loaded and 'RANGE' or u.dead and 'DEAD' or u.pct and string.format('%.0f%%',u.pct*100) or '--',x+116,y+8,16)
    end
    if #s.party==0 then text(s.partial_roster and 'No loaded group members' or not s.roster_available and 'Group data unavailable' or 'Solo',18,345,18,muted)end
   else text('Group panel disabled in options',18,345,18,muted)end
   if C.buffs:get_state()then
    local buffs={};for i=1,math.min(3,#s.buffs)do buffs[#buffs+1]=s.buffs[i].name end
    text(U.text(table.concat(buffs,' / '),65),18,420,16,muted)
   end
   if #encounters>0 then text(s.mode=='arena' and 'ARENA OPPONENTS' or 'ENCOUNTERS',18,451,17);encounter(480)end
   if #timers>0 then
    local y=#encounters>0 and 500+math.min(5,#encounters)*58 or 451
    text('NEXT ENCOUNTER EVENTS / BIGWIGS',18,y,17)
    for i=1,math.min(2,#timers)do local event=timers[i];text(event.name..string.format(' / %.1fs',event.left),18,y+24*i,18,event.important and red or white)end
   end
  elseif page==2 then
   text('YOUR ABILITY COOLDOWNS / CHARGES',18,139,20)
   if not C.cooldowns:get_state()then text('Cooldown tiles disabled in options',18,180,20,muted)
   elseif #s.cooldowns==0 then text('No tracked learned spells. Add spell IDs in options.',18,180,18,muted)
   else for i=1,math.min(9,#s.cooldowns)do
    local row=s.cooldowns[i];local x=18+((i-1)%3)*250;local y=180+math.floor((i-1)/3)*94
    rect(x,y,242,86);text(U.text(row.name,23),x+12,y+10,19)
    local state=U.cooldown(row);text(state,x+12,y+36,24,state=='AVAILABLE' and green or accent)
    if row.charges~=nil and row.max_charges and row.max_charges>0 then text(row.charges..' / '..row.max_charges..' charges',x+12,y+65,16,muted)end
   end end
  elseif page==3 then
   health(s.player,'PLAYER',18,135,355);health(s.target,'TARGET',405,135,355)
   local p=s.pvp
   if not p then text('PvP awareness opens in Arena, BGs and World PvP.',18,244,18,muted)
   else
    rect(18,244,742,143);text('YOU '..p.player_cc..' / TARGET '..p.target_cc,28,255,19)
    text(p.burst==true and 'ENEMY BURST ACTIVE' or p.burst==false and 'No burst detected' or 'Burst data unavailable',28,282,18,p.burst==true and red or muted)
    for i,row in ipairs(p.dr)do
     local value=row.value==nil and '--' or row.value==0 and 'IMMUNE' or string.format('%.0f%%',row.value*100)
     text(row.name..' '..value,28+(i-1)*184,309,17,row.value==0 and red or white)
     text(row.left and row.left>0 and string.format('Reset %.1fs',row.left) or '',28+(i-1)*184,331,16,muted)
    end
    text(p.trinket_age and string.format('Target trinket used %.0fs ago',p.trinket_age) or 'Target trinket / not observed',28,358,18,muted)
    if #p.cooldowns>0 then text(p.cooldowns[1].name..string.format(' / %.1fs',p.cooldowns[1].left),18,394,18,accent)end
   end
   if s.score then text(string.format('MATCH / Kills %s / Deaths %s / Honor %s',s.score.kills or '--',s.score.deaths or '--',s.score.honor or '--'),18,422,18,muted)end
   encounter(454)
  elseif page==4 then
   local m=s.meters or {label='CURRENT FIGHT',status='Meter unavailable'}
   text('YOUR COMBAT METERS / '..m.label,18,139,20)
   if C.meters:get_state()then
    local labels={'DAMAGE','DPS','HEALING','HPS'};local values={m.damage,m.dps,m.healing,m.hps}
    for i=1,4 do
     local x=18+((i-1)%2)*387;local y=178+math.floor((i-1)/2)*92
     rect(x,y,355,84);image(w,i<=2 and 'poison' or 'control',(x+292)*scale,(y+16)*scale,48*scale,48*scale)
     text(labels[i],x+14,y+12,18,muted);text(require('ui_meters').format(values[i]),x+14,y+39,30)
    end
    button(m.label,18,376,200,function()C.meter_overall:set(not C.meter_overall:get_state())end)
    button('RESET METERS',550,376,210,function()if require('ui_meters').reset()then s.meters=require('ui_meters').read(C.meter_overall:get_state())end end)
   else text('Meters disabled in options',18,180,20,muted)end
  end
  rect(18,H-38,742,28)
  local gcd=C.gcd:get_state() and (s.gcd==nil and 'GCD --' or s.gcd>0 and string.format('GCD %.2fs',s.gcd) or 'GCD READY') or ''
  text(gcd,28,H-32,17,s.gcd and s.gcd>0 and red or white)
  local context=s.activity_info or (s.combat and 'IN COMBAT' or 'EXPLORING')
  if s.combat_seconds then context=context..string.format(' / %.0fs',s.combat_seconds)end
  text(U.text(context,42),310,H-32,17,muted)
 end)
end
return T
