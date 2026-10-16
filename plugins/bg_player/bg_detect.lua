local Policy=require("bg_route_policy")
local D={}
local instances={
 [30]="alterac",[489]="warsong",[529]="arathi",[566]="eye_standard",
 [607]="strand",[628]="isle",[726]="twin_peaks",[727]="silvershard",
 [761]="gilneas",[968]="eye_standard",[998]="kotmogu",[1105]="deepwind_legacy",
 [1191]="ashran",[1280]="southshore",[1681]="arathi",[1803]="seething",[2106]="warsong",[2107]="arathi",
 [2118]="wintergrasp",
 [2177]="arathi_comp_stomp",[2245]="deepwind_modern",[2656]="deephaul",[2799]="slayers_rise",
 [2997]="darkspear_islands"
}
local ui_maps={
 [401]="alterac",[417]="kotmogu",[423]="silvershard",[443]="warsong",
 [461]="arathi",[482]="eye_standard",[512]="strand",[540]="isle",
 [519]="deepwind_legacy",[588]="ashran",[623]="southshore",[626]="twin_peaks",
 [736]="gilneas",[813]="eye_standard",[856]="kotmogu",[860]="silvershard",
 [907]="seething",[935]="deepwind_modern",[1139]="arathi",[1334]="wintergrasp",[1339]="warsong",
 [1383]="arathi",[1404]="wintergrasp",[1478]="ashran",[1576]="deepwind_modern",
 [2345]="deephaul",[2397]="slayers_rise",[2524]="darkspear_islands"
}
local names={
 ["alterac valley"]="alterac",["warsong gulch"]="warsong",["arathi basin"]="arathi",
 ["darkspear islands"]="darkspear_islands",["the darkspear islands"]="darkspear_islands",
 ["eye of the storm"]="eye_standard",["isle of conquest"]="isle",["twin peaks"]="twin_peaks",
 ["silvershard mines"]="silvershard",["the battle for gilneas"]="gilneas",["battle for gilneas"]="gilneas",
 ["temple of kotmogu"]="kotmogu",["deepwind gorge"]="deepwind_modern",["seething shore"]="seething",
 ["deephaul ravine"]="deephaul",["ashran"]="ashran",["battle for wintergrasp"]="wintergrasp",
 ["wintergrasp"]="wintergrasp",["strand of the ancients"]="strand",
 ["southshore vs. tarren mill"]="southshore",["southshore vs tarren mill"]="southshore",
 ["tarren mill vs southshore"]="southshore",["slayer's rise"]="slayers_rise",["slayers rise"]="slayers_rise"
}
function D.resolve(instance_id,map_id,instance_name,client_family)
 local by_instance=instances[tonumber(instance_id)]
 local by_map=ui_maps[tonumber(map_id)]
 if by_instance and by_map and by_instance~=by_map then return nil,"battleground_identity_conflict" end
 local clean=type(instance_name)=="string" and instance_name:lower():gsub("^%s+",""):gsub("%s+$","")
 local profile=by_instance or by_map or names[clean]
 if profile and client_family then
  local allowed=Policy.allowed(client_family,profile)
  if not allowed then return nil,"battleground_not_available_on_client" end
 end
 return profile,profile and "detected" or "unsupported_battleground"
end
return D
