-- Explicit rule profiles, not queue IDs or live observations.
-- A provider selects the actual layout; never infer it from a client name alone.
local R={profiles={
 warsong={name="Warsong Gulch",kind="ctf"},
 twin_peaks={name="Twin Peaks",kind="ctf"},
 arathi_training={name="Arathi Basin (Training Grounds)",kind="bases",mode="training",npc_opponents=true},
 gilneas_training={name="Battle for Gilneas (Training Grounds)",kind="bases",mode="training",npc_opponents=true},
 silvershard_training={name="Silvershard Mines (Training Grounds)",kind="carts",mode="training",npc_opponents=true},
 arathi_comp_stomp={name="Arathi Basin (legacy Comp Stomp)",kind="bases",mode="comp_stomp",npc_opponents=true},
 arathi={name="Arathi Basin",kind="bases"},
 arathi_blitz={name="Arathi Basin (Blitz)",kind="bases",mode="blitz"},
 gilneas={name="Battle for Gilneas",kind="bases"},
 eye_standard={name="Eye of the Storm",kind="hybrid"},
 darkspear_islands={name="Darkspear Islands",kind="hybrid"},
 eye_blitz={name="Eye of the Storm (Blitz; live layout)",kind="hybrid",mode="blitz"},
 eye_blitz_legacy={name="Eye of the Storm (legacy rotating Blitz)",kind="hybrid",mode="blitz"},
 deepwind_modern={name="Deepwind Gorge (base layout)",kind="bases"},
 deepwind_blitz={name="Deepwind Gorge (Blitz)",kind="bases",mode="blitz"},
 deepwind_legacy={name="Deepwind Gorge (legacy carts)",kind="legacy_cart_bases"},
 kotmogu={name="Temple of Kotmogu",kind="orbs"},
 silvershard={name="Silvershard Mines",kind="carts"},
 seething={name="Seething Shore",kind="resources"},
 deephaul={name="Deephaul Ravine",kind="cart_crystal"},
 alterac={name="Alterac Valley",kind="reinforcements"},
 isle={name="Isle of Conquest",kind="siege"},
 wintergrasp={name="Battle for Wintergrasp",kind="siege"},
 strand={name="Strand of the Ancients",kind="siege_rounds"},
 ashran={name="Ashran",kind="frontline"},
 southshore={name="Southshore vs. Tarren Mill",kind="deathmatch"},
 slayers_rise={name="Slayer's Rise",kind="reinforcements"}
}}
function R.npc_opponents(snapshot)
 local rule=R.profiles[snapshot.rule_profile]
 return rule~=nil and rule.npc_opponents==true and snapshot.mode==rule.mode
end
function R.resolve(snapshot)
 if not snapshot.rule_profile then return snapshot end
 local rule=R.profiles[snapshot.rule_profile]
 if not rule then return nil,"unknown_battleground_rule_profile" end
 if snapshot.kind and snapshot.kind~=rule.kind then return nil,"battleground_rule_mismatch" end
 if rule.mode and snapshot.mode~=rule.mode then return nil,"battleground_mode_mismatch" end
 local copy={};for key,value in pairs(snapshot) do copy[key]=value end
 copy.kind=rule.kind;copy.battleground_name=rule.name
 return copy
end
return R
