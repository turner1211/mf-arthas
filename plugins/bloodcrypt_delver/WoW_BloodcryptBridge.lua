-- Execute ONCE in WoW's addon Lua environment through an existing addon loader.
-- This is not a Sylvanas module. It never controls movement or enters an instance.
if _G.BloodcryptWoWBridge then return _G.BloodcryptWoWBridge end
assert(type(CreateFrame)=="function" and C_Timer,"Load this Lua through a WoW addon loader")
local B={queue={},sequence=0,last_request=-100,last_push=-100,refresh_at=nil,bigwigs_events=0};_G.BloodcryptWoWBridge=B
local frame=CreateFrame("Frame");B.frame=frame
local DELVE_INSTANCES={[2933]=true,[2952]=true,[2953]=true,[2961]=true,[2962]=true,[2963]=true,[2964]=true,[2965]=true,[2966]=true,[2979]=true,[3003]=true,[3038]=true,[3043]=true,[3077]=true,[3079]=true}
-- Exact Midnight delve choices maintained by LittleWigs. Abundance/resource gossip is intentionally excluded.
local DELVE_GOSSIP={[136318]=true,[136385]=true,[136317]=true,[138496]=true,[140366]=true,[135708]=true,[135865]=true,[135798]=true,[138592]=true,[139635]=true,[139585]=true,[139462]=true,[136477]=true,[134669]=true,[136446]=true,[141655]=true,[134949]=true,[136275]=true,[136279]=true,[136086]=true,[138009]=true,[138317]=true,[136141]=true,[141485]=true,[137248]=true,[137389]=true,[134668]=true,[137619]=true,[137580]=true,[135239]=true,[135634]=true,[135811]=true,[138141]=true}
local function identity()
 local name,realm=UnitFullName("player");realm=realm or GetNormalizedRealmName()
 return name.."-"..realm
end
local function self_sender(sender)
 if type(sender)~="string" then return false end
 local full=identity():lower():gsub("%s","");local value=sender:lower():gsub("%s","")
 return value==full or (not value:find("-",1,true) and value==UnitName("player"):lower())
end
local function clean(v) return (tostring(v or ""):gsub("[|\r\n]"," "):sub(1,90)) end
local function enqueue(kind,token,...)
 local f={"BCDV1",kind,token,B.sequence,...};for i=1,#f do f[i]=clean(f[i]) end
 local s=table.concat(f,"|");if #s>255 then s=s:sub(1,255) end
 if #B.queue<256 then B.queue[#B.queue+1]=s end
end
local function enqueue_priority(kind,token,...)
 local before=#B.queue;enqueue(kind,token,...)
 if #B.queue>before then table.insert(B.queue,1,table.remove(B.queue)) end
end
local POI={
 [2952]={2395,8438,8437},[2933]={2393,8426,8425},[2953]={2424,8428,8427},[3003]={2393,8440,8439},
 [2961]={2437,8442,8441},[2962]={2437,8444,8443},[2963]={2413,8434,8433},[2964]={2413,8436,8435},
 [2965]={2405,8430,8429},[2979]={2405,8432,8431},[3077]={2512,8763,8764},[3038]={2512,8760,8761},
}
local function poi_story(expected)
 local ids=POI[expected]
 if not ids or not C_AreaPoiInfo or not C_UIWidgetManager or not Enum or not Enum.UIWidgetVisualizationType then return nil end
 for i=2,3 do
  local ok,poi=pcall(C_AreaPoiInfo.GetAreaPOIInfo,ids[1],ids[i])
  if ok and poi and poi.tooltipWidgetSet then
   local widgets=C_UIWidgetManager.GetAllWidgetsBySetID(poi.tooltipWidgetSet)
   for _,info in ipairs(widgets or {}) do
    if info.widgetType==Enum.UIWidgetVisualizationType.TextWithState then
     local viz=C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo(info.widgetID)
     if viz and viz.orderIndex==0 and type(viz.text)=="string" and viz.text~="" then
      return viz.text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):gsub("^[Vv]ariant:%s*",""):match("^%s*(.-)%s*$")
     end
    end
   end
  end
 end
