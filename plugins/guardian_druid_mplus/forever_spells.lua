local U=require("druid_shared")
local M={
 bear={9634,5487},cat={768},moonkin={24858},barkskin={22812},nature_grasp={17329,16813,16812,16811,16810,16689},
 mark={9885,9884,8907,5234,6756,5232,1126},gift={21850,21849},thorns={9910,9756,8914,1075,782,467},faerie_fire={9907,9749,778,770},
 wrath={9912,8905,6780,5180,5179,5178,5177,5176},moonfire={9835,9834,9833,8929,8928,8927,8926,8925,8924,8921},
 starfire={25298,9876,9875,8951,8950,8949,2912},insect_swarm={24977,24976,24975,24974,5570},hurricane={17402,17401,16914},
 roots={9853,9852,5196,5195,1062,339},hibernate={18658,18657,2637},
 growl={6795},challenging_roar={5209},enrage={5229},demo={9898,9747,9490,1735,99},swipe={9908,9754,769,780,779},maul={9881,9880,9745,8972,6809,6808,6807},
 bash={8983,6798,5211},frenzied_regen={22842},lacerate={1235827,1235826,414644},primal_bite={1238073,1238070,1238069,407995},berserk={417141},
 claw={9850,9849,5201,3029,1082},rake={9904,1824,1823,1822},rip={9896,9894,9752,9493,9492,1079},shred={9830,9829,8992,6800,5221},
 ferocious_bite={31018,22829,22828,22827,22568},shifting_power={1322605},feral_charge={1238122},cower={9892,9000,8998},prowl={9913,6783,5215},dash={9821,1850},
 ravage={9867,9866,9865,6785},pounce={9827,9823,9005},clearcasting={16870},
 healing_touch={25297,9889,9888,9758,8903,6778,5187,5186,5185,5184,5183},
 rejuvenation={25299,9841,9840,9839,8910,3627,2091,2090,1430,1058,774},
 regrowth={9858,9857,9856,9750,8941,8940,8939,8938,8936},swiftmend={18562},wild_growth={1238215,1238214,408120},tranquility={9863,9862,8918,740},
 nature_swiftness={17116},innervate={29166},revive={1237951,1237950,1237949,1237948,437138},rebirth={20748,20747,20742,20739,20484},
 cure_poison={8946},abolish_poison={2893},remove_curse={2782}
}
local best_cache={}
function M.best(key)
    if best_cache[key]~=nil then return best_cache[key]~=false and best_cache[key]or nil end
    local list=M[key];if type(list)~="table" then return nil end
    for _,id in ipairs(list) do if U.known(id) then best_cache[key]=id;return id end end
    best_cache[key]=false
end
function M.invalidate()best_cache={}end
function M.has(unit,key,harmful,caster)
    local list=M[key] or {}
    for _,id in ipairs(list) do local active,remain,stacks=U.aura(unit,id,harmful,caster);if active then return true,remain,stacks,id end end
    return false,nil,0,nil
end
return M
