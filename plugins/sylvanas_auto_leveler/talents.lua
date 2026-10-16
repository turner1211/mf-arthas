-- Retail trait purchases: select available ranks, then verify the committed state.
local Catalog=require("talent_builds")
local Plan=require("talent_plan")
local M={}
function M.new(api,log,profile)
 local self={next=0,nodes={},refresh=0,failed={},refusals={},read_failures={}}
 local function emit(e,f) if log then log(e,f) end end
 local function read(name,fn,fallback,...)
  if type(fn)~="function" then return fallback end
  local ran,result=pcall(fn,...)
  if ran then return result end
  local now=api.time()
  if now>=(self.read_failures[name] or 0) then
   self.read_failures[name]=now+10;emit("talent_api_read_failed",{operation=name,error=tostring(result)})
  end
  return fallback
 end
 local function input(name,fn,...)
  if type(fn)~="function" then return false end
  local ran,result=pcall(fn,...)
  if not ran or result==false then
   emit("talent_api_input_failed",{operation=name,error=not ran and tostring(result) or nil})
   return false
  end
  return true
 end
 local function specialization() return read("specialization",api.spec,0) or 0 end
 local function emit_plan(e,fields)
  local signature=table.concat({e,tostring(fields.spec),tostring(fields.variant),tostring(fields.reason)},"|")
  if signature~=self.plan_diagnostic then self.plan_diagnostic=signature;emit(e,fields) end
 end
 function self:event(event)
  if event=="TRAIT_CONFIG_LIST_UPDATED" or event=="TRAIT_CONFIG_UPDATED" or event=="TRAIT_NODE_CHANGED"
   or event=="PLAYER_TALENT_UPDATE" or event=="ACTIVE_TALENT_GROUP_CHANGED" then
   -- The live node list can be incomplete during login. Rebuild immediately when
   -- Blizzard announces that trait data or the active loadout changed.
   self.refresh=0;self.next=0;self.identity=nil;self.checked_plan=nil;self.plan_diagnostic=nil
   if event=="ACTIVE_TALENT_GROUP_CHANGED" then
    self.failed={};self.refusals={}
   end
  end
 end
 local function refuse(id,now,event)
  self.refusals[id]=(self.refusals[id] or 0)+1
  local delay=math.min(300,30*2^math.min(4,self.refusals[id]-1))
  self.failed[id]=now+delay;emit(event,{node=id,retry_seconds=delay,refusals=self.refusals[id]})
 end
 function self:tick()
  local p=api.player();local now=api.time()
  if profile and profile.auto_talents==false or not p or not p:is_valid() or p:is_dead() or p:is_ghost() or p:is_in_combat() or p:is_casting_spell() or p:is_channelling_spell() then return end
  local ui=api.ui
  if not ui.get_talent_tree_ids or not ui.get_talent_tree_nodes or not ui.get_talent_node_info or not ui.can_purchase_talent_rank or not ui.learn_talent then return end
  if self.pending then
   local job=self.pending
   if job.spec~=specialization() then
    emit("talent_purchase_invalidated",{node=job.id,reason="specialization_changed"})
    self.pending=nil;self.next=0;self.refresh=0;self.identity=nil;self.checked_plan=nil
    return
   end
   local info=read("node_info",ui.get_talent_node_info,nil,job.id)
   if info and (info.ranks_purchased or info.active_rank or 0)>job.rank then
    emit("talent_purchase_confirmed",{node=job.id,entry=job.entry});self.pending=nil;self.next=now+0.5;self.refusals[job.id]=nil;self.failed[job.id]=nil
   elseif now>=job.deadline then
    self.pending=nil;refuse(job.id,now,"talent_purchase_timeout")
   end
   return
  end
  if now<self.next then return end
  self.next=now+1
  local spec=specialization()
  local identity=tostring(p:get_class())..":"..tostring(spec)..":"..tostring(p:get_level())
  if identity~=self.failure_identity then self.failure_identity=identity;self.failed={};self.refusals={} end
  if identity~=self.identity or now>=self.refresh then
   self.identity=identity;self.refresh=now+30;self.nodes={};local seen={}
   for _,tree in ipairs(read("tree_ids",ui.get_talent_tree_ids,{}) or {}) do
    for _,id in ipairs(read("tree_nodes",ui.get_talent_tree_nodes,{},tree) or {}) do if not seen[id] then seen[id]=true;self.nodes[#self.nodes+1]=id end end
   end
   table.sort(self.nodes)
   local explicit=profile and profile.talent_order
   if explicit and #explicit>0 then
    self.plan={}
    for _,row in ipairs(explicit) do local id=type(row)=="table" and row.node_id or row;if seen[id] then
     local node=read("node_info",ui.get_talent_node_info,nil,id)
     self.plan[#self.plan+1]={node_id=id,entry_id=type(row)=="table" and row.entry_id or nil,target_rank=type(row)=="table" and row.target_rank or node and node.max_ranks}
    end end
   else
    local build=Catalog[spec];self.plan=nil
    if profile and profile.game_version=="Forever" then
     -- Forever's trait node ids differ from Retail and can change during beta.
     -- Build a live, deterministic plan from the actual tree rather than using
     -- stale Retail ids. Availability/prerequisites remain authoritative.
     self.plan={}
     for _,id in ipairs(self.nodes) do
      local node=read("node_info",ui.get_talent_node_info,nil,id)
      if node and node.is_visible and (node.max_ranks or 0)>0 then
       local entry=(node.node_type==2 or node.node_type==3) and ((node.entry_ids or {})[1]) or nil
       self.plan[#self.plan+1]={node_id=id,entry_id=entry,target_rank=node.max_ranks}
      end
     end
     emit_plan("talent_forever_live_plan",{spec=spec,source="live_trait_tree",variant="deterministic",reason=nil})
    elseif build then
     local variant=build.builds[profile and profile.talent_variant or build.default]
     if variant then self.plan,self.plan_error=Plan.decode(variant.code,spec,self.nodes,function(id) return read("node_info",ui.get_talent_node_info,nil,id) end,{tolerant=true}) end
     local skipped=self.plan and self.plan.skipped and #self.plan.skipped or 0
     emit_plan(self.plan and (skipped>0 and "talent_build_partially_selected" or "talent_build_selected") or "talent_build_unresolved",{spec=spec,source=build.source,variant=variant and variant.label,reason=self.plan_error,hash_unverified=self.plan and self.plan.hash_unverified,skipped=skipped})
    else emit_plan("talent_build_unavailable",{spec=spec}) end
   end
  end
  if self.plan and self.checked_plan~=self.plan then
   self.checked_plan=self.plan;local wanted={}
   for _,row in ipairs(self.plan) do wanted[row.node_id]=row end
   for _,id in ipairs(self.nodes) do
    local info=read("node_info",ui.get_talent_node_info,nil,id);local row=wanted[id]
    if info and (info.ranks_purchased or 0)>0 and (not row or info.ranks_purchased>(row.target_rank or info.max_ranks or 0)
      or row.entry_id and info.active_entry_id and info.active_entry_id>0 and row.entry_id~=info.active_entry_id) then
     emit("talent_existing_build_differs",{node=id,rank=info.ranks_purchased,wanted_rank=row and row.target_rank or 0})
    end
   end
  end
  for _,row in ipairs(self.plan or {}) do
   local id=row.node_id
   local info=read("node_info",ui.get_talent_node_info,nil,id)
   if info and info.is_available and info.is_visible and (info.ranks_purchased or info.active_rank or 0)<math.min(info.max_ranks or 0,row.target_rank or info.max_ranks or 0) and now>=(self.failed[id] or 0) then
    local entry=(info.node_type==2 or info.node_type==3) and row.entry_id or nil
    if info.node_type==2 or info.node_type==3 then
     entry=entry or info.active_entry_id and info.active_entry_id>0 and info.active_entry_id or (info.entry_ids or {})[1]
     for _,row in ipairs(profile and profile.talent_order or {}) do if type(row)=="table" and row.node_id==id and row.entry_id then entry=row.entry_id end end
    end
    if entry and (info.ranks_purchased or 0)>0 and info.active_entry_id and info.active_entry_id>0 and info.active_entry_id~=entry then
     emit("talent_existing_choice_conflict",{node=id,wanted_entry=entry,existing_entry=info.active_entry_id});self.failed[id]=now+30
    elseif ((info.node_type~=2 and info.node_type~=3) or entry) and read("can_purchase",ui.can_purchase_talent_rank,false,id,entry) then
     if input("learn_talent",ui.learn_talent,id,entry) then
      self.pending={id=id,entry=entry,rank=info.ranks_purchased or info.active_rank or 0,deadline=now+5,spec=spec}
      emit("talent_purchase_requested",{node=id,entry=entry,spec=spec})
     else refuse(id,now,"talent_purchase_refused") end
     return
    end
   end
  end
 end
 return self
end
return M
