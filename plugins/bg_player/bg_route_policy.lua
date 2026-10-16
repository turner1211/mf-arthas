-- Client-aware map boundary. Shared legacy maps deliberately reuse their
-- proven world-coordinate corridors; client-exclusive maps never cross over.
local P={}
local forever={warsong=true,arathi=true,alterac=true,darkspear_islands=true}
local retail={darkspear_islands=false}
local function family(value)
 return tostring(value or "unknown"):lower():gsub("[^%w]+","_"):gsub("^_+",""):gsub("_+$","")
end
function P.allowed(client_family,profile)
 local f=family(client_family)
 if f=="unknown" or f=="" then return true,"client_loading" end
 if f:find("forever",1,true) then return forever[profile]==true,forever[profile] and "shared_or_forever" or "retail_only" end
 if f=="midnight" or f=="retail" or f=="war_within" or f=="dragonflight" then
  return retail[profile]~=false,retail[profile]==false and "forever_only" or "retail"
 end
 -- Preserve existing support for Classic/private adapters until their map
 -- catalogs are positively identified; route learning remains product-scoped.
 return true,"compatible_unclassified_client"
end
function P.classification(profile)
 if profile=="darkspear_islands" then return "forever_only" end
 if profile=="warsong" or profile=="arathi" or profile=="alterac" then return "retail_forever_shared" end
 return "retail_catalog"
end
return P
