-- World-coordinate landmarks imported from the public CopilotBuddy BGBuddy profiles.
-- Links describe conservative objective corridors; Sentinel pathfinds each leg.
local D={}
local function p(x,y,z) return {x=x,y=y,z=z} end
D.warsong={source="live_warsong_census",verified_custom=true,direct=false,avoid_mount=true,waypoint_radius=8,nodes={
 -- Flag-object coordinates are not navigation corridor points. The old graph
 -- selected h_flag as the nearest node from the Horde spawn and repeatedly
 -- pulled healers back into the room. These are observed room/tunnel/field
 -- positions from successful WSG runs.
 h_room=p(975.0,1436.0,345.0),h_turn=p(1021.4,1411.0,341.4),
 h_exit=p(1058.2,1375.9,328.6),h_field=p(1086.6,1390.4,319.8),
 h_mid=p(1144.8,1558.8,308.9),a_mid=p(1317.1,1551.7,315.3),
 a_exit=p(1492.7,1457.8,344.9)},links={
 h_room={"h_turn"},h_turn={"h_room","h_exit"},h_exit={"h_turn","h_field"},
 h_field={"h_exit","h_mid"},h_mid={"h_field","a_mid"},
 a_mid={"h_mid","a_exit"},a_exit={"a_mid"}}}
D.arathi={verified_custom=true,nodes={h=p(701.6498,702.2996,-15.83955),farm=p(817.0,880.0,-56.4),bs=p(974.5204,1040.614,-44.3847),
 lm=p(849.3735,1154.198,11.49594),gm=p(1147.498,847.794,-109.6731),st=p(1164.465,1198.99,-56.4528),a=p(1292.919,1291.104,-13.14064)},
 links={h={"farm"},farm={"h","bs","lm"},bs={"farm","lm","gm","st"},lm={"farm","bs","st"},gm={"bs","st"},st={"bs","lm","gm","a"},a={"st"}}}
D.arathi_blitz=D.arathi;D.arathi_training=D.arathi;D.arathi_comp_stomp=D.arathi
D.gilneas={verified_custom=true,nodes={h=p(1404.859,980.0989,7.429097),mine_east=p(1301.0,941.0,7.0),mine=p(1249.563,959.337,6.164304),ww=p(974.4443,948.5432,13.17166),
 lh=p(1047.119,1287.746,3.551034),a=p(909.46,1337.36,27.59665),
 -- Live 0.41.4 resurrection telemetry proved the northern graveyard descent.
 -- Keeping these short road legs prevents a single 130-yard cliff-side request.
 north_gy=p(1241.8,829.0,27.8),north_slope=p(1241.0,860.0,23.3),north_road=p(1251.5,888.6,17.7),north_turn=p(1268.0,925.0,10.0)},
 links={h={"mine_east"},mine_east={"h","mine"},mine={"mine_east","ww","lh","north_turn"},ww={"mine","lh"},lh={"mine","ww","a"},a={"lh"},
 north_gy={"north_slope"},north_slope={"north_gy","north_road"},north_road={"north_slope","north_turn"},north_turn={"north_road","mine"}}}
