local M={}
local classes={
 [1]={"Warrior",{199,156,110},{35,18,14},"classicon-warrior",{71,72,73},"IRON AND BLOOD"},
 [2]={"Paladin",{244,140,186},{36,22,31},"classicon-paladin",{65,66,70},"JUDGMENT FALLS"},
 [3]={"Hunter",{170,211,114},{19,31,18},"classicon-hunter",{253,254,255},"THE HUNT BEGINS"},
 [4]={"Rogue",{255,244,104},{29,27,9},"classicon-rogue",{259,260,261},"NO WITNESSES"},
 [5]={"Priest",{230,230,230},{25,22,31},"classicon-priest",{256,257,258},"FAITH OR FEAR"},
 [6]={"Death Knight",{196,30,58},{31,8,13},"classicon-deathknight",{250,251,252},"DEATH ADVANCES"},
 [7]={"Shaman",{0,112,222},{8,19,34},"classicon-shaman",{262,263,264},"THE ELEMENTS RAGE"},
 [8]={"Mage",{63,199,235},{10,24,35},"classicon-mage",{62,63,64},"REALITY BREAKS"},
 [9]={"Warlock",{135,136,238},{22,12,36},"classicon-warlock",{265,266,267},"SOULS FOR POWER"},
 [10]={"Monk",{0,255,152},{8,30,22},"classicon-monk",{268,270,269},"BODY BECOMES WEAPON"},
 [11]={"Druid",{255,124,10},{32,18,8},"classicon-druid",{102,103,104,105},"THE WILD DEVOURS"},
 [12]={"Demon Hunter",{163,48,201},{29,8,35},"classicon-demonhunter",{577,581,1480},"THE HUNT NEVER ENDS"},
 [13]={"Evoker",{51,147,127},{10,28,28},"classicon-evoker",{1467,1468,1473},"DRAGONFIRE AWAKENS"},
}
-- class, name, icon slug, accent, blood, motif, PvP title
local specs={
 [71]={1,"Arms","ability_warrior_savageblow",{188,42,36},{116,8,12},1,"THE EXECUTIONER"},
 [72]={1,"Fury","ability_warrior_innerrage",{238,54,35},{145,10,8},2,"UNENDING CARNAGE"},
 [73]={1,"Protection","ability_warrior_defensivestance",{178,120,55},{92,24,18},3,"THE IRON WALL"},
 [65]={2,"Holy","spell_holy_holybolt",{255,212,112},{122,35,58},4,"MERCILESS LIGHT"},
 [66]={2,"Protection","spell_holy_devotionaura",{232,166,68},{112,28,52},3,"SACRED BULWARK"},
 [70]={2,"Retribution","spell_holy_auraoflight",{255,92,92},{148,21,42},1,"FINAL JUDGMENT"},
 [253]={3,"Beast Mastery","ability_hunter_bestialdiscipline",{196,86,42},{98,25,15},5,"PACK OF TEETH"},
 [254]={3,"Marksmanship","ability_marksmanship",{198,214,92},{82,31,18},6,"ONE SHOT"},
 [255]={3,"Survival","ability_hunter_camouflage",{102,190,91},{86,28,17},5,"TRAP AND TEAR"},
 [259]={4,"Assassination","ability_rogue_deadlybrew",{173,49,101},{121,4,28},7,"VENOM IN THE VEINS"},
 [260]={4,"Outlaw","ability_rogue_waylay",{221,143,48},{105,23,19},6,"BLACK FLAG KILLER"},
 [261]={4,"Subtlety","ability_stealth",{116,82,181},{84,7,29},7,"DEATH FROM SHADOW"},
 [256]={5,"Discipline","spell_holy_powerwordshield",{205,176,255},{91,27,62},4,"PAIN IS THE LESSON"},
 [257]={5,"Holy","spell_holy_guardianspirit",{255,238,181},{104,37,49},4,"LAST RITES"},
 [258]={5,"Shadow","spell_shadow_shadowwordpain",{137,62,185},{79,5,43},8,"THE VOID WHISPERS"},
 [250]={6,"Blood","spell_deathknight_bloodpresence",{224,35,48},{126,0,12},2,"CRIMSON HUNGER"},
 [251]={6,"Frost","spell_deathknight_frostpresence",{78,190,239},{80,20,40},9,"FROZEN GRAVE"},
 [252]={6,"Unholy","spell_deathknight_unholypresence",{104,177,63},{73,22,29},10,"PLAGUE MARCH"},
 [262]={7,"Elemental","spell_nature_lightning",{77,174,255},{83,18,30},11,"STORM OF RUIN"},
 [263]={7,"Enhancement","spell_shaman_maelstromweapon",{52,205,191},{91,23,28},11,"DOOMHAMMER RUSH"},
 [264]={7,"Restoration","spell_nature_magicimmunity",{58,194,225},{76,25,37},12,"TIDE AGAINST DEATH"},
 [62]={8,"Arcane","spell_holy_magicalsentry",{171,89,242},{72,18,55},8,"ARCANE ANNIHILATION"},
 [63]={8,"Fire","spell_fire_firebolt02",{255,91,28},{130,17,9},13,"BURN THEM ALL"},
 [64]={8,"Frost","spell_frost_frostbolt02",{75,202,255},{63,30,52},9,"SHATTERED AND COLD"},
 [265]={9,"Affliction","spell_shadow_deathcoil",{117,196,68},{78,12,49},10,"AGONY WITHOUT END"},
 [266]={9,"Demonology","spell_shadow_metamorphosis",{169,87,232},{92,8,64},8,"LEGION UNLEASHED"},
 [267]={9,"Destruction","spell_shadow_rainoffire",{255,91,24},{136,10,18},13,"CHAOS INCARNATE"},
 [268]={10,"Brewmaster","spell_monk_brewmaster_spec",{176,125,48},{85,28,20},3,"DRUNKEN JUGGERNAUT"},
 [270]={10,"Mistweaver","spell_monk_mistweaver_spec",{61,224,177},{67,33,39},12,"MISTS OF SURVIVAL"},
 [269]={10,"Windwalker","spell_monk_windwalker_spec",{87,241,137},{74,25,26},11,"FISTS OF FURY"},
 [102]={11,"Balance","spell_nature_starfall",{93,126,255},{75,24,45},8,"ECLIPSE OF WAR"},
 [103]={11,"Feral","ability_druid_catform",{238,75,35},{132,8,18},5,"RIP AND REND"},
 [104]={11,"Guardian","ability_racial_cannibalize",{173,104,47},{96,24,16},3,"MAUL THE LINE"},
 [105]={11,"Restoration","spell_nature_healingtouch",{65,206,109},{69,32,35},12,"ROOTED IN BLOOD"},
 [577]={12,"Havoc","ability_demonhunter_specdps",{187,68,238},{102,5,55},7,"FELBLADE MASSACRE"},
 [581]={12,"Vengeance","ability_demonhunter_spectank",{121,212,64},{84,17,45},3,"PAIN MADE ARMOR"},
 [1480]={12,"Devourer","spell_shadow_soulleech_3",{210,73,255},{95,4,73},10,"THE HUNGER BELOW"},
 [1467]={13,"Devastation","ability_evoker_masterylifebinder_bronze",{229,83,54},{122,16,28},13,"DRAGONFIRE EXECUTION"},
 [1468]={13,"Preservation","ability_evoker_preservation_spec",{66,205,177},{71,27,42},12,"TIME DENIES DEATH"},
 [1473]={13,"Augmentation","ability_evoker_augmentspec",{229,170,74},{92,29,39},4,"EMPOWER THE SLAUGHTER"},
}
local tanks={[73]=1,[66]=1,[250]=1,[268]=1,[104]=1,[581]=1}
local healers={[65]=1,[256]=1,[257]=1,[264]=1,[270]=1,[105]=1,[1468]=1}
local melee={[71]=1,[72]=1,[70]=1,[255]=1,[259]=1,[260]=1,[261]=1,[251]=1,[252]=1,[263]=1,[269]=1,[103]=1,[577]=1}
local ranged={[253]=1,[254]=1,[258]=1,[262]=1,[62]=1,[63]=1,[64]=1,[265]=1,[266]=1,[267]=1,[1480]=1,[1467]=1,[1473]=1,[102]=1}
local function unknown()
 return {role="unknown",label="Adventurer / Detecting class",color={190,42,48},accent={145,35,52},blood={92,4,14},
  shadow={19,12,18},background={11,8,13},surface={30,19,27},class_icon="inv_misc_questionmark",
  spec_icon="ability_dualwield",class_asset="battle",spec_asset="battle",
  title="BLOOD AND GLORY",epithet="AWAITING COMBAT IDENTITY",motif=1}
