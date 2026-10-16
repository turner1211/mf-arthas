local M={}
local healing_ids={[225979]=true,[243214]=true,[174269]=true}
local damage_ids={
    [30527]=true,[31144]=true,[46647]=true,
    [87317]=true,[87318]=true,[87320]=true,[87321]=true,[87322]=true,
    [88288]=true,[88314]=true,[194643]=true,
}
local function lower(value)return type(value)=="string" and value:lower() or "" end
local function contains(value,needle)return value:find(needle,1,true)~=nil end
local function fields(U,u)
    local name=lower(U.call(u,"get_name"))
    local title=lower(U.call(u,"get_title") or U.call(u,"get_sub_name")
        or U.call(u,"get_subname") or U.call(u,"get_unit_title"))
    return tonumber(U.call(u,"get_npc_id")),name,title
end
local function dummy_words(name,title)
    return contains(name,"training dummy") or contains(name,"training bag")
        or contains(name,"combat dummy") or contains(name,"tanking dummy")
        or contains(name,"target dummy") or contains(title,"training dummy")
        or contains(title,"dummy")
end
function M.kind(U,me,u)
    if not U.valid(u) or U.call(u,"is_player")==true then return nil end
    local npc,name,title=fields(U,u)
    local healing=healing_ids[npc] or contains(title,"healing")
        or contains(title,"healer") or contains(title,"healing trainer")
    local damage=damage_ids[npc] or dummy_words(name,title)
    if healing and U.call(u,"is_enemy_with",me)~=true then return "healing" end
    if damage and (U.call(u,"is_enemy_with",me)==true or U.call(me,"can_attack",u)==true) then
        return contains(title,"cleave") and "cleave" or "damage"
    end
    return nil
end
function M.is_healing(U,me,u)return M.kind(U,me,u)=="healing" end
function M.is_damage(U,me,u)
    local kind=M.kind(U,me,u);return kind=="damage" or kind=="cleave"
end
function M.is_cleave(U,me,u)return M.kind(U,me,u)=="cleave" end
return M
