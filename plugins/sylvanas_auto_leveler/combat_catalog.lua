-- Starter fallbacks supplement Retail's live specialization-aware recommendation.
-- Every candidate is checked against the actual learned spellbook and castability.
local M={classes={},specs={}}
local function spell(id,extra) local s=extra or {};s.id=id;return s end
local function class(id,name,attacks,defense,heals,extra)
 local c=extra or {};c.name=name;c.attacks=attacks;c.defense=defense or {};c.heals=heals or {};M.classes[id]=c
end
local function spec(id,class_id,name,attacks,extra)
 local s=extra or {};s.class_id=class_id;s.name=name;s.attacks=attacks;M.specs[id]=s
end
class(1,"Warrior",{spell(1464)}, {spell(184364),spell(871)}, {spell(34428,{enemy=true,hp=70}),spell(202168,{enemy=true,hp=70})})
class(2,"Paladin",{spell(20271),spell(35395)}, {spell(498)}, {spell(85673,{hp=65}),spell(19750,{hp=55}),spell(633,{hp=20})})
class(3,"Hunter",{spell(3044),spell(56641)}, {spell(264735)}, {spell(109304,{hp=55})},{pet=true,summons={883},revive=982,pet_heal=136})
class(4,"Rogue",{spell(196819,{combo=4}),spell(2098,{combo=4}),spell(1752)}, {spell(5277)}, {spell(185311,{hp=60})})
class(5,"Priest",{spell(589,{dot=true}),spell(585)}, {spell(17,{buff=true})}, {spell(2061,{hp=65})})
class(6,"Death Knight",{spell(49998),spell(47541),spell(316239)}, {spell(48792)}, {spell(49998,{enemy=true,hp=70})})
class(7,"Shaman",{spell(188196),spell(403)}, {spell(108271)}, {spell(8004,{hp=60})})
class(8,"Mage",{spell(133),spell(116)}, {spell(11426,{buff=true}),spell(235313,{buff=true}),spell(235450,{buff=true})}, {})
class(9,"Warlock",{spell(172,{dot=true}),spell(686)}, {spell(104773)}, {spell(234153,{enemy=true,hp=55})},{pet=true,summons={697,688}})
class(10,"Monk",{spell(100784),spell(100780)}, {spell(115203)}, {spell(116670,{hp=60})})
class(11,"Druid",{spell(8921,{dot=true}),spell(5176)}, {spell(22812)}, {spell(8936,{hp=60}),spell(18562,{hp=55})})
class(12,"Demon Hunter",{spell(162794),spell(162243)}, {spell(198589),spell(204021,{enemy=true})}, {})
class(13,"Evoker",{spell(361469),spell(362969)}, {spell(363916)}, {spell(361469,{hp=60})})
spec(71,1,"Arms",{spell(5308,{execute=20}),spell(12294),spell(7384),spell(1464)})
spec(72,1,"Fury",{spell(184367),spell(23881),spell(85288),spell(1464)})
spec(73,1,"Protection",{spell(23922),spell(6572),spell(20243),spell(1464)})
spec(65,2,"Holy",{spell(20473),spell(20271),spell(35395)})
spec(66,2,"Protection",{spell(31935),spell(20271),spell(53595),spell(35395)})
spec(70,2,"Retribution",{spell(85256),spell(184575),spell(20271),spell(35395)})
spec(253,3,"Beast Mastery",{spell(34026),spell(217200,{dot=true}),spell(193455),spell(3044)})
spec(254,3,"Marksmanship",{spell(19434),spell(257044),spell(3044),spell(56641)},{no_pet=true})
spec(255,3,"Survival",{spell(34026),spell(259387),spell(186270)})
spec(259,4,"Assassination",{spell(32645,{combo=4}),spell(1943,{combo=4,dot=true}),spell(1329),spell(1752)})
spec(260,4,"Outlaw",{spell(2098,{combo=4}),spell(185763,{buff_id=195627}),spell(193315),spell(1752)})
spec(261,4,"Subtlety",{spell(196819,{combo=4}),spell(185438),spell(53),spell(1752)})
spec(256,5,"Discipline",{spell(589,{dot=true}),spell(47540),spell(585)})
spec(257,5,"Holy",{spell(14914,{dot=true}),spell(585)})
spec(258,5,"Shadow",{spell(34914,{dot=true}),spell(589,{dot=true}),spell(8092),spell(15407)})
spec(250,6,"Blood",{spell(49998),spell(195182),spell(206930)})
spec(251,6,"Frost",{spell(49143),spell(49020),spell(49184)})
spec(252,6,"Unholy",{spell(47541),spell(55090),spell(85948)},{summons={46585}})
spec(262,7,"Elemental",{spell(188389,{dot=true}),spell(51505),spell(188196),spell(403)})
spec(263,7,"Enhancement",{spell(17364),spell(60103),spell(193786),spell(188196),spell(403)})
spec(264,7,"Restoration",{spell(188389,{dot=true}),spell(51505),spell(188196),spell(403)})
spec(62,8,"Arcane",{spell(44425,{power_type=16,power_min=3}),spell(30451),spell(133)})
spec(63,8,"Fire",{spell(11366,{buff_id=48108}),spell(108853),spell(2136),spell(133)})
spec(64,8,"Frost",{spell(30455,{buff_id=44544}),spell(44614,{buff_id=190446}),spell(116)})
spec(265,9,"Affliction",{spell(980,{dot=true}),spell(172,{dot=true}),spell(30108,{dot=true}),spell(686)})
spec(266,9,"Demonology",{spell(105174),spell(104316),spell(686)},{summons={30146,697,688}})
spec(267,9,"Destruction",{spell(348,{dot=true}),spell(116858),spell(17962),spell(29722),spell(686)})
spec(268,10,"Brewmaster",{spell(121253),spell(100784),spell(100780)})
spec(269,10,"Windwalker",{spell(107428),spell(113656),spell(100784),spell(100780)})
spec(270,10,"Mistweaver",{spell(107428),spell(100784),spell(100780)})
spec(102,11,"Balance",{spell(78674),spell(8921,{dot=true}),spell(5176),spell(194153)},{form=24858})
spec(103,11,"Feral",{spell(22568,{combo=4}),spell(1079,{combo=4,dot=true}),spell(1822,{dot=true}),spell(5221)},{form=768})
spec(104,11,"Guardian",{spell(33917),spell(6807),spell(8921,{dot=true})},{form=5487})
spec(105,11,"Restoration",{spell(8921,{dot=true}),spell(5176)})
spec(577,12,"Havoc",{spell(188499),spell(162794),spell(162243)})
spec(581,12,"Vengeance",{spell(228477),spell(203782)})
spec(1480,12,"Devourer",{spell("Reap"),spell("Consume"),spell("Void Ray")})
spec(1467,13,"Devastation",{spell(356995),spell(361469),spell(362969)})
spec(1468,13,"Preservation",{spell(356995),spell(361469),spell(362969)})
spec(1473,13,"Augmentation",{spell(395160),spell(361469),spell(362969)})
-- Basic mode avoids empowered/ground-location spells without explicit execution support.
M.empowered={[357208]=true,[359073]=true,[355936]=true,[367226]=true}
-- Supplemental learned abilities; removed/talent-gated spells remain filtered live.
local interrupts={[1]={6552},[2]={96231},[3]={147362,187707},[4]={1766},[5]={15487},[6]={47528},[7]={57994},[8]={2139},[9]={19647,119910},[10]={116705},[11]={106839,78675},[12]={183752},[13]={351338}}
for cid,ids in pairs(interrupts) do M.classes[cid].interrupts={};for _,id in ipairs(ids) do table.insert(M.classes[cid].interrupts,spell(id)) end end
M.classes[1].buffs={spell(6673,{buff=true})}
M.classes[5].buffs={spell(21562,{buff=true})}
M.classes[8].buffs={spell(1459,{buff=true})}
M.classes[11].buffs={spell(1126,{buff=true})}
local cooldowns={
 [71]={{107574,true},{262161,false}},[72]={{1719,true},{107574,true}},[73]={{107574,true}},
 [65]={{31884,true}},[66]={{31884,true}},[70]={{31884,true},{343527,false}},
 [253]={{19574,true},{193530,true}},[254]={{288613,true}},[255]={{360952,true}},
 [259]={{360194,false}},[260]={{13750,true}},[261]={{121471,true}},
 [256]={{34433,false},{123040,false}},[257]={{34433,false}},[258]={{228260,true},{34433,false},{200174,false}},
 [250]={{49028,false}},[251]={{51271,true},{279302,false}},[252]={{63560,true},{42650,true},{49206,false}},
 [262]={{114050,true},{192249,false}},[263]={{114051,true},{51533,true}},[264]={{114052,true}},
 [62]={{365350,true}},[63]={{190319,true}},[64]={{12472,true}},
 [265]={{205180,false}},[266]={{265187,false}},[267]={{1122,false}},
 [268]={{387184,false}},[269]={{137639,true},{123904,false}},[270]={{322118,true}},
 [102]={{194223,true},{102560,true}},[103]={{5217,true},{106951,true},{102543,true}},[104]={{50334,true},{102558,true}},[105]={{33891,true}},
 [577]={{191427,true}},[581]={{187827,true}},[1480]={},
 [1467]={{375087,true}},[1468]={},[1473]={{403631,false}},
}
for sid,rows in pairs(cooldowns) do
 local s=M.specs[sid];s.cooldowns={}
 for _,row in ipairs(rows) do table.insert(s.cooldowns,spell(row[1],{self_target=row[2],combat_only=true,target_hp_min=40})) end