end
function M.resolve(class_id,reported)
 local cl=classes[class_id];if not cl then return unknown() end
 local id=tonumber(reported) or 0;if id>0 and id<50 then id=cl[5][id] or 0 end
 local sp=specs[id];if sp and sp[1]~=class_id then sp=nil end
 local role=sp and (tanks[id] and "tank" or healers[id] and "healer" or "damage") or "unknown"
 local style=role=="damage" and (melee[id] and "melee" or ranged[id] and "ranged" or "unknown") or nil
 local accent=sp and sp[4] or cl[2];local blood=sp and sp[5] or {105,11,25};local sh=cl[3]
 return {class_id=class_id,spec_id=sp and id or nil,role=role,damage_style=style,
  label=cl[1].." / "..(sp and sp[2] or "Specialization unavailable"),color=cl[2],accent=accent,blood=blood,shadow=sh,
  background={math.max(5,sh[1]-6),math.max(5,sh[2]-6),math.max(7,sh[3]-5)},surface={sh[1]+10,sh[2]+10,sh[3]+11},
  class_icon=cl[4],spec_icon=sp and sp[3] or cl[4],class_asset="class_"..class_id,
  spec_asset=sp and ("spec_"..id) or ("class_"..class_id),
  title=sp and sp[7] or cl[6],epithet=cl[6],motif=sp and sp[6] or class_id}
end
function M.detect(player)
 if not player then return M.resolve(nil,nil) end
 local ok,cid=pcall(function() return player:get_class() end);local valid=pcall(function() return assert(player:is_valid()) end)
 if not ok or not valid then return M.resolve(nil,nil) end
 local got,sid=pcall(function() return player:get_specialization_id() end)
 return M.resolve(cid,got and sid or nil)
end
M.classes=classes;M.specs=specs
return M
