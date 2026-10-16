-- MasterArthasNav: server fallback for client:get_height.
-- The bundled client asks the server for /height only when the game cannot
-- answer, and then expects "ok x y z". Every bridge answers "ok <z>" (ArthasNav
-- 2.2.5 and MasterArthasNav; Auto Leveler parses that form directly), so the
-- fallback always failed with bad_request "unexpected HTTP 200". When exactly
-- that failure comes back, ask /height again and read the single height.
local M={}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<1e7 end
local function base_url()
    local ok,cfg=pcall(require,"anav/config")
    if not ok or type(cfg)~="table" or type(cfg.base_url)~="string" then return nil end
    return (cfg.base_url:gsub("/+$",""))
end
local function parse_failure(ok,detail)
    return ok==false and type(detail)=="table" and detail.code=="bad_request" and detail.detail=="unexpected HTTP 200"
end
function M.query(p,done)
    local url=base_url()
    local ok_map,map=pcall(core.get_instance_id)
    if not url or not ok_map or type(map)~="number" or type(core.http_get)~="function"
        or not finite(p.x) or not finite(p.y) or not finite(p.z) then return done(false) end
    local answered=false
    local ok=pcall(core.http_get,string.format("%s/height?map=%d&x=%.3f&y=%.3f&z=%.3f",url,map,p.x,p.y,p.z),function(status,_,body)
        if answered then return end
        answered=true
        local z=status==200 and type(body)=="string" and tonumber(body:match("^ok%s+([%+%-%.%deE]+)%s*$")) or nil
        if finite(z) then done(true,z) else done(false) end
    end)
    if not ok and not answered then answered=true;done(false) end
end
function M.wrap(client)
    if type(client)~="table" or type(client.get_height)~="function" or rawget(client,"__master_height_fallback") then return false end
    local original=client.get_height
    client.get_height=function(self,p,cb,...)
        if type(cb)~="function" or type(p)~="table" then return original(self,p,cb,...) end
        return original(self,p,function(ok,z,detail,...)
            if not parse_failure(ok,detail) then return cb(ok,z,detail,...) end
            M.query(p,function(got,height)
                if got then cb(true,height,{code="ok"}) else cb(ok,z,detail) end
            end)
        end,...)
    end
    rawset(client,"__master_height_fallback",true)
    return true
end
return M
