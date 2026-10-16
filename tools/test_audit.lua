local root=(arg and arg[0]or''):match('^(.*)[/\\]tools[/\\][^/\\]+$')or'.'
package.path=root..'/plugins/MasterArthasNav/?.lua;'..package.path
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local clock=0
core={time=function()return clock end}
local routes=require('anav/routes')
local start={x=0,y=0,z=20};local goal={x=10,y=0,z=0}
for _,bad in ipairs({0/0,math.huge,-1,'invalid',false})do
 local path,reason=routes.inspect({start,goal},goal,{max_drop=bad})
 check(path==nil and reason=='bad_route_options','reject invalid drop limit')
 path,reason=routes.inspect({start,goal},goal,{min_confidence=bad})
 check(path==nil and reason=='bad_route_options','reject invalid confidence limit')
end
for _,key in ipairs({'allow_falling','allow_partial'})do
 local options={[key]='false'};local path,reason=routes.inspect({start,goal},goal,options)
 check(path==nil and reason=='bad_route_options','text flags cannot enable unsafe routes')
end
check(routes.inspect({start,goal},goal)==nil,'default policy refuses unsafe drop')
check(routes.inspect({start,goal},goal,{allow_falling=true})~=nil,'explicit falling policy supported')
local corner={x=10,y=0,z=20};local finish={x=10,y=10,z=20}
local path=routes.inspect({start,corner,finish},finish)
local found=false;for _,p in ipairs(path)do if p.x==corner.x and p.y==corner.y and p.z==corner.z then found=true end end
check(found,'route subdivision preserves corner')
local old_reply;local events={}
routes.submit(function(cb)old_reply=cb end,function()return true end,0,function(_,_,e)events[#events+1]=e.code end)
routes.submit(function(cb)cb(true,{},'next')end,function()return true end,0,function(ok,_,e)check(not ok and e.code=='query_queue_timeout','expired waiting query is rejected')end)
clock=21;routes.pump()
check(events[1]=='query_timeout','active query timeout reported')
-- The waiting query also expired; submit fresh work after recovery.
local delivered=0;local fresh_reply
routes.submit(function(cb)fresh_reply=cb end,function()return true end,0,function()delivered=delivered+1 end)
old_reply(true)
check(delivered==0 and routes.metrics.late_responses==1 and routes.busy,'stale response cannot finish fresh query')
fresh_reply(true);check(delivered==1 and not routes.busy,'current response completes normally')
routes.submit(function(cb)cb(true)end,function()return true end,0,function()error('consumer failure')end)
check(routes.metrics.callback_errors==1 and not routes.busy,'consumer exception does not lock queue')
local L=require('mf_i18n')
local refresh=L.refresh
L.refresh=function()error('host refresh failure')end
check(not pcall(L.with_scope,function()end)and not L.depth,'refresh exception does not poison scope depth')
L.refresh=refresh
check(L.with_scope(function()return 'recovered'end)=='recovered','scope recovers after refresh error')
package.loaded.mf_unicode_font={get=function()error('host font failure')end}
L.set_locale('zhCN',false)
check(L.font_for(42)==42,'host font error preserves original font')
local weak=setmetatable({},{__mode='v'})
do local native={render=function()end};weak[1]=native;weak[2]=L.wrap_control(native)end
collectgarbage('collect');collectgarbage('collect')
check(weak[1]==nil and weak[2]==nil,'discarded control proxies are collectible')

local travel=require('anav/travel_policy')
local huge={available=true,distance=1e308,speed=1e-308}
check(travel.choose({huge})==nil,'overflowing travel time cannot be selected')
local sane={available=true,distance=100,speed=5,wait_seconds=2}
local chosen,cost=travel.choose({huge,sane})
check(chosen==sane and cost==22,'finite verified travel remains selectable')
local recorder=require('anav/flight_recorder')
local origin={x=0,y=0,z=0}
for i=0,29 do recorder.sample(i,origin,{})end
recorder.failure(30,'test')
for i=30,39 do recorder.sample(i,origin,{})end
recorder.sample(40,{x=0/0,y=0,z=0},{})
check(recorder.pending==nil and #recorder.captures==1,'bad coordinates cannot prevent capture finalization')
check(#recorder.captures[1].rows==40,'failure capture bounded to thirty pre and ten post samples')
recorder.failure(41,'next');recorder.failure(52,'new')
check(#recorder.captures==2 and recorder.pending.reason=='new','new failure settles expired pending capture')
local sample_deadline=recorder.next_sample
recorder.sample(0/0,origin,{})
check(recorder.next_sample==sample_deadline,'invalid timestamp cannot poison sample schedule')
check(pcall(recorder.sample,53,origin,nil),'missing diagnostic status handled')
local runtime=require('anav/runtime_api')
local stale=setmetatable({},{__index=function()error('expired object')end})
core.object_manager={get_local_player=function()return stale end}
check(runtime.position()==nil and runtime.casting()==false,'expired player properties safely handled')
core.object_manager={get_local_player=function(self)if not self then return nil end;return{is_valid=function()return true end,get_position=function()return origin end,is_channelling_spell=function()return true end}end}
check(runtime.position()==origin and runtime.casting()==true,'method-style player access supported')
for _,bad in ipairs({0/0,math.huge,-math.huge})do
 check(L.clip('sample',bad)=='','invalid clipping count handled')
 check(L.fit('sample',bad,0,13)=='','invalid GUI width handled')
 check(not L.set_font(bad),'invalid font handle rejected')
end
core.graphics={get_text_width=function()return 0/0 end}
check(L.fit('abcdef',40,0,13)=='ab...','invalid native measurement uses bounded fallback')
io.write(string.format('%d navigation and host-failure checks passed.\n',checks))
