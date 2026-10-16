-- Planning data only: never substitute zone bands for executable quest routes.
-- Forever-specific coordinates must come from matching live/addon records.
local M={edition="Forever",min_level=31,max_level=60,provisional=true}
M.bands={
 {min=31,max=34,Alliance={"Stranglethorn Vale","Arathi Highlands","Desolace"},Horde={"Stranglethorn Vale","Desolace","Arathi Highlands"}},
 {min=35,max=44,Alliance={"Riverglades","Stranglethorn Vale","Dustwallow Marsh"},Horde={"Riverglades","Stranglethorn Vale","Dustwallow Marsh"},forever_zone="Riverglades"},
 {min=45,max=49,Alliance={"Tanaris","Feralas","The Hinterlands"},Horde={"Tanaris","Feralas","The Hinterlands"}},
 {min=50,max=54,Alliance={"Un'Goro Crater","Searing Gorge","Felwood"},Horde={"Un'Goro Crater","Searing Gorge","Felwood"}},
 {min=55,max=60,Alliance={"Western Plaguelands","Eastern Plaguelands","Winterspring","Burning Steppes"},Horde={"Western Plaguelands","Eastern Plaguelands","Winterspring","Burning Steppes"}}
}
function M.for_character(level,faction)
 if faction~="Alliance" and faction~="Horde" then return nil,"faction_required" end
 if type(level)~="number" then return nil,"level_required" end
 for _,band in ipairs(M.bands) do
  if level>=band.min and level<=band.max then
   local zones={};for i,zone in ipairs(band[faction]) do zones[i]=zone end
   return {zones=zones,min_level=band.min,max_level=band.max,provisional=true,
    requires={"Forever quest identities","action coordinates","prerequisite checks","Sentinel mesh","transport links"}}
  end
 end
 return nil,"outside_plan_range"
end
return M