end
local function capture(token,expected)
 local getSpec=C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization
 local getInfo=C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo or GetSpecializationInfo
 local className,_,classID=UnitClass("player")
 local specIndex=getSpec and getSpec()
 if specIndex and getInfo then
  local specID,specName,_,_,role=getInfo(specIndex)
  enqueue("I",token,classID or 0,specID or 0,role or "NONE",className,specName)
 end
 local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
 enqueue("W",token,BigWigsLoader and 1 or 0,loaded and loaded("LittleWigs") and 1 or 0,B.bigwigs_events,B.last_bigwigs_event or "")
 local hasActive=C_DelvesUI and C_DelvesUI.HasActiveDelve and C_DelvesUI.HasActiveDelve()
 local activeTier=hasActive and C_DelvesUI.GetActiveDelveTier and C_DelvesUI.GetActiveDelveTier() or nil
 local season=C_DelvesUI and C_DelvesUI.GetCurrentDelvesSeasonNumber and C_DelvesUI.GetCurrentDelvesSeasonNumber() or 0
 local companion=C_DelvesUI and C_DelvesUI.GetCompanionInfoForActivePlayer and C_DelvesUI.GetCompanionInfoForActivePlayer() or 0
 local rewardEligible=false
 if hasActive and C_DelvesUI and C_DelvesUI.IsEligibleForActiveDelveRewards then local ok,value=pcall(C_DelvesUI.IsEligibleForActiveDelveRewards,"player");rewardEligible=ok and value==true end
 enqueue("D",token,hasActive and 1 or 0,activeTier and activeTier.tier or 0,activeTier and activeTier.difficultyID or 0,season or 0,companion or 0,rewardEligible and 1 or 0)
 local currency=C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(3028)
 local keyItems=C_Item and C_Item.GetItemCount and C_Item.GetItemCount(224172) or 0
 enqueue("J",token,currency and currency.quantity or 0,keyItems or 0)
 local story=poi_story(expected);if story then enqueue("K",token,expected,story) end
 local _,_,_,_,_,_,_,instance=GetInstanceInfo()
 local info=C_ScenarioInfo.GetScenarioInfo();local step=C_ScenarioInfo.GetScenarioStepInfo()
 local count=step and step.numCriteria or 0
 if count>64 then enqueue("E",token,"Scenario exceeds protocol limit");return end
 enqueue("S",token,instance or 0,info and info.scenarioID or 0,step and step.stepID or 0,count,step and step.title or "")
 if info then enqueue("G",token,info.currentStage or 0,info.numStages or 0,info.flags or 0,info.name or "") end
 local affixes=C_ScenarioInfo.GetTieredEntranceActiveSpells and C_ScenarioInfo.GetTieredEntranceActiveSpells() or {}
 local active={};for i=1,math.min(#(affixes or {}),32) do local id=tonumber(affixes[i]);if id and id>0 then active[#active+1]=math.floor(id) end end
 enqueue("F",token,table.concat(active,","))
 if step then
  enqueue("H",token,step.stepFailed and 1 or 0,step.isBonusStep and 1 or 0,step.isForCurrentStepOnly and 1 or 0,step.shouldShowBonusObjective and 1 or 0,step.weightedProgress or "",step.rewardQuestID or 0,step.widgetSetID or 0,step.description)
  for i=1,math.min(#(step.spells or {}),16) do local spell=step.spells[i];enqueue("A",token,i,spell.spellID or 0,spell.icon or 0,spell.name) end
 end
 local uiMap=C_Map and C_Map.GetBestMapForUnit("player")
 local pins=uiMap and C_ScenarioInfo.GetScenarioIconInfo and C_ScenarioInfo.GetScenarioIconInfo(uiMap) or {}
 -- Pins are objective evidence, not a guarantee of a traversable route.
 for i=1,math.min(#(pins or {}),32) do
  local pin=pins[i]
  enqueue("O",token,i,uiMap,pin.x,pin.y,pin.atlas,pin.description)
 end
 for index=1,count do
  local r=C_ScenarioInfo.GetCriteriaInfo(index)
  if not r then enqueue("E",token,"Criterion unavailable");return end
  enqueue("C",token,index,r.criteriaID,r.quantity,r.totalQuantity,r.completed and 1 or 0,r.failed and 1 or 0,r.description)
  enqueue("Q",token,index,r.criteriaType or 0,r.flags or 0,r.assetID or 0,r.duration or 0,r.elapsed or 0,r.isWeightedProgress and 1 or 0,r.isFormatted and 1 or 0,r.quantityString)
 end
 enqueue("Z",token)
end
local function in_supported_delve()
 local _,kind,_,_,_,_,_,instance=GetInstanceInfo();return kind=="scenario" and DELVE_INSTANCES[instance]==true
end
local function select_delve_gossip()
 if not in_supported_delve() or not C_GossipInfo or type(C_GossipInfo.GetOptions)~="function" or type(C_GossipInfo.SelectOption)~="function" then return end
 for _,option in ipairs(C_GossipInfo.GetOptions() or {}) do
  local id=option.gossipOptionID
  if DELVE_GOSSIP[id] then
   local ok,err=pcall(C_GossipInfo.SelectOption,id,"",false)
   if ok then B.last_ui_action="gossip:"..id;enqueue_priority("U","push","gossip",id,option.name or option.text or "") else enqueue_priority("E","push","Gossip selection failed: "..tostring(err)) end
   return
  end
 end
end
local function select_single_delve_power()
 if not in_supported_delve() or not C_PlayerChoice or type(C_PlayerChoice.GetCurrentPlayerChoiceInfo)~="function" or type(C_PlayerChoice.SendPlayerChoiceResponse)~="function" then return end
 local info=C_PlayerChoice.GetCurrentPlayerChoiceInfo();local options=info and info.options
 if type(options)~="table" or #options~=1 or not options[1].spellID or type(options[1].buttons)~="table" or #options[1].buttons~=1 then return end
 local button=options[1].buttons[1];if not button or not button.id then return end
 local ok,err=pcall(function() C_PlayerChoice.SendPlayerChoiceResponse(button.id);if type(C_PlayerChoice.OnUIClosed)=="function" then C_PlayerChoice.OnUIClosed() end end)
 if ok then B.last_ui_action="power:"..button.id;enqueue_priority("U","push","power",button.id,options[1].header or options[1].spellID) else enqueue_priority("E","push","Power selection failed: "..tostring(err)) end
end
local function select_tier(token,tier,expected)
 local f=DelvesDifficultyPickerFrame
 if not f or not f:IsShown() then enqueue("P",token,0,0,0,"Delve picker is not open");return end
 if InCombatLockdown() then enqueue("P",token,0,0,0,"Tier selection paused during combat");return end
 if f.entranceType~=Enum.TieredEntranceType.Delve then enqueue("P",token,0,0,0,"Picker is not a delve");return end
 local map=C_DelvesUI.GetDelveEntranceMapID()
 if map~=expected then enqueue("P",token,map,0,0,"Wrong delve entrance");return end
 local chosen
 for _,r in ipairs(f:GetTierInfos() or {}) do
  local eligible=C_DelvesUI.IsDelveEntranceTierEnabled(r.tier)
  if r.unlocked and eligible and (tier==0 or r.tier==tier) and (not chosen or r.tier>chosen.tier) then chosen=r end
 end
 if not chosen then enqueue("P",token,map,0,0,"Requested tier is unavailable");return end
 local eligible,reason=C_DelvesUI.IsDelveEntranceTierEnabled(chosen.tier)
 if not eligible then enqueue("P",token,map,0,0,reason or "Tier is not eligible");return end
 -- Use the picker state methods verified in Blizzard's own implementation.
 f:SetSelectedTierInfo(chosen);f:UpdateWidgets();f.DelveRewardsContainerFrame:SetRewards();f:UpdatePortalButtonState()
 if f.Dropdown and f.Dropdown.Update then f.Dropdown:Update() end
 local selected=f:GetSelectedTierInfo();local ready=f:CanEnterDelve()
 enqueue("P",token,map,selected and selected.tier or 0,ready and 1 or 0,ready and "Ready" or "Picker cannot enter")
end
local function attach_bigwigs()
 if B.bigwigs_attached or not BigWigsLoader or type(BigWigsLoader.RegisterMessage)~="function" then return end
 for _,event in ipairs({"BigWigs_StartBar","BigWigs_StopBar","BigWigs_PauseBar","BigWigs_ResumeBar","BigWigs_SetStage","BigWigs_OnBossEngage","BigWigs_OnBossEngageMidEncounter","BigWigs_OnBossWin","BigWigs_OnBossWipe","BigWigs_OnBossDisable"}) do
  local event_name=event
  BigWigsLoader.RegisterMessage(B,event,function(message,module,key,text,duration)
   B.bigwigs_events=B.bigwigs_events+1
   local module_name=type(module)=="table" and (module.displayName or module.moduleName) or module
   B.last_bigwigs_event=table.concat({event_name,clean(module_name),clean(key),clean(text),clean(duration)},":")
  end)
 end
 B.bigwigs_attached=true
end
frame:RegisterEvent("CHAT_MSG_WHISPER");frame:RegisterEvent("ADDON_LOADED");frame:RegisterEvent("PLAYER_ENTERING_WORLD");frame:RegisterEvent("GOSSIP_SHOW");frame:RegisterEvent("PLAYER_CHOICE_UPDATE")
for _,event in ipairs({"SCENARIO_UPDATE","SCENARIO_CRITERIA_UPDATE","SCENARIO_CRITERIA_SHOW_STATE_UPDATE","SCENARIO_POI_UPDATE","SCENARIO_SPELL_UPDATE","SCENARIO_BONUS_OBJECTIVE_COMPLETE","SCENARIO_COMPLETED","ACTIVE_DELVE_DATA_UPDATE","WALK_IN_DATA_UPDATE"}) do pcall(frame.RegisterEvent,frame,event) end
frame:SetScript("OnEvent",function(_,event,text,sender)
 if event=="ADDON_LOADED" then attach_bigwigs();return end
 if event=="GOSSIP_SHOW" then C_Timer.After(0,select_delve_gossip);return end
 if event=="PLAYER_CHOICE_UPDATE" then C_Timer.After(0,select_single_delve_power);return end
 if event=="PLAYER_ENTERING_WORLD" or event=="ACTIVE_DELVE_DATA_UPDATE" or event=="WALK_IN_DATA_UPDATE" or event:match("^SCENARIO_") then B.refresh_at=GetTime()+.25;return end
 if not self_sender(sender) or type(text)~="string" or #text>255 then return end
 local kind,token,tier,instance=text:match("^BCDV1|([RT])|([%w_]+)|(%d+)|(%d+)$")
 if not kind or #token>48 or GetTime()-B.last_request<2 then return end
 tier=tonumber(tier);instance=tonumber(instance)
 if kind=="T" and (tier<0 or tier>100 or instance<1) then return end
 B.last_request=GetTime();B.sequence=B.sequence+1;B.queue={}
 local ok,err=pcall(function() if kind=="T" then select_tier(token,tier,instance) end;capture(token,instance) end)
 if not ok then B.queue={};enqueue("E",token,"Bridge API error: "..tostring(err)) end
end)
B.ticker=C_Timer.NewTicker(0.4,function()
 local now=GetTime()
 if #B.queue==0 and (B.refresh_at and now>=B.refresh_at or in_supported_delve() and now-B.last_push>=15) then
  B.refresh_at=nil;B.last_push=now;B.sequence=B.sequence+1
  local _,_,_,_,_,_,_,instance=GetInstanceInfo();local ok,err=pcall(capture,"push",instance or 0)
  if not ok then B.queue={};enqueue("E","push","Passive bridge error: "..tostring(err)) end
 end
 if #B.queue==0 then return end
 local message=table.remove(B.queue,1)
 local send=SendChatMessage or C_ChatInfo and C_ChatInfo.SendChatMessage
 if send then send(message,"WHISPER",nil,identity()) end
 if #B.queue==0 then B.last_push=GetTime() end
end)
-- Hide only this bridge's self-whisper lines in chat; other traffic is unaffected.
if ChatFrame_AddMessageEventFilter then
 local function filter(_,_,text,sender) return type(text)=="string" and text:match("^BCDV1|")~=nil and self_sender(sender) end
 ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER",filter)
 ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM",filter)
end
attach_bigwigs()
return B
