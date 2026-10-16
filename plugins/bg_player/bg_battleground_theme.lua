local M={}
local themes={
 warsong={"WARSONG GULCH","CAPTURE THE ENEMY FLAG","orb",{180,32,36},{245,84,53},{91,4,16},1},
 twin_peaks={"TWIN PEAKS","HUNT THE ENEMY FLAG CARRIER","orb",{56,102,164},{204,54,55},{74,8,23},2},
 arathi={"ARATHI BASIN","CONTROL THE FIVE BASES","shield",{177,128,46},{224,185,78},{84,17,20},3},
 gilneas={"BATTLE FOR GILNEAS","SECURE THE THREE STRONGHOLDS","shield",{64,116,145},{90,190,174},{67,12,26},4},
 eye_standard={"EYE OF THE STORM","HOLD TOWERS • RUN THE FLAG","orb",{96,74,176},{188,92,236},{74,9,49},5},
 darkspear_islands={"DARKSPEAR ISLANDS","CONTROL THE ISLAND OBJECTIVES","battle",{43,126,116},{79,215,174},{61,12,29},6},
 deepwind_modern={"DEEPWIND GORGE","CONTROL THE BATTLEFIELD NODES","shield",{134,87,38},{219,151,51},{76,12,18},7},
 kotmogu={"TEMPLE OF KOTMOGU","CLAIM ORBS • CONTROL THE CENTER","orb",{139,48,155},{238,100,212},{77,5,45},8},
 silvershard={"SILVERSHARD MINES","ESCORT AND CONTEST THE CARTS","helm",{98,92,75},{227,177,75},{71,12,17},9},
 seething={"SEETHING SHORE","DROP • MINE • DENY AZERITE","battle",{30,110,154},{56,202,237},{61,7,29},10},
 deephaul={"DEEPHAUL RAVINE","ESCORT CARTS • SECURE CRYSTALS","helm",{114,58,145},{214,94,231},{65,7,39},11},
 alterac={"ALTERAC VALLEY","BREAK THE ENEMY REINFORCEMENTS","battle",{77,101,143},{184,207,238},{73,12,20},12},
 isle={"ISLE OF CONQUEST","COMMAND SIEGE • BREACH THE KEEP","helm",{68,101,133},{225,172,67},{70,10,20},13},
 wintergrasp={"WINTERGRASP","CONTROL WORKSHOPS • BREAK THE WALLS","helm",{74,115,145},{119,202,237},{65,13,28},14},
 strand={"STRAND OF THE ANCIENTS","ESCORT SIEGE • DESTROY THE GATES","helm",{139,98,45},{235,188,84},{80,13,18},15},
 ashran={"ASHRAN","ADVANCE THE FRONTLINE","battle",{130,48,42},{229,93,58},{78,7,17},16},
 southshore={"SOUTHSHORE VS. TARREN MILL","CRUSH THE ENEMY WAR PARTY","skull",{125,33,39},{232,68,60},{81,4,13},17},
 slayers_rise={"SLAYER'S RISE","DESTROY THE ENEMY REINFORCEMENTS","skull",{115,29,47},{222,69,86},{77,4,18},18},
}
local aliases={arathi_blitz="arathi",arathi_training="arathi",arathi_comp_stomp="arathi",
 gilneas_training="gilneas",silvershard_training="silvershard",eye_blitz="eye_standard",
 eye_blitz_legacy="eye_standard",deepwind_blitz="deepwind_modern",deepwind_legacy="deepwind_modern"}
function M.resolve(profile,role_theme)
 profile=aliases[profile] or profile
 local row=themes[profile] or {"BATTLEGROUND COMMAND","QUEUE • FIGHT • CAPTURE • WIN","battle",{126,35,42},{218,174,79},{78,5,16},19}
 local role=role_theme or {}
 return {profile=profile,title=row[1],label=row[1],epithet=row[2],objective_line=row[2],profile_icon=row[3],
  class_icon=row[3],spec_icon=row[3],class_asset="battle",spec_asset=row[3],color=row[4],accent=row[5],blood=row[6],motif=row[7],
  shadow={14,13,16},background={7,8,11},surface={25,27,31},role=role.role or "unknown",damage_style=role.damage_style}
end
return M