end
local supplemental={
 [71]={spell(772,{dot=true})},[72]={spell(190411,{aoe=2}),spell(5308,{execute=20})},[73]={spell(6343,{aoe=2})},
 [65]={spell(24275,{execute=20})},[66]={spell(53600),spell(26573,{ground_self=true,aoe=2})},[70]={spell(24275,{execute=20}),spell(53385,{aoe=3})},
 [253]={spell(53351,{execute=20}),spell(2643,{aoe=3})},[254]={spell(53351,{execute=20}),spell(2643,{aoe=3})},[255]={spell(259495),spell(53351,{execute=20})},
 [259]={spell(51723,{aoe=3})},[260]={spell(315341)},[261]={spell(114014,{aoe=3})},
 [256]={spell(204197,{dot=true})},[257]={spell(14914)},[258]={spell(335467),spell(32379,{execute=20})},
 [250]={spell(50842,{aoe=2})},[251]={spell(49184)},[252]={spell(77575,{dot=true})},
 [262]={spell(8042),spell(188443,{aoe=3})},[263]={spell(188389,{dot=true}),spell(187874,{aoe=2})},[264]={spell(188443,{aoe=3})},
 [62]={spell(5143),spell(1449,{aoe=3})},[63]={spell(2948)},[64]={spell(30455,{execute=20})},
 [265]={spell(324536)},[266]={spell(264178)},[267]={spell(17877,{execute=20})},
 [268]={spell(115181,{aoe=2})},[269]={spell(101546,{aoe=3})},[270]={spell(101546,{aoe=3})},
 [102]={spell(93402,{dot=true})},[103]={spell(106830,{aoe=3}),spell(106785,{aoe=3})},[104]={spell(77758,{aoe=2}),spell(213771,{aoe=3})},[105]={spell(93402,{dot=true})},
 [577]={spell(198013)},[581]={spell(204596,{ground=true,aoe=2})},[1480]={spell("Reap"),spell("Consume"),spell("Void Ray")},
 [1467]={spell(357208,{empower=1}),spell(359073,{empower=1})},[1468]={spell(357208,{empower=1})},[1473]={spell(357208,{empower=1}),spell(396286,{empower=1})},
}
for sid,rows in pairs(supplemental) do M.specs[sid].supplemental=rows end
local aoe={
 [71]={spell(845,{aoe=2}),spell(1680,{aoe=3,aoe_center="player"})},
 [72]={spell(190411,{aoe=2,aoe_center="player"}),spell(1680,{aoe=3,aoe_center="player"})},
 [73]={spell(6343,{aoe=2,aoe_center="player"}),spell(6572,{aoe=2})},
 [65]={spell(26573,{aoe=2,ground_self=true,aoe_center="player"})},
 [66]={spell(31935,{aoe=2}),spell(26573,{aoe=2,ground_self=true,aoe_center="player"})},
 [70]={spell(53385,{aoe=3}),spell(255937,{aoe=2})},
 [253]={spell(2643,{aoe=3})},[254]={spell(257044,{aoe=2}),spell(2643,{aoe=3})},[255]={spell(259495,{aoe=2}),spell(212436,{aoe=3})},
 [259]={spell(121411,{aoe=3,combo=4,aoe_center="player"}),spell(51723,{aoe=3,aoe_center="player"})},
 [260]={spell(13877,{aoe=2,aoe_center="player",self_target=true,buff=true})},
 [261]={spell(319175,{aoe=3,combo=4}),spell(197835,{aoe=3,aoe_center="player"}),spell(114014,{aoe=3})},
 [256]={spell(132157,{aoe=3,aoe_center="player"})},[257]={spell(132157,{aoe=3,aoe_center="player"})},[258]={spell(205385,{aoe=3,ground=true})},
 [250]={spell(50842,{aoe=2,aoe_center="player"}),spell(43265,{aoe=3,ground=true})},
 [251]={spell(49184,{aoe=2}),spell(196770,{aoe=3,aoe_center="player",self_target=true,buff=true})},
 [252]={spell(207317,{aoe=3}),spell(43265,{aoe=3,ground=true})},
 [262]={spell(61882,{aoe=3,ground=true}),spell(188443,{aoe=3})},
 [263]={spell(187874,{aoe=2,aoe_center="player"}),spell(188443,{aoe=3})},[264]={spell(188443,{aoe=3})},
 [62]={spell(44425,{aoe=3,power_type=16,power_min=3}),spell(1449,{aoe=3,aoe_center="player",radius=10})},
 [63]={spell(2120,{aoe=3,ground=true,buff_id=48108}),spell(31661,{aoe=3,aoe_center="player"})},
 [64]={spell(84714,{aoe=2}),spell(190356,{aoe=3,ground=true})},
 [265]={spell(27243,{aoe=3})},[266]={spell(105174,{aoe=3})},[267]={spell(5740,{aoe=3,ground=true})},
 [268]={spell(121253,{aoe=2}),spell(115181,{aoe=2,aoe_center="player"}),spell(101546,{aoe=3,aoe_center="player"})},
 [269]={spell(113656,{aoe=2}),spell(101546,{aoe=3,aoe_center="player"})},[270]={spell(101546,{aoe=3,aoe_center="player"})},
 [102]={spell(191034,{aoe=3}),spell(93402,{aoe=2,dot=true}),spell(194153,{aoe=2})},
 [103]={spell(285381,{aoe=3,combo=4}),spell(106830,{aoe=3,aoe_center="player"}),spell(106785,{aoe=3,aoe_center="player"})},
 [104]={spell(77758,{aoe=2,aoe_center="player"}),spell(213771,{aoe=3,aoe_center="player"})},
 [105]={spell(93402,{aoe=2,dot=true}),spell(194153,{aoe=2})},
 [577]={spell(198013,{aoe=2}),spell(188499,{aoe=3,aoe_center="player"})},
 [581]={spell(204596,{aoe=2,ground=true}),spell(228477,{aoe=3})},[1480]={spell("Void Ray",{aoe=2}),spell("Reap",{aoe=3})},
 [1467]={spell(357208,{aoe=2,empower=1}),spell(359073,{aoe=2,empower=2}),spell(362969,{aoe=2})},
 [1468]={spell(357208,{aoe=2,empower=1}),spell(362969,{aoe=2})},
 [1473]={spell(396286,{aoe=2,empower=1}),spell(357208,{aoe=2,empower=1}),spell(362969,{aoe=2})},
}
for sid,rows in pairs(aoe) do M.specs[sid].aoe=rows end
local starter_aoe={ [1]=6343,[2]=26573,[3]=2643,[4]=51723,[5]=132157,[6]=50842,[7]=188443,[8]=1449,[9]=27243,[10]=101546,[11]=106785,[12]=188499,[13]=362969 }
for cid,id in pairs(starter_aoe) do
 local around_self=cid==1 or cid==2 or cid==4 or cid==5 or cid==6 or cid==8 or cid==10 or cid==11 or cid==12
 M.classes[cid].aoe={spell(id,{aoe=3,aoe_center=around_self and "player" or "target",ground_self=cid==2 or nil})}
end
return M
