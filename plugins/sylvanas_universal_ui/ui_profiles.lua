-- Class order and specialization indexes follow the Retail talent interface.
-- Ability IDs are starter display candidates; only learned abilities are shown.
local P={classes={},specs={}}
local function class(id,name,rgb) P.classes[id]={name=name,color=rgb,specs={}} end
class(1,'Warrior',{199,156,110});class(2,'Paladin',{245,140,186})
class(3,'Hunter',{171,212,115});class(4,'Rogue',{255,244,104})
class(5,'Priest',{235,235,235});class(6,'Death Knight',{196,45,75})
class(7,'Shaman',{65,145,255});class(8,'Mage',{105,204,240})
class(9,'Warlock',{148,130,201});class(10,'Monk',{0,255,152})
class(11,'Druid',{255,125,10});class(12,'Demon Hunter',{163,48,201})
class(13,'Evoker',{51,147,127})
local function spec(c,id,name,role,powers,spells)
 local row={class=c,id=id,name=name,role=role,powers=powers,spells=spells}
 P.classes[c].specs[#P.classes[c].specs+1]=id;P.specs[id]=row
end
spec(1,71,'Arms','DPS',{'RAGE'},{167105,227847,107574,118038,6552})
spec(1,72,'Fury','DPS',{'RAGE'},{1719,184364,107574,46924,6552})
spec(1,73,'Protection','TANK',{'RAGE'},{2565,12975,871,1160,6552})
spec(2,65,'Holy','HEALER',{'MANA','HOLYPOWER'},{31884,31821,6940,642,633})
spec(2,66,'Protection','TANK',{'HOLYPOWER','MANA'},{53600,31850,86659,642,96231})
spec(2,70,'Retribution','DPS',{'HOLYPOWER'},{31884,255937,184662,642,96231})
spec(3,253,'Beast Mastery','DPS',{'FOCUS'},{19574,193530,186265,109304,147362})
spec(3,254,'Marksmanship','DPS',{'FOCUS'},{288613,257044,186265,109304,147362})
spec(3,255,'Survival','DPS',{'FOCUS'},{360952,259495,186265,109304,187707})
spec(4,259,'Assassination','DPS',{'ENERGY','COMBOPOINTS'},{360194,385627,1856,31224,1766})
spec(4,260,'Outlaw','DPS',{'ENERGY','COMBOPOINTS'},{13750,315508,1856,31224,1766})
spec(4,261,'Subtlety','DPS',{'ENERGY','COMBOPOINTS'},{121471,185313,1856,31224,1766})
spec(5,256,'Discipline','HEALER',{'MANA'},{47536,62618,33206,19236,586})
spec(5,257,'Holy','HEALER',{'MANA'},{64843,47788,265202,19236,586})
spec(5,258,'Shadow','DPS',{'INSANITY','MANA'},{228260,391109,47585,19236,15487})
spec(6,250,'Blood','TANK',{'RUNICPOWER','RUNES'},{55233,49028,48792,194679,47528})
spec(6,251,'Frost','DPS',{'RUNICPOWER','RUNES'},{51271,152279,279302,48792,47528})
spec(6,252,'Unholy','DPS',{'RUNICPOWER','RUNES'},{275699,42650,63560,48792,47528})
spec(7,262,'Elemental','DPS',{'MAELSTROM','MANA'},{191634,198067,108271,108280,57994})
spec(7,263,'Enhancement','DPS',{'MANA'},{51533,114051,384352,108271,57994})
spec(7,264,'Restoration','HEALER',{'MANA'},{98008,108280,16191,108271,57994})
spec(8,62,'Arcane','DPS',{'MANA','ARCANECHARGES'},{365350,321507,12051,342245,2139})
spec(8,63,'Fire','DPS',{'MANA'},{190319,108853,257541,342245,2139})
spec(8,64,'Frost','DPS',{'MANA'},{12472,84714,205021,342245,2139})
spec(9,265,'Affliction','DPS',{'SOULSHARDS','MANA'},{205180,278350,104773,108416,30283})
spec(9,266,'Demonology','DPS',{'SOULSHARDS','MANA'},{265187,111898,104773,108416,30283})
spec(9,267,'Destruction','DPS',{'SOULSHARDS','MANA'},{1122,196447,104773,108416,30283})
spec(10,268,'Brewmaster','TANK',{'ENERGY'},{119582,115203,122278,322507,116705})
spec(10,270,'Mistweaver','HEALER',{'MANA'},{115310,116849,322118,115203,116705})
spec(10,269,'Windwalker','DPS',{'ENERGY','CHI'},{137639,152173,123904,115203,116705})
spec(11,102,'Balance','DPS',{'LUNARPOWER','MANA'},{194223,102560,78675,22812,194153})
spec(11,103,'Feral','DPS',{'ENERGY','COMBOPOINTS'},{106951,102543,5217,61336,106839})
spec(11,104,'Guardian','TANK',{'RAGE'},{192081,22842,22812,61336,106839})
spec(11,105,'Restoration','HEALER',{'MANA'},{740,33891,102342,197721,22812})
spec(12,577,'Havoc','DPS',{'FURY'},{191427,198013,198589,196718,183752})
spec(12,581,'Vengeance','TANK',{'FURY'},{187827,203720,204021,212084,183752})
spec(12,1480,'Devourer','DPS',{'FURY'},{183752})
spec(13,1467,'Devastation','DPS',{'ESSENCE','MANA'},{375087,357208,359073,363916,351338})
spec(13,1468,'Preservation','HEALER',{'MANA','ESSENCE'},{363534,370537,357170,374227,363916})
spec(13,1473,'Augmentation','DPS',{'ESSENCE','MANA'},{403631,395152,395296,363916,351338})
P.power_names={MANA='Mana',RAGE='Rage',FOCUS='Focus',ENERGY='Energy',COMBOPOINTS='Combo points',
 RUNES='Runes',RUNICPOWER='Runic power',SOULSHARDS='Soul shards',LUNARPOWER='Astral power',
 HOLYPOWER='Holy power',MAELSTROM='Maelstrom',CHI='Chi',INSANITY='Insanity',ARCANECHARGES='Arcane charges',FURY='Fury',ESSENCE='Essence'}
function P.starter(class_id)
 local c=P.classes[class_id];if not c then return end
 local first=P.specs[c.specs[1]]
 local spells,seen={},{}
 for _,id in ipairs(c.specs)do for _,spell in ipairs(P.specs[id].spells)do if not seen[spell]then seen[spell]=true;spells[#spells+1]=spell end end end
 return {id=10000+class_id,class=class_id,name='Starter',role='LEVELING',powers=first.powers,spells=spells}
end
function P.resolve(class_id,reported,index,object_reported)
 local c=P.classes[class_id];if not c then return nil,'Unknown class' end
 local signals={}
 local function global_id(value,label)
  value=tonumber(value)
  if not value or value<=0 then return true end
  value=math.floor(value)
  local row=P.specs[value]
  if not row then return nil,'Unsupported '..label..' specialization ID' end
  if row.class~=class_id then return nil,'Class/spec mismatch' end
  signals[#signals+1]=value;return true
 end
 local ok,why=global_id(reported,'spellbook');if not ok then return nil,why end
 ok,why=global_id(object_reported,'player');if not ok then return nil,why end
 index=tonumber(index)
 if index and index>0 then
  index=math.floor(index)
  local id=c.specs[index]
  if not id then return nil,'Waiting for valid specialization index' end
  signals[#signals+1]=id
 end
 if #signals==0 then return nil,'Waiting for specialization' end
 for i=2,#signals do if signals[i]~=signals[1] then return nil,'Specialization changing' end end
 return P.specs[signals[1]]
end
return P
