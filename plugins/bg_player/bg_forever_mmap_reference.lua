-- Inventory from the supplied UNVERIFIED legacy archive. This is diagnostic
-- evidence only; it must never be treated as proof that the active server has
-- these files or that they match the running Forever build.
local R={
 target_build="1.60.1.70245",verified=false,status="unverified_legacy",
 map_headers=98,tile_files=3412,known_unusable_maps={[616]=true},
 profiles={
  alterac={map_id=30,header=true,tiles=27},
  warsong={map_id=489,header=true,tiles=12},
  arathi={map_id=529,header=true,tiles=16},
  darkspear_islands={map_id=2524,header=false,tiles=0},
 }
}
function R.coverage(profile)
 local row=R.profiles[profile]
 if not row then return {profile=profile,status="unknown_profile",verified=false} end
 return {profile=profile,map_id=row.map_id,header=row.header,tiles=row.tiles,verified=false,
  status=row.header and "legacy_present_unverified" or "legacy_missing"}
end
function R.report(profile)
 local row=R.coverage(profile)
 if not row.map_id then return "unknown profile / active ArthasNav probe required" end
 return string.format("%s map %d / legacy header=%s tiles=%d / unverified for build %s",
  tostring(profile),row.map_id,tostring(row.header),row.tiles,R.target_build)
end
return R
