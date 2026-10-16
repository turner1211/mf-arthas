-- Briefly defers our interrupt after a friendly player's interrupt request so
-- the client can update cast state and avoid two allies spending stops together.
local M={}
local recent={}
local interrupts={
 [96231]=true,[1766]=true,[6552]=true,[2139]=true,[57994]=true,[106839]=true,
 [116705]=true,[47528]=true,[183752]=true,[351338]=true,[147362]=true,
 [187707]=true,[15487]=true,[78675]=true,[31935]=true,[205109]=true,
}
function M.reset() recent={} end
function M.observe(data,n,h)
 if type(data)~='table' or not interrupts[tonumber(data.spell_id)] or not data.caster or not data.target then return end
 if h.same(data.caster,h.player) or h.enemy(data.caster) then return end
 local key=h.guid(data.target);if key then recent[tostring(key)]=n+0.22 end
end
function M.defer(unit,n,guid)
 local key=unit and guid(unit);local until_time=key and recent[tostring(key)] or nil
 if not until_time then return false end
 if n>=until_time then recent[tostring(key)]=nil;return false end
 return true,until_time-n
end
return M
