local F={};F.__index=F
local function position(value)
 local ok,x,y,z=pcall(function()return value.x,value.y,value.z end)
 if ok and type(x)=="number" and type(y)=="number" and type(z)=="number" then return{x=x,y=y,z=z}end
end
local function warsong_spawn_team(p)
 if not p then return nil end
 if p.x>=850 and p.x<=1105 and p.y>=1340 and p.y<=1510 and p.z>=315 then return 0 end
 if p.x>=1470 and p.x<=1605 and p.y>=1390 and p.y<=1560 and p.z>=330 then return 1 end
end
function F.new()return setmetatable({value=nil,source="unavailable",conflict=false},F)end
function F:reset()self.value=nil;self.source="unavailable";self.conflict=false end
function F:observe(profile,player_position,api_team,phase)
 api_team=(api_team==0 or api_team==1) and api_team or nil
 local geometric=profile=="warsong" and (phase==2 or self.value==nil) and warsong_spawn_team(position(player_position)) or nil
 if geometric~=nil then
  self.conflict=api_team~=nil and api_team~=geometric
  self.value=geometric;self.source=self.conflict and "warsong_spawn_override" or "warsong_spawn"
 elseif self.value==nil and api_team~=nil then self.value=api_team;self.source="battleground_api" end
 return self.value,self.source,self.conflict
end
function F:team()return self.value end
function F:report()return{team=self.value,source=self.source,conflict=self.conflict}end
return F
