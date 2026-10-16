local Data=require("bg_route_data")
local C={};C.__index=C
local channels={CHAT_MSG_INSTANCE_CHAT=true,CHAT_MSG_INSTANCE_CHAT_LEADER=true,
 CHAT_MSG_BATTLEGROUND=true,CHAT_MSG_BATTLEGROUND_LEADER=true}
local aliases={
 arathi={blacksmith="bs",bs="bs",farm="farm",fm="farm",stables="st",stable="st",st="st",
  lumbermill="lm",["lumber mill"]="lm",lm="lm",goldmine="gm",["gold mine"]="gm",gm="gm",mine="gm"},
 gilneas={mine="mine",mines="mine",gm="mine",["gold mine"]="mine",waterworks="ww",["water works"]="ww",works="ww",ww="ww",lighthouse="lh",lh="lh"},
 deepwind_modern={quarry="quarry",qua="quarry",q="quarry",market="market",mid="market",middle="market",
  shrine="shrine",shirine="shrine",farm="farm",fm="farm",ruins="ruins",ruin="ruins"},
 seething={west="west",western="west",east="east",eastern="east",north="north",northern="north",
  mid="south_mid",middle="south_mid",south="south_mid"},
 eye_standard={mid="flag",middle="flag",flag="flag",["mage tower"]="mt",mt="mt",
  ["draenei ruins"]="dr",["draenei ruin"]="dr",dr="dr",["fel reaver"]="fr",fr="fr",
  ["blood elf"]="be",["blood elf tower"]="be",bt="be",be="be"}
}
local inherit={arathi_blitz="arathi",arathi_training="arathi",arathi_comp_stomp="arathi",
 gilneas_training="gilneas",deepwind_blitz="deepwind_modern",eye_blitz="eye_standard",eye_blitz_legacy="eye_standard"}
local function normalize(text)
 return " "..tostring(text or ""):lower():gsub("[^%w%s']"," "):gsub("%s+"," ").." "
end
local function contains(text,phrase) return text:find(" "..phrase.." ",1,true)~=nil end
local function location_map(profile)
 local key=inherit[profile] or profile;local out={}
 for phrase,id in pairs(aliases[key] or {}) do out[phrase]=id end
 local graph=Data[profile]
 for id in pairs(graph and graph.nodes or {}) do
  local phrase=tostring(id):lower():gsub("_"," ")
  if not phrase:find("spawn",1,true) and not phrase:find("exit",1,true) and
   not phrase:find("road",1,true) and not phrase:find("turn",1,true) and
   not phrase:find("slope",1,true) then
   out[phrase]=id
  end
 end
 return out,graph
end
function C.new() return setmetatable({active_rows={},seen={},seen_count=0},C) end
function C:reset() self.active_rows={};self.seen={};self.seen_count=0 end
local function remember(self,signature,now)
 if self.seen[signature]==nil then self.seen_count=(self.seen_count or 0)+1 end
 self.seen[signature]=now
 if self.seen_count<=256 then return end
 local kept,count={},0
 for key,at in pairs(self.seen) do
  if type(at)=="number" and now>=at and now-at<60 then kept[key]=at;count=count+1 end
 end
 self.seen,self.seen_count=kept,count
end
function C:ingest(event,args,profile,role,now)
 if not channels[event] or (role~="damage" and role~="tank") or type(args)~="table" or type(args[1])~="string" then return end
 local text=normalize(args[1])
 local map,graph=location_map(profile)
 if not map or not graph then return end
 local best_id,best_len
 for phrase,id in pairs(map) do
  if contains(text,phrase) and (not best_len or #phrase>best_len) then best_id,best_len=id,#phrase end
 end
 local point=best_id and graph.nodes and graph.nodes[best_id]
 if not point then return end
 local clearing=contains(text,"clear") or contains(text,"safe") or contains(text,"nvm") or contains(text,"nevermind")
 local active_key=tostring(profile)..":"..best_id
 if clearing then
  if self.active_rows[active_key] then self.active_rows[active_key]=nil;return {cleared=true,id=best_id} end
  return
 end
 if not (contains(text,"inc") or contains(text,"incoming") or contains(text,"help") or contains(text,"defend") or
  contains(text,"def") or contains(text,"attack") or contains(text,"go") or contains(text,"need") or
  contains(text,"push") or contains(text,"take") or contains(text,"cap") or contains(text,"capture")) then return end
 local signature=tostring(profile)..":"..best_id..":"..tostring(args[2] or ""):lower()..":"..text
 if self.seen[signature] and now-self.seen[signature]<2 then return end
 remember(self,signature,now)
 local count=tonumber(text:match(" (%d+) "));if count then count=math.max(1,math.min(15,count)) end
 local defensive=contains(text,"inc") or contains(text,"incoming") or contains(text,"help") or
  contains(text,"defend") or contains(text,"def") or contains(text,"need")
 local prior=self.active_rows[active_key]
 local sender_key=tostring(args[2] or ""):lower()
 local senders={};local confirmations=1
 if prior and now<prior.expires then
  for key,value in pairs(prior.senders or {}) do senders[key]=value end
  confirmations=prior.confirmations or 1
  -- Rewording the same location from one sender must not continuously refresh
  -- or inflate the command. A later update is allowed because battle state can
  -- genuinely change, while separate teammates corroborate immediately.
  if sender_key~="" and senders[sender_key] and now-(prior.received or 0)<8 then return prior end
 end
 if sender_key~="" and not senders[sender_key] then
  senders[sender_key]=true
  if prior and now<prior.expires then confirmations=math.min(5,confirmations+1) end
 end
 local row={profile=profile,id=best_id,position={x=point.x,y=point.y,z=point.z},message=args[1],sender=args[2],received=now,
  intent=defensive and "defense" or "offense",enemy_count=count,confirmations=confirmations,senders=senders,
  expires=now+math.min(32,22+(count or 0))}
 self.active_rows[active_key]=row
 return row
end
function C:active(profile,role,now)
 if role~="damage" and role~="tank" then return nil end
 local best,best_score
 for key,row in pairs(self.active_rows) do
  if now>=row.expires then self.active_rows[key]=nil
  elseif row.profile==profile then
   local score=(row.enemy_count or 1)*10+math.min(4,(row.confirmations or 1)-1)*12+(row.received or 0)*0.001
   if not best_score or score>best_score then best,best_score=row,score end
  end
 end
 return best
end
function C:apply(snapshot,profile,now)
 local row=self:active(profile,snapshot.player_role,now)
 if not row then return snapshot end
 local out={};for key,value in pairs(snapshot) do out[key]=value end
 out.callout_position={x=row.position.x,y=row.position.y,z=row.position.z}
 out.callout_id=row.id;out.callout_message=row.message;out.callout_sender=row.sender
 out.callout_intent=row.intent;out.callout_enemy_count=row.enemy_count
 out.callout_confirmations=row.confirmations;out.callout_expires_at=row.expires
 return out
end
return C