D.gilneas_training=D.gilneas
D.deepwind_modern={source="live_deepwind_1576",direct=false,verified_custom=true,avoid_mount=true,waypoint_radius=7,nodes={
 horde_spawn=p(-102.8,805.0,133.1),
 horde_east_gate=p(-70.3,781.3,132.3),horde_east_road=p(-35.0,755.0,126.0),
 horde_west_gate=p(-121.6,797.3,131.8),horde_west_road=p(-155.0,755.0,115.9),
 alliance_spawn=p(-250.0,205.0,133.2),alliance_exit=p(-208.5,205.3,131.3),
 quarry=p(117.3368,706.5226,134.4530),market=p(-166.5243,500.2917,109.8543),
 shrine=p(-466.6870,335.2160,127.3770),farm=p(63.3681,301.5608,124.2592),
 -- Live 1.46 telemetry proved the southern road around the Market/Farm ridge.
 -- These are observed ground positions; do not replace them with linear
 -- interpolation, which cuts southeast through the mountain near -54,425.
 -- The former -123.7,472.4 corner sits beside the Market building and was
 -- blacklisted live. Approach the capture point around its north side using
 -- positions already present in successful chronological telemetry.
 market_n1=p(-152.5,508.5,109.2),market_n2=p(-130.6,506.3,109.1),
 market_n3=p(-114.7,508.2,108.5),market_e2=p(-77.8,472.2,103.0),
 market_e3=p(-68.1,448.1,104.1),east_road_w=p(-54.0,425.6,105.0),
 east_road_mid=p(0.0,426.0,108.0),east_road_buff=p(96.1,426.1,111.1),
 farm_road=p(80.0,350.0,120.0),
 ruins=p(-374.5868,717.1719,134.3947)},links={
 horde_spawn={"horde_east_gate","horde_west_gate"},
 horde_east_gate={"horde_spawn","horde_east_road"},horde_east_road={"horde_east_gate","quarry","market"},
 horde_west_gate={"horde_spawn","horde_west_road"},horde_west_road={"horde_west_gate","ruins","market"},
 alliance_spawn={"alliance_exit"},alliance_exit={"alliance_spawn","farm","shrine"},
 quarry={"market","east_road_buff","horde_east_road"},
 market={"market_n1","quarry","shrine","ruins","horde_east_road","horde_west_road"},
 market_n1={"market","market_n2"},market_n2={"market_n1","market_n3"},
 market_n3={"market_n2","market_e2"},market_e2={"market_n3","market_e3"},
 market_e3={"market_e2","east_road_w"},east_road_w={"market_e3","east_road_mid"},
 east_road_mid={"east_road_w","east_road_buff"},east_road_buff={"east_road_mid","farm_road","quarry"},
 farm_road={"east_road_buff","farm"},
 ruins={"market","shrine","horde_west_road"},farm={"farm_road","shrine","alliance_exit"},
 shrine={"market","farm","ruins","alliance_exit"}}}
D.deepwind_blitz=D.deepwind_modern
D.eye_standard={source="live_eye_role_corridors",verified_custom=true,waypoint_radius=5,nodes={
 -- Repeated live samples established the west spawn ramp and the safe platform
 -- lanes.  The old five-node graph drew long diagonals through ruins and over
 -- the center drop; these short corridor controls keep steering on walkable
 -- ground and enter each objective from its ramp.
 west_spawn=p(1804.4,1539.6,1248.7),west_ramp_high=p(1837.8,1540.9,1234.1),
 west_ramp_mid=p(1892.7,1542.6,1198.8),west_ramp_low=p(1972.8,1545.1,1171.9),
 west_cross=p(2035.4,1545.2,1165.3),center_w=p(2088.6,1556.5,1157.9),
 flag=p(2174.99,1569.236,1159.942),
 fr_lane=p(2055.2,1612.9,1166.0),fr_ramp=p(2027.3,1652.0,1174.7),fr_turn=p(2019.6,1682.4,1182.1),
 fr=p(2042.904,1738.793,1190.063),
 be_lane=p(2040.3,1521.9,1165.1),be_ramp=p(2037.0,1466.7,1169.6),
 be=p(2048.365,1396.737,1194.286),
 east_cross=p(2223.8,1588.7,1167.2),mt_ramp=p(2255.0,1650.0,1177.0),
 mt=p(2285.397,1726.766,1188.291),dr_ramp=p(2255.0,1490.0,1178.0),
 dr=p(2285.415,1391.91,1196.19)},links={
 west_spawn={"west_ramp_high"},west_ramp_high={"west_spawn","west_ramp_mid"},
 west_ramp_mid={"west_ramp_high","west_ramp_low"},west_ramp_low={"west_ramp_mid","west_cross"},
 west_cross={"west_ramp_low","center_w","fr_lane","be_lane"},center_w={"west_cross","flag","fr_lane","be_lane"},
 flag={"center_w","east_cross"},
 fr_lane={"west_cross","center_w","fr_ramp"},fr_ramp={"fr_lane","fr_turn"},fr_turn={"fr_ramp","fr"},fr={"fr_turn"},
 be_lane={"west_cross","center_w","be_ramp"},be_ramp={"be_lane","be"},be={"be_ramp"},
 east_cross={"flag","mt_ramp","dr_ramp"},mt_ramp={"east_cross","mt"},mt={"mt_ramp"},
 dr_ramp={"east_cross","dr"},dr={"dr_ramp"}}}
