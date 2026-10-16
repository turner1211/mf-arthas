local M={}

local ranged={ [62]=true,[63]=true,[64]=true,[102]=true,[253]=true,[254]=true,[258]=true,[262]=true,[265]=true,[266]=true,[267]=true,[1467]=true,[1473]=true,[1480]=true }

local function bracket(level)
 if level<10 then return "Initiate",1 end
 if level<20 then return "Apprentice",2 end
 if level<40 then return "Adventurer",3 end
 if level<60 then return "Veteran",4 end
 if level<80 then return "Champion",5 end
 return "Endgame",5
end

function M.get(character,options)
 character=character or {};options=options or {}
 local level=math.max(1,math.floor(tonumber(character.level) or 1))
 local name,pull=bracket(level);local role=character.role or "UNKNOWN";local spec=tonumber(character.spec_id) or 0
 if role=="TANK" then pull=pull+1 elseif role=="HEALER" then pull=math.max(1,pull-1) end
 local configured=math.max(1,math.floor(tonumber(options.max_pull) or 5))
 return {level=level,name=name,label="Level "..level.." / "..name,max_pull=math.min(configured,pull),approach_range=ranged[spec] and 25 or role=="HEALER" and 20 or 4.5,mount=level>=10,flying=level>=20,rotation=ranged[spec] and "RANGED" or role=="HEALER" and "HEALER" or "MELEE",role=role,spec_id=spec}
end

return M
