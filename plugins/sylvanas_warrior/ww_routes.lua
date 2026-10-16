local U=require('ww_util')
local Guides=require('ww_route_data')
local Packs=require('ww_route_packs')
local R={state={pull=1,guide=nil,visible={},bound={},dead={},used={},anchors={}},status='Route waiting',actions={}}
local last_context,next_scan=nil,0
local progress_file='sylvanas_warrior/route_progress.txt'
local function replace_data(text)
 if type(core.create_data_file)~='function'or type(core.write_data_file)~='function'then return end
 if type(core.create_data_folder)=='function'then U.fn(core.create_data_folder,'sylvanas_warrior')end
 if type(core.delete_data_file)=='function'then U.fn(core.delete_data_file,progress_file)end
 U.fn(core.create_data_file,progress_file);U.fn(core.write_data_file,progress_file,text)
end
local function normalize(v)return tostring(v or ''):lower():gsub('[^%w]','') end
local function context()
 local kind=U.fn(core.get_instance_type);local challenge=core.world and U.number(U.fn(core.world.get_active_challenge_map_id)) or 0
 if kind~='party' and challenge<=0 then return nil end
 local name=U.fn(core.get_instance_name) or '';local key=tostring(U.fn(core.get_instance_id))..':'..challenge..':'..name
 if challenge>0 then for _,g in ipairs(Guides) do local p=Packs[g.name];if p and p.challenge_id==challenge then return key,g end end end
 for _,g in ipairs(Guides) do for _,alias in ipairs(g.aliases or {}) do
  if normalize(name):find(normalize(alias),1,true) then return key,g end
 end end
 return key,nil
end
local function save_progress()
 local s=R.state
 if not last_context or not s.guide then return end
 replace_data(table.concat({last_context,s.guide.name,tostring(s.pull)},'\t'))
end
local function restore_progress(context_key,guide)
 if not context_key or not guide or type(core.read_data_file)~='function'then return end
 local raw=U.fn(core.read_data_file,progress_file);if type(raw)~='string'or raw==''then return end
 local saved_context,saved_guide,pull=raw:match('^([^\t]*)\t([^\t]*)\t(%d+)$');pull=U.number(pull)
 if saved_context==context_key and saved_guide==guide.name and pull and pull==math.floor(pull)
  and pull>=1 and pull<=#guide.pulls+1 then R.state.pull=pull end
end
local function reset(guide,restore,context_key)
 R.state={pull=1,guide=guide,visible={},bound={},dead={},used={},anchors={},mismatch_since=nil,last_player_pos=nil}
 if restore then restore_progress(context_key,guide)end
 R.status=guide and guide.name..' | Pull 1/'..#guide.pulls or 'No saved route for this dungeon'
 if guide then R.status=guide.name..' | Pull '..R.state.pull..'/'..#guide.pulls end
