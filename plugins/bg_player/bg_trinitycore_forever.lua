-- Concrete battleground identifiers and positions imported from TrinityCore
-- commit 7abb5096bc06ecde73455d0456e9044a85c862af.
local T={commit="7abb5096bc06ecde73455d0456e9044a85c862af"}
T.queue_slots=3
T.status={none=0,wait_queue=1,preparation=2,active=3,finished=4}
T.battlemaster={alterac=1,warsong=2,arathi=3,eye=7,strand=9,isle=30,random=32,
 twin_peaks=108,gilneas=120,kotmogu=699,silvershard=708,deepwind=754,seething=894,random_epic=901,
 warsong_ctf=1014,wintergrasp_epic=1017,arathi_domination=1018,arathi_comp_stomp=1019,
 ashran_epic=1020,random_modern=1029,korraks_revenge=1033,deepwind_domination=1037}
T.brawls={gilneas_old=846,arathi_winter=847,deepwind_dunk=849,temple_hotmogu=858,
 gravity_lapse=859,warsong_scramble=861,eye_of_the_horn=862,deep_six=879,arathi=880,
 deepwind=881,eye=882,silvershard=883,kotmogu=884,gilneas=885,warsong=886}
T.powerups={speed=179871,restoration=179904,berserking=179905}
T.silvershard={map=727,cart_entries={[60140]=true},gates={212939,212940,212941,212942},spawns={
 south={x=739.29517,y=203.76389,z=319.54398},east={x=744.5174,y=183.19792,z=319.54395},north={x=759.32465,y=198.3316,z=319.53058}}}
T.kotmogu={orbs={
 {id="purple",entry=212092,position={x=1850.2170,y=1416.8229,z=13.3382}},
 {id="green",entry=212093,position={x=1716.8923,y=1416.6180,z=13.2056}},
 {id="blue",entry=212091,position={x=1716.9479,y=1250.0173,z=13.3266}},
 {id="orange",entry=212094,position={x=1850.1666,y=1250.1180,z=13.2056}}},healing={
 {x=1868.2396,y=1391.1198,z=11.52903},{x=1697.9149,y=1275.7673,z=12.16028},
 {x=1698.4271,y=1391.7951,z=11.75756},{x=1867.8836,y=1274.8872,z=11.85079}}}
T.deephaul={crystal_entry=422413,cart_entries={[214690]=true,[217346]=true,[211155]=true,[211271]=true},
 control_entries={east=430211,west=430216,cap=430207},spells={crystal=434339,restoration=296575,berserking=296576,frequency=422968},
 gates={437274,446147},spawns={west={x=4250.3647,y=-2751.066,z=239.46973},east={x=3875.0,y=-3150.0,z=240.2913}},
 horde_carts={{x=4179.265625,y=-2788.071289,z=240.735886},{x=4163.166016,y=-2809.192627,z=240.864441},
  {x=4171.251953,y=-2798.543457,z=240.813614},{x=4175.225586,y=-2793.239502,z=240.793503},{x=4167.109375,y=-2803.795166,z=240.978973}},
 alliance_carts={{x=3949.052979,y=-3106.71875,z=240.960846},{x=3961.213623,y=-3090.671875,z=241.011582},
  {x=3957.064209,y=-3095.954834,z=240.801407},{x=3965.46875,y=-3084.965332,z=240.854004},{x=3953.146729,y=-3101.300293,z=240.92868}}}
return T
