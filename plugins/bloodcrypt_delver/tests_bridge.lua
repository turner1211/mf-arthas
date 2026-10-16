local Bridge=require("bc_bridge")
local passed=0
local function test(name,fn) fn();passed=passed+1;print("PASS "..name) end
local now=0;local sent
local b=Bridge.new({now=function() return now end,identity=function() return "Tester-Realm" end,send=function(s,kind,target) assert(kind=="WHISPER" and target=="Tester-Realm");sent=s;return true end})
b:request(8,2952);local token=b.token
local function receive(payload,recipient) return b:event("CHAT_MSG_WHISPER_INFORM",{payload,recipient or "Tester-Realm"}) end
local function line(kind,...) local f={"BCDV1",kind,token,1,...};for i=1,#f do f[i]=tostring(f[i]) end;return table.concat(f,"|") end
test("protocol accepts only own outgoing whisper responses",function()
 assert(not b:event("CHAT_MSG_WHISPER",{line("P",2952,8,1,"Ready"),"Tester-Realm"}))
 assert(not receive(line("P",2952,8,1,"Ready"),"Other-Realm"))
end)
test("tier acknowledgement binds exact instance and tier",function()
 assert(receive(line("P",2952,8,1,"Ready")));assert(b:tier_ready(2952,8));assert(not b:tier_ready(3003,8));assert(not b:tier_ready(2952,9))
end)
test("partial scenario data stays unpublished",function()
 assert(receive(line("S",2952,123,456,1,"Objective")));assert(receive(line("Z"))==false);assert(b:current(2952)==nil)
end)
test("complete criterion transaction publishes atomically",function()
 assert(receive(line("C",1,789,1,1,1,0,"Test objective")));assert(receive(line("Z")))
 assert(b:criterion(2952,456,789).complete);assert(b:criterion(2952,457,789)==nil)
end)
test("scenario metadata preserves spells and timed criteria",function()
 assert(receive(line("S",2952,123,456,1,"Objective")))
 assert(receive(line("G",3,9,17,"Labyrinth of Kindo'jan")))
 assert(receive(line("F","1288103,1288125")))
 assert(receive(line("H",0,0,1,0,42,9001,77,"Use the scenario action")))
 assert(receive(line("A",1,1288125,12345,"Echo of Ula'tek")))
 assert(receive(line("C",1,789,2,5,0,0,"Activate devices")))
 assert(receive(line("Q",1,8,4,99,30,12,0,1,"2 / 5")))
 assert(receive(line("Z")));local s=b:current(2952)
 assert(s.current_step_only and s.weighted_progress==42 and s.reward_quest_id==9001 and s.widget_set_id==77)
 assert(s.current_stage==3 and s.num_stages==9 and s.scenario_flags==17 and s.scenario_name=="Labyrinth of Kindo'jan")
 assert(#s.active_affixes==2 and s.active_affixes[1]==1288103 and s.active_affixes[2]==1288125)
 assert(s.spells[1].id==1288125 and s.criteria[1].duration==30 and s.criteria[1].elapsed==12 and s.criteria[1].quantity_string=="2 / 5")
end)
test("expired snapshots and tier acknowledgements are rejected",function() now=21;assert(b:current(2952)==nil);assert(not b:tier_ready(2952,8));now=0 end)
test("new request invalidates earlier token responses",function()
 b:request();assert(not receive(line("P",2952,8,1,"Ready")));token=b.token
end)
test("BigWigs callback diagnostics use the bridge",function()
 assert(receive(line("W",1,1,7,"BigWigs_OnBossWin")));assert(b.wigs.bigwigs and b.wigs.littlewigs and b.wigs.events==7)
end)
test("verified delve UI actions are accepted",function()
 assert(receive(line("U","gossip",137580,"Mirror story")));assert(b.ui_action.kind=="gossip" and b.ui_action.id==137580)
 assert(receive(line("U","power",42,"Delve power")));assert(b.ui_action.kind=="power" and b.ui_action.id==42)
end)
test("active delve tier metadata is bounded and fresh",function()
 assert(receive(line("D",1,8,208,2,17,1)));local d=b:delve_state();assert(d.active and d.tier==8 and d.difficulty_id==208 and d.season==2 and d.companion_id==17 and d.reward_eligible)
 assert(receive(line("D",1,8,208,2,17)));assert(b:delve_state().reward_eligible==false,"an older bridge must fail closed for key spending")
 now=21;assert(b:delve_state()==nil);now=0
end)
test("LittleWigs timer bars use the native BigWigs reader once",function()
 local calls=0;local api={addons={bigwigs={is_loaded=function() return true end,get_bars=function() calls=calls+1;return {{key=999,text="|cffffffffMechanic|r",remaining=2,duration=5,is_emphasized=true}} end}}}
 local wigs=require("bc_wigs");local rows=wigs.scan(api,true);assert(calls==1 and rows[1].text=="Mechanic" and rows[1].remaining==2 and rows[1].key==999)
 wigs.scan(api,false);assert(calls==1)
end)
test("WoW bridge rejects foreign requests and selects an eligible tier",function()
 local frame={events={}};local handler;local ticker;local selected;local outgoing={};local callbacks={}
 _G.CreateFrame=function() return frame end
 function frame:RegisterEvent(e) self.events[e]=true end
 function frame:SetScript(_,fn) handler=fn end
 _G.C_Timer={NewTicker=function(_,fn) ticker=fn;return {} end,After=function(_,fn) fn() end}
 _G.UnitFullName=function() return "Tester","Realm" end;_G.UnitName=function() return "Tester" end
 _G.UnitClass=function() return "Rogue","ROGUE",4 end
 _G.C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return 259,"Assassination","",0,"DAMAGER" end}
 _G.GetNormalizedRealmName=function() return "Realm" end;_G.GetTime=function() return now end
 _G.GetInstanceInfo=function() return "Delve","scenario",0,0,0,0,0,2952 end
 _G.C_ScenarioInfo={GetScenarioInfo=function() return {scenarioID=123,currentStage=3,numStages=9,flags=17,name="Labyrinth"} end,GetScenarioStepInfo=function() return {stepID=456,numCriteria=1,title="Objective",description="Do it",spells={{spellID=1288125,name="Echo",icon=12}}} end,GetCriteriaInfo=function() return {criteriaID=789,quantity=1,totalQuantity=1,completed=true,failed=false,description="Test",duration=10,elapsed=2} end,GetTieredEntranceActiveSpells=function() return {1288103,1288125} end}
 _G.InCombatLockdown=function() return false end;_G.Enum={TieredEntranceType={Delve=1}}
 _G.C_DelvesUI={GetDelveEntranceMapID=function() return 2952 end,IsDelveEntranceTierEnabled=function() return true end,HasActiveDelve=function() return true end,GetActiveDelveTier=function() return {tier=8,difficultyID=208} end,GetCurrentDelvesSeasonNumber=function() return 2 end,GetCompanionInfoForActivePlayer=function() return 17 end,IsEligibleForActiveDelveRewards=function(unit) assert(unit=="player");return true end}
 _G.C_AddOns={IsAddOnLoaded=function(name) return name=="LittleWigs" end}
 _G.C_GossipInfo={GetOptions=function() return {{gossipOptionID=137580,name="Use the mirrors"}} end,SelectOption=function(id) assert(id==137580) end}
 _G.C_PlayerChoice={GetCurrentPlayerChoiceInfo=function() return {options={{spellID=123,header="Power",buttons={{id=44}}}}} end,SendPlayerChoiceResponse=function(id) assert(id==44) end,OnUIClosed=function() end}
 local picker={entranceType=1,DelveRewardsContainerFrame={SetRewards=function() end},Dropdown={Update=function() end}}
 function picker:IsShown() return true end;function picker:GetTierInfos() return {{tier=8,unlocked=true}} end
 function picker:SetSelectedTierInfo(r) selected=r end;function picker:GetSelectedTierInfo() return selected end
 function picker:UpdateWidgets() end;function picker:UpdatePortalButtonState() end;function picker:CanEnterDelve() return selected~=nil end
 _G.DelvesDifficultyPickerFrame=picker
 _G.BigWigsLoader={RegisterMessage=function(receiver,event,fn) assert(receiver~=BigWigsLoader);callbacks[event]=fn end}
 _G.SendChatMessage=function(text,kind,lang,target) assert(kind=="WHISPER" and target=="Tester-Realm");outgoing[#outgoing+1]=text end
 local test_source=debug.getinfo(1,"S").source:gsub("^@","")
 local test_dir=test_source:match("^(.*[/\\])") or ""
 local bridge=dofile(test_dir.."WoW_BloodcryptBridge.lua")
 handler(frame,"CHAT_MSG_WHISPER","BCDV1|T|test|8|2952","Other-Realm");assert(not selected)
 handler(frame,"CHAT_MSG_WHISPER","BCDV1|T|test|8|2952","Tester-Realm");assert(selected and selected.tier==8)
 callbacks.BigWigs_StartBar("BigWigs_StartBar",{displayName="Azta'rec"},1288125,"Echo of Ula'tek",5);assert(bridge.bigwigs_events==1 and bridge.last_bigwigs_event:find("1288125",1,true))
 callbacks.BigWigs_PauseBar("BigWigs_PauseBar",{displayName="Azta'rec"},1288125,"Echo of Ula'tek",5);assert(bridge.bigwigs_events==2 and bridge.last_bigwigs_event:find("BigWigs_PauseBar",1,true))
 callbacks.BigWigs_SetStage("BigWigs_SetStage",{displayName="Azta'rec"},2);assert(bridge.bigwigs_events==3 and bridge.last_bigwigs_event:find("BigWigs_SetStage",1,true) and bridge.last_bigwigs_event:find(":2:",1,true))
 handler(frame,"GOSSIP_SHOW");assert(bridge.last_ui_action=="gossip:137580")
 handler(frame,"PLAYER_CHOICE_UPDATE");assert(bridge.last_ui_action=="power:44")
  for i=1,9 do ticker() end
 local picker_seen=false;for _,message in ipairs(outgoing) do if message:match("^BCDV1|P|test|1|2952|8|1|Ready$") then picker_seen=true end end;assert(picker_seen)
 assert(frame.events.CHAT_MSG_WHISPER and callbacks.BigWigs_StartBar and callbacks.BigWigs_PauseBar and callbacks.BigWigs_ResumeBar and callbacks.BigWigs_SetStage and callbacks.BigWigs_OnBossEngageMidEncounter)
 local saved=selected;now=3;handler(frame,"CHAT_MSG_WHISPER","BCDV1|T|other|8|3003","Tester-Realm");assert(selected==saved)
 now=6;_G.C_Map={GetBestMapForUnit=function() return 2502 end};C_ScenarioInfo.GetScenarioStepInfo=function() local spells={};for i=1,16 do spells[i]={spellID=1200000+i,name="Spell "..i,icon=i} end;return {stepID=456,numCriteria=64,title="Maximum transaction",description="Stress",spells=spells} end
 C_ScenarioInfo.GetCriteriaInfo=function(i) return {criteriaID=700000+i,quantity=i,totalQuantity=64,completed=false,failed=false,description="Criterion "..i,duration=0,elapsed=0} end
 C_ScenarioInfo.GetScenarioIconInfo=function() local pins={};for i=1,32 do pins[i]={x=i/100,y=i/100,atlas="poi",description="Pin "..i} end;return pins end
 handler(frame,"CHAT_MSG_WHISPER","BCDV1|R|max|0|2952","Tester-Realm");assert(#bridge.queue>128 and #bridge.queue<256,"maximum documented snapshot must fit the bounded queue");assert(bridge.queue[#bridge.queue]:match("^BCDV1|Z|max|"),"maximum snapshot must retain its atomic commit marker")
end)
test("DVE3 preserves exact scenario criterion routing",function()
 local Routes=require("bc_routes");local r={name="Test",variant="Story",map=2952,instance=2952,entrance_map=0,entrance={x=1,y=2,z=3},scenario_id=123,steps={{kind="interact",position={x=4,y=5,z=6},object_id=1,confirm="criterion",stage_id=456,criterion_id=789}}}
 r.entrance_map=1;local q=assert(Routes.decode(Routes.encode(r)));assert(q.scenario_id==123 and q.steps[1].stage_id==456 and q.steps[1].criterion_id==789)
end)
print(passed.." bridge/BigWigs checks passed")