end
local function step(delta)
 local s=R.state;if not s.guide then return end
 for guid in pairs(s.bound) do s.used[guid]=true end
 s.pull=math.max(1,math.min(#s.guide.pulls+1,s.pull+delta));s.bound={};s.dead={};s.visible={};next_scan=0
 R.status=s.pull>#s.guide.pulls and s.guide.name..' | Route complete' or s.guide.name..' | Pull '..s.pull..'/'..#s.guide.pulls
 save_progress()
end
R.actions.previous=function()step(-1)end;R.actions.next=function()step(1)end
R.actions.reset=function()reset(R.state.guide,false,last_context);replace_data('');next_scan=0 end
local function count(ids)local t={};for _,id in ipairs(ids or {})do t[id]=(t[id]or 0)+1 end;return t end
local function center(rows)
 local x,y,z,n=0,0,0,0;for _,r in ipairs(rows)do local p=U.call(r.unit,'get_position');if p then x=x+p.x;y=y+p.y;z=z+p.z;n=n+1 end end
 if n>0 then return require('common/geometry/vector_3').new(x/n,y/n,z/n) end
end
local function raw_center(rows)
 local x,y,z,n=0,0,0,0;for _,r in ipairs(rows)do local p=U.call(r.unit,'get_position');if p then x=x+p.x;y=y+p.y;z=z+p.z;n=n+1 end end
 if n>0 then return{x=x/n,y=y/n,z=z/n}end
end
local function point_distance(a,b)
 if not a or not b then return math.huge end
 return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)
end
local function route_frequency(guide)
 local frequency={};for _,pull in ipairs(guide.pulls)do local seen={};for _,id in ipairs(pull)do seen[id]=true end;for id in pairs(seen)do frequency[id]=(frequency[id]or 0)+1 end end
 return frequency
end
local function score_pull(guide,index,objects,frequency,current)
 local wanted=count(guide.pulls[index]);local matched,rare,distance=0,0,0
 for id,needed in pairs(wanted)do
  local distances={};for _,r in ipairs(objects)do if r.id==id then distances[#distances+1]=r.distance end end;table.sort(distances)
  local take=math.min(needed,#distances);matched=matched+take
  for i=1,take do distance=distance+distances[i]end
  if take>0 then rare=rare+take/math.max(1,frequency[id]or 1)end
 end
 local expected=#guide.pulls[index];local coverage=expected>0 and matched/expected or 0
 local average=matched>0 and distance/matched or 100
 return{index=index,matched=matched,expected=expected,coverage=coverage,rare=rare,average=average,
  score=matched*10+coverage*45+rare*8-average*.04-math.abs(index-current)*.35}
end
local function locate_pull(player,guide,objects,now)
 local s=R.state;local frequency=route_frequency(guide);local current=score_pull(guide,s.pull,objects,frequency,s.pull);local best=current
 for index=1,#guide.pulls do local row=score_pull(guide,index,objects,frequency,s.pull);if row.score>best.score then best=row end end
 local pp=U.call(player,'get_position');local teleported=point_distance(pp,s.last_player_pos)>100;s.last_player_pos=pp and{x=pp.x,y=pp.y,z=pp.z}or s.last_player_pos
 if current.matched==0 then s.mismatch_since=s.mismatch_since or now else s.mismatch_since=nil end
 local recovery=teleported or current.matched==0 and now-(s.mismatch_since or now)>=1.4
 local ahead=best.index>s.pull;local behind=best.index<s.pull
 local strong=best.coverage>=.72 or best.matched>=3 and best.rare>=1.0 or best.matched>=1 and best.expected==1
 local clearly_better=best.score>=current.score+10
 if best.index~=s.pull and strong and clearly_better and (ahead or behind and recovery)then
  s.pull=best.index;s.bound={};s.dead={};s.visible={};s.mismatch_since=nil
  local anchor=raw_center(objects);if anchor then s.anchors[best.index]=anchor end
  save_progress();return best,true
 end
 if current.matched>0 and current.coverage>=.45 then local anchor=raw_center(objects);if anchor then s.anchors[s.pull]=anchor end end
 return current,false
end
R.score_pull=score_pull
function R.update(player,identity,mode,enabled)
 if not enabled or not identity or identity.id~=73 or (mode~='mythic_plus' and mode~='dungeon') then
  R.state.visible={};R.status='Protection dungeon route inactive';return
 end
 local now=U.number(U.fn(core.time))or 0;if now<next_scan then return end;next_scan=now+.35
 local ctx,guide=context()
 -- Route progress belongs to one character and one dungeon context. This keeps
 -- two Protection Warriors from restoring each other's active pull.
 if ctx then ctx=tostring(identity.player or U.guid(player)or'?')..'|'..ctx end
 if ctx~=last_context or guide~=R.state.guide then last_context=ctx;reset(guide,true,ctx) end
 local s=R.state;if not guide or s.pull>#guide.pulls then return end
 local objects={}
 for _,row in pairs(U.fn(core.object_manager.get_all_objects)or{})do
  local u=type(row)=='table' and row.object or row
  if U.valid(u) and not U.same(u,player) and U.call(u,'is_player')~=true then
   local id=U.number(U.call(u,'get_npc_id'));local guid=U.guid(u)
   if id and guid and not s.used[guid] and U.distance(player,u)<=100 then
    objects[#objects+1]={unit=u,id=id,guid=guid,distance=U.distance(player,u)}
   end
  end
 end
 local located,moved=locate_pull(player,guide,objects,now)
 local wanted,available=count(guide.pulls[s.pull]),{}
 for _,r in ipairs(objects)do if wanted[r.id]and not s.bound[r.guid]then available[#available+1]=r end end
 table.sort(available,function(a,b)return a.distance<b.distance end)
 local occupied={};for _,r in pairs(s.bound)do occupied[r.id]=(occupied[r.id]or 0)+1 end
 for _,r in ipairs(available)do if (occupied[r.id]or 0)<(wanted[r.id]or 0) then s.bound[r.guid]=r;occupied[r.id]=(occupied[r.id]or 0)+1 end end
 local live,dead_count={},{}
 for _,id in pairs(s.dead)do dead_count[id]=(dead_count[id]or 0)+1 end
 for guid,r in pairs(s.bound)do
  if s.dead[guid] then
  elseif U.call(r.unit,'is_dead')==true then s.dead[guid]=r.id;dead_count[r.id]=(dead_count[r.id]or 0)+1
  elseif U.valid(r.unit) then live[#live+1]=r end
 end
 local complete=next(s.bound)~=nil
 for id,n in pairs(wanted)do if (dead_count[id]or 0)<n then complete=false;break end end
 if complete then for guid in pairs(s.bound)do s.used[guid]=true end;s.pull=s.pull+1;s.bound={};s.dead={};save_progress();return R.update(player,identity,mode,enabled) end
 s.visible=live;local matched=0;for _ in pairs(s.bound)do matched=matched+1 end
 local expected=#guide.pulls[s.pull];local confidence=expected>0 and math.floor(matched/expected*100+.5)or 0
 local pack=Packs[guide.name];local forces=pack and pack.planned_forces
 R.status=guide.name..' | Pull '..s.pull..'/'..#guide.pulls..(moved and' | AUTO-LOCATED' or' | location tracking')
  ..' | matched '..matched..'/'..expected..' ('..confidence..'%)'
  ..(forces and ' | route forces '..forces or '')
end
function R.render(enabled)
 if not enabled or not R.state.guide or #R.state.visible==0 or not core.graphics then return end
 local ok,color=pcall(require,'common/color');if not ok then return end
 local yellow=color.new(255,220,55,145);local green=color.new(55,230,115,135);local text_color=color.new(255,230,95,220);local vec2=require('common/geometry/vector_2')
 local pos=center(R.state.visible);local player=U.fn(core.object_manager.get_local_player);local pp=U.call(player,'get_position')
 if core.graphics.text_2d then pcall(core.graphics.text_2d,R.status,vec2.new(30,160),13,text_color,false) end
 if pos and pp and core.graphics.line_3d then pcall(core.graphics.line_3d,pp,pos,green,2,0,false) end
 -- One small destination outline replaces the former 8-yard pack ring and
 -- per-enemy rings, keeping the tank and encounter floor unobscured.
 if pos and core.graphics.circle_3d then pcall(core.graphics.circle_3d,pos,3.25,yellow,24,.18) end
 if pos and core.graphics.text_3d then pcall(core.graphics.text_3d,'PULL '..R.state.pull,pos,13,text_color,true) end
end
return R
