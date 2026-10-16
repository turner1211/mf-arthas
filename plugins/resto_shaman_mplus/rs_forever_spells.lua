-- WoW Forever 1.60.x spell catalog. This file intentionally contains no Retail
-- hero talents, specialization spell IDs, or Retail-only override rules.
local M={
 LIGHTNING_BOLT={25307,15208,15207,15206,15205,15204,15203,9532,529,548,403},
 CHAIN_LIGHTNING={25442,10605,930,421}, EARTH_SHOCK={10414,10413,10412,8046,8045,8044,8042},
 FLAME_SHOCK={10448,10447,8053,8052,8050}, FROST_SHOCK={10473,10472,8058,8056},
 LAVA_BURST={1238300,1238299,408490}, FIRE_NOVA={408345,408344,408343,408342,408341},
 STORMSTRIKE={17364}, RAGE={425336}, RIPTIDE={1239243,1239242,408521}, WATER_SHIELD={408510},
 HEALING_WAVE={25396,25357,10396,10395,8005,8004,8003,332,331},
 LESSER_HEALING_WAVE={25420,10468,10467,10466,8010,8008}, CHAIN_HEAL={25423,10623,10622,1064},
 HEALING_STREAM={10463,10462,10461,6377,6375,5394}, MANA_SPRING={10497,10496,10495,5675},
 MANA_TIDE={16190}, NATURE_SWIFTNESS={16188}, PURGE={8012,370}, CURE_POISON={526}, CURE_DISEASE={2870},
 POISON_CLEANSING={8166}, DISEASE_CLEANSING={8170}, TREMOR={8143}, EARTHBIND={2484},
 SEARING={10438,10437,6365,6364,3599}, MAGMA={10587,10586,8190}, CALL_ELEMENTS={66842},
 CALL_ANCESTORS={66843},CALL_SPIRITS={66844},TOTEMIC_RECALL={36936},TOTEMIC_PROJECTION={108287},
 MAELSTROM_TALENT={408498},MAELSTROM_AURA={408505}, CLEARCASTING={16246}, GHOST_WOLF={2645}, REINCARNATION={20608},
 ANCESTRAL_SPIRIT={20777,20776,20610,20609,2008},
 LIGHTNING_SHIELD={10432,10431,10430,945,905,324},STONECLAW={10428,10427,6392,6391,5730},GROUNDING={8177},
 STRENGTH_EARTH={25361,10442,8163,8162,8075},WINDFURY_TOTEM={10614,10613,8512},
 STONESKIN={10408,10407,8155,8154,8071},GRACE_AIR={25359,10627,8835},
 FLAMETONGUE_TOTEM={16387,10526,8249,8227},TRANQUIL_AIR={25908},
 WINDFURY_WEAPON={16362,16316,8235,8232},FLAMETONGUE_WEAPON={16342,16341,10400,8038,8027,8024},
 ROCKBITER_WEAPON={16314,16313,16312,10399,8018,8017},
}
local function book(name,...)
 local fn=core.spell_book and core.spell_book[name];if type(fn)~="function" then return nil end
 local ok,v=pcall(fn,...);if ok then return v end
end
function M.known(family)
 if type(family)=="number" then return book("is_spell_known",family)==true and family or nil end
 for _,id in ipairs(family or {}) do if book("is_spell_known",id)==true then return id end end
end
function M.ready(family)
 local id=M.known(family);if not id or book("is_usable_spell",id)~=true then return nil end
 local cd=book("get_spell_cooldown",id);if type(cd)=="number" and cd<=0.05 then return id end
end
-- Families are ordered highest rank first. Rank-aware selection lets Forever
-- conserve mana without hard-coding a level cap or assuming every rank is known.
function M.ready_rank(family,offset)
 if type(family)=="number" then return M.ready(family) end
 local available={}
 for _,id in ipairs(family or {}) do
  if book("is_spell_known",id)==true and book("is_usable_spell",id)==true then
   local cd=book("get_spell_cooldown",id)
   if type(cd)=="number" and cd<=0.05 then available[#available+1]=id end
  end
 end
 if #available==0 then return nil end
 return available[math.min(#available,math.max(1,1+(tonumber(offset) or 0)))]
end
function M.lowest_ready(family)
 if type(family)=="number" then return M.ready(family) end
 for index=#(family or {}),1,-1 do
  local id=family[index]
  if book("is_spell_known",id)==true and book("is_usable_spell",id)==true then
   local cd=book("get_spell_cooldown",id)
   if type(cd)=="number" and cd<=0.05 then return id end
  end
 end
end
return M