D.eye_blitz=D.eye_standard;D.eye_blitz_legacy=D.eye_standard
D.seething={source="live_seething_1803_907",verified_custom=true,direct=false,nodes={
 west=p(1243.2,2721.5,11.9),west_bend=p(1304.0,2703.1,4.3),
 south_mid=p(1383.5,2695.0,3.3),east=p(1441.1,2700.2,9.8),
 north=p(1343.7,2919.9,33.1)},links={
 west={"west_bend","north"},west_bend={"west","south_mid","north"},
 south_mid={"west_bend","east","north"},east={"south_mid"},
 north={"west","west_bend","south_mid"}}}
D.alterac={nodes={
 fh=p(-1402.618,-306.1053,89.5062),fk=p(-1360.146,-253.3394,99.36983),fw=p(-1298.302,-267.0432,114.1503),fg=p(-1084.617,-346.1363,55.09029),
 tp=p(-769.136,-361.7828,90.89497),ib=p(-611.9578,-394.7544,60.854),ig=p(-542.7599,-163.3699,57.0109),shb=p(-159.6747,-459.7626,40.38681),
 sf=p(-204.8813,-113.6155,78.56417),sho=p(-44.49652,-288.391,15.07864),shg=p(76.7593,-403.4769,46.47937),iw=p(203.2704,-359.8108,56.38459),
 dbs=p(553.1511,-77.37878,51.92493),spg=p(670.7874,-292.2694,30.27469),db=p(683.8859,-21.60244,50.61976)},
 order={"fh","fk","fw","fg","tp","ib","ig","shb","sf","sho","shg","iw","dbs","spg","db"}}
D.isle={nodes={h=p(1168.348,-761.9674,48.62987),hk=p(1339.021,-765.8522,60.81643),hangar=p(735.1211,-1104.929,134.566),
 ak=p(238.8202,-812.9496,59.5785),a=p(391.5189,-833.1606,48.62804)},links={h={"hk","hangar"},hk={"h","hangar"},hangar={"hk","ak","h","a"},ak={"hangar","a"},a={"ak","hangar"}}}
D.strand={nodes={beach=p(1545.061,99.0054,5.628502),purple=p(1249.467,68.25315,42.67157),red=p(1257.36,-198.2806,46.36218),
 yellow=p(1094.945,-106.6107,72.15096),relic=p(962.5902,-106.6647,93.86793)},links={beach={"purple","red"},purple={"beach","yellow"},red={"beach","yellow"},yellow={"purple","red","relic"},relic={"yellow"}}}
