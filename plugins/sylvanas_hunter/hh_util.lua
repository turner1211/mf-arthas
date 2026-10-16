local U={}
function U.fn(f,...)
 if type(f)~='function' then return nil end
 local ok,v=pcall(f,...);if ok then return v end
end
function U.call(o,k,...)
 if not o then return nil end
 local ok,f=pcall(function()return o[k]end)
 if ok then return U.fn(f,o,...) end
end
function U.number(v)
 local ok,n=pcall(tonumber,v)
 if ok and n and n==n and n~=math.huge and n~=-math.huge then return n end
end
function U.guid(o) local v=U.call(o,'get_guid');return v and tostring(v) or nil end
function U.same(a,b)
 if not a or not b then return false end
 if a==b then return true end
 local x,y=U.guid(a),U.guid(b);return x~=nil and x==y
end
function U.valid(o) return U.call(o,'is_valid')==true and U.call(o,'is_dead')==false end
function U.hp(o)
 local h,m=U.number(U.call(o,'get_health')),U.number(U.call(o,'get_max_health'))
 if h and m and m>0 then return math.max(0,math.min(100,h/m*100)),m end
end
function U.distance(a,b)
 local p,q=U.call(a,'get_position'),U.call(b,'get_position')
 return U.point_distance(p,q)
end
function U.point_distance(p,q)
 if not p or not q then return math.huge end
 local ok,d=pcall(function()return math.sqrt((p.x-q.x)^2+(p.y-q.y)^2+(p.z-q.z)^2)end)
 return ok and U.number(d) or math.huge
end
function U.enemy(p,u) return U.valid(u) and U.call(u,'is_unit')==true and U.call(p,'can_attack',u)==true end
function U.pvp_unit(u)
 if U.call(u,'is_player')==true then return true end
 local owner=U.call(u,'get_owner')
 return U.call(owner,'is_valid')==true and U.call(owner,'is_player')==true
end
function U.los(p,u)
 return core.graphics and U.fn(core.graphics.is_line_of_sight,p,u)==true
end
function U.facing(p,u)
 local a,b=U.call(p,'get_position'),U.call(u,'get_position')
 local r=U.number(U.call(p,'get_rotation'))
 if not a or not b or not r then return false end
 local ok,result=pcall(function()
  local dx,dy=b.x-a.x,b.y-a.y
  local n=math.sqrt(dx*dx+dy*dy)
  return n<0.01 or (math.cos(r)*dx+math.sin(r)*dy)/n>=0
 end)
 return ok and result==true
end
function U.clean(v) return tostring(v or ''):gsub('[\r\n|%z]',' '):sub(1,220) end
return U
