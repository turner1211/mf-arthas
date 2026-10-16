-- Persistent quest checkpoint outcomes, adapted from the battleground route store.
local M={};M.__index=M
local PATH="sylvanas_auto_leveler/quest_route_memory.txt"
local function safe(v) return tostring(v or "unknown"):gsub("[^%w_:%.%-]","_"):sub(1,180) end
local function checkpoint_signature(step)
    local out={}
    for _,point in ipairs(step.checkpoints or {}) do
        out[#out+1]=string.format("%.2f,%.2f",tonumber(point.x) or 0,tonumber(point.y) or 0)
    end
    return safe(table.concat(out,";"))
end
local function objective_signature(step)
    if step.objective_indices then
        local out={};for _,index in ipairs(step.objective_indices) do out[#out+1]=tostring(index) end
        return table.concat(out,",")
    end
    return tostring(step.objective_index or "all")
end
local function key(profile,step)
    -- A quest can contain multiple guide rows and objective areas. Keep their
    -- outcomes isolated, and invalidate old learning when authored points move.
    return table.concat({safe(profile),safe(step.quest_id or step.title),safe(step.source_index),
        safe(step.action),safe(objective_signature(step)),checkpoint_signature(step)},":")
end
function M.new(api,profile)
    local self=setmetatable({api=api or {},profile=profile or "unknown",rows={},dirty=false,sequence=0},M)
    local ok,text=false,nil
    if type(self.api.read)=="function" then ok,text=pcall(self.api.read,PATH) end
    if ok and type(text)=="string" then
        for line in text:gmatch("[^\r\n]+") do
            local k,index,successes,failures,last=line:match("^([^\t]+)\t(%d+)\t(%d+)\t(%d+)\t([%d%.%-]+)$")
            if k then
                local sequence=tonumber(last) or 0
                self.rows[k..":"..index]={successes=tonumber(successes) or 0,failures=tonumber(failures) or 0,last=sequence}
                self.sequence=math.max(self.sequence,sequence)
            end
        end
    end
    return self
end
function M:row(step,index)
    local id=key(self.profile,step)..":"..tostring(index)
    local row=self.rows[id] or {successes=0,failures=0,last=0};self.rows[id]=row
    return row,id
end
function M:choose(step,attempt)
    local points=step.checkpoints or {};if #points==0 then return nil end
    local fallback=(math.max(1,attempt or 1)-1)%#points+1
    local best,best_score,best_row
    for index=1,#points do
        local row=self:row(step,index)
        local score=row.successes*3-row.failures*2
        -- The attempt-based checkpoint wins equal scores. This preserves the
        -- original circuit order while allowing known failures to be avoided.
        local ranked=score+(index==fallback and .25 or 0)
        if not best_score or ranked>best_score then best,best_score,best_row=index,ranked,row end
    end
    local reason=(best_row.successes or 0)>0 and "proven_progress"
        or (best~=fallback and "avoiding_failed_checkpoint" or "circuit_rotation")
    return best,reason,best_score
end
function M:record(step,index,success)
    if not index then return end
    local row=self:row(step,index)
    if success then row.successes=math.min(9999,row.successes+1);row.failures=math.max(0,row.failures-1)
    else row.failures=math.min(9999,row.failures+1) end
    -- Session uptime resets on reload. A stored sequence preserves true update
    -- order so bounded retention does not evict fresh records after a restart.
    self.sequence=self.sequence+1;row.last=self.sequence;self.dirty=true;self:flush()
end
function M:flush()
    if not self.dirty then return true end
    if type(self.api.write)~="function" then return false end
    local records={}
    for id,row in pairs(self.rows) do records[#records+1]={id=id,row=row} end
    table.sort(records,function(a,b) return (a.row.last or 0)>(b.row.last or 0) end)
    local out={}
    for i=1,math.min(1000,#records) do
        local item=records[i];local base,index=item.id:match("^(.*):(%d+)$")
        if base and index then out[#out+1]=table.concat({base,index,item.row.successes,item.row.failures,item.row.last},"\t") end
    end
    local ok,result=pcall(self.api.write,PATH,table.concat(out,"\n")..(#out>0 and "\n" or ""))
    if ok and result~=false then self.dirty=false;return true end
    return false
end
function M:summary(step,index)
    local row=self:row(step,index);return {successes=row.successes,failures=row.failures,last=row.last}
end
return M