D.twin_peaks={source="live_twin_peaks_2106_1339",verified_custom=true,chronological=true,direct=false,waypoint_radius=6,nodes={
 -- Live 0.75.8 telemetry proved the complete southern valley crossing.  The
 -- former two-node graph asked Sentinel to solve one 610-yard diagonal with a
 -- 70-yard elevation change, which repeatedly returned an unusable height and
 -- stranded the player in the river depression.  Keep every request on the
 -- observed road, river floor and east-base ascent instead.
 h_room=p(1552.0,328.5,1.6),h_gate=p(1557.4,309.8,0.1),h_road=p(1600.3,287.5,0.1),
 h_slope=p(1657.7,268.6,-6.8),valley_w=p(1716.5,254.3,-8.7),food_w=p(1754.2,242.1,-14.1),
 river_w=p(1806.8,230.5,-22.4),river_mid=p(1849.5,221.1,-28.0),
 river_cross=p(1883.3,215.0,-24.4),river_e=p(1918.1,200.1,-22.0),
 east_slope_low=p(1965.8,215.0,-3.6),east_bank=p(1992.1,210.9,0.5),east_slope_mid=p(2020.5,170.9,4.9),
 east_slope_high=p(2043.0,159.9,13.0),a_approach=p(2096.7,146.0,36.2),
 a_gate=p(2118.1,154.7,43.6),a_room=p(2117.6,191.7,44.1)},links={
 h_room={"h_gate"},h_gate={"h_room","h_road"},h_road={"h_gate","h_slope"},
 h_slope={"h_road","valley_w"},valley_w={"h_slope","food_w"},
 food_w={"valley_w","river_w"},river_w={"food_w","river_mid"},
 river_mid={"river_w","river_cross"},river_cross={"river_mid","river_e"},
 river_e={"river_cross","east_slope_low"},east_slope_low={"river_e","east_bank"},
 east_bank={"east_slope_low","east_slope_mid"},east_slope_mid={"east_bank","east_slope_high"},
 east_slope_high={"east_slope_mid","a_approach"},
 a_approach={"east_slope_high","a_gate"},a_gate={"a_approach","a_room"},
 a_room={"a_gate"}}}
D.kotmogu={source="verified_kotmogu_orb_landmarks",verified_custom=true,nodes={
 purple=p(1850.2170,1416.8229,13.3382),green=p(1716.8923,1416.6180,13.2056),
 blue=p(1716.9479,1250.0173,13.3266),orange=p(1850.1666,1250.1180,13.2056),
 center=p(1783.55,1333.42,13.25)},links={
 purple={"center"},green={"center"},blue={"center"},orange={"center"},
 center={"purple","green","blue","orange"}}}
D.ashran={source="wow_areapoi_12_1_0_69933",nodes={
 alliance=p(3994.8665,-4095.4810,57.4092),overwatch=p(4226.8892,-4171.1978,31.9758),
 vanguard=p(4353.5679,-4190.1895,11.2362),crossroads=p(4535.0190,-4211.8213,8.5273),
 advance=p(4678.3145,-4222.1963,11.2593),emberfall=p(4801.4731,-4211.3647,32.9594),
 horde=p(5052.5962,-4184.4946,45.4820),ogre=p(4532.8960,-4380.8960,20.5972),
 ancient=p(4531.2734,-3758.1702,26.7677)},links={
 alliance={"overwatch"},overwatch={"alliance","vanguard"},
 vanguard={"overwatch","crossroads"},crossroads={"vanguard","advance","ogre","ancient"},
 advance={"crossroads","emberfall"},emberfall={"advance","horde"},horde={"emberfall"},
 ogre={"crossroads"},ancient={"crossroads"}}}
D.slayers_rise={source="wow_areapoi_12_1_0_69933",nodes={
 grief=p(3116.4500,-1467.7900,-66.1639),valor=p(2902.6001,-825.5210,-137.3730),
 path=p(3256.7700,-206.7710,-207.5750),might=p(3278.6499,514.0630,-199.3820),
 hate=p(3749.1299,1004.4200,-129.6420),sparring=p(3802.8701,-959.6530,-159.2860),
 shadowridge=p(3525.0901,-741.3510,-173.8230),refinery=p(3829.1001,-442.4870,-204.9880),
 stareater=p(3931.8999,36.3638,-205.7160),husk=p(4162.8301,-71.8802,-336.4770)},links={
 grief={"valor"},valor={"grief","path","shadowridge","sparring"},
 path={"valor","might","shadowridge","refinery"},might={"path","hate","stareater","husk"},
 hate={"might"},sparring={"valor","shadowridge","refinery"},
 shadowridge={"valor","path","sparring","refinery"},
 refinery={"path","sparring","shadowridge","stareater","husk"},
 stareater={"might","refinery","husk"},husk={"might","refinery","stareater"}}}
-- Coordinates are verified Wintergrasp world-space landmarks from the open-source
-- mod-wintergrasp-bots director.  Long field crossings are split through road/muster
-- nodes so Sentinel receives bounded, connected legs instead of one map-wide request.
D.wintergrasp={source="azerothcore_wintergrasp_bots",nodes={
 east=p(4398.08,2356.50,376.19),east_road=p(4526,2810,391.20),
 sunken=p(4949.34,2432.59,320.18),sunken_road=p(5081,2287,365.00),
 west=p(4390.78,3304.09,372.43),west_road=p(4573,3475,363.01),
 broken=p(4948.52,3342.34,376.88),field=p(4900,2841,390),
 gate=p(5145,2841,409),muster=p(5185,2855,409),courtyard=p(5240,2841,409),
 arch_w=p(5250,2841,409),arch_e=p(5292,2841,409),last_door=p(5360,2841,414),
 relic=p(5440.379,2840.493,430.282)},links={
 east={"east_road","sunken"},east_road={"east","field"},
 sunken={"east","sunken_road","field"},sunken_road={"sunken","field"},
 west={"west_road","broken"},west_road={"west","field"},
 broken={"west","field"},field={"east_road","sunken","sunken_road","west_road","broken","gate"},
 gate={"field","muster"},muster={"gate","courtyard"},courtyard={"muster","arch_w"},
 arch_w={"courtyard","arch_e"},arch_e={"arch_w","last_door"},
 last_door={"arch_e","relic"},relic={"last_door"}}}
-- Recorded trace graphs cover moving-objective maps whose useful corridors
-- cannot be represented by a few static objective landmarks.
local Recorded=require("bg_recorded_route_data")
local Legacy=require("bg_legacy_recorded_route_data")
-- Keep the authored objective graph as a map-wide backbone and attach the
-- denser, physically traversed graph separately.  The route selector uses a
-- recorded component only when both endpoints are close to that same
-- component; this prevents a disconnected telemetry island from inventing a
-- link across a wall, cliff or separate floor.
local recorded_names={"arathi","deephaul","deepwind_modern","eye_standard","gilneas","kotmogu","seething","silvershard","warsong"}
-- Every ruleset variant that uses the same physical map must resolve through
-- the canonical profile before recorded telemetry is attached.  Sharing the
-- landmark table alone is insufficient: without this mapping the variant gets
-- the sparse backbone but silently misses the dense, walked route component.
local aliases={
 silvershard_training="silvershard",
 arathi_training="arathi",arathi_comp_stomp="arathi",arathi_blitz="arathi",
 gilneas_training="gilneas",
 deepwind_blitz="deepwind_modern",
 eye_blitz="eye_standard",eye_blitz_legacy="eye_standard"
}
local prepared={}
local function graph(profile)
 local canonical=aliases[profile] or profile
 if prepared[canonical] then return D[canonical] end
 local recorded=Recorded[canonical]
 local g=D[canonical] or Legacy[canonical] or recorded
 if not g then return nil end
 D[canonical]=g
 if recorded and g~=recorded then g.recorded=recorded end
 if recorded then g.verified_custom=true end
 if g.order and not g.links then
  g.links={};for i,id in ipairs(g.order) do g.links[id]={};if i>1 then g.links[id][#g.links[id]+1]=g.order[i-1] end;if i<#g.order then g.links[id][#g.links[id]+1]=g.order[i+1] end end
 end
 prepared[canonical]=true;return g
end
-- Proxy every read so dense live telemetry is compiled only for the map that
-- requests it. __pairs preserves complete offline audits without making hot
-- reload pay for all nine battleground graphs.
return setmetatable({}, {
 __index=function(_,profile) return graph(profile) end,
 __newindex=function(_,profile,value) D[profile]=value;prepared[profile]=nil end,
 __pairs=function()
  local keys,seen={},{}
  for key in pairs(D) do keys[#keys+1]=key;seen[key]=true end
  for _,key in ipairs(recorded_names) do if not seen[key] then keys[#keys+1]=key;seen[key]=true end end
  for key in pairs(aliases) do if not seen[key] then keys[#keys+1]=key end end
  table.sort(keys);local index=0
  return function() index=index+1;local key=keys[index];if key then return key,graph(key) end end
 end
})
