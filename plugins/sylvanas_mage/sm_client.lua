local M={}
local function read(fn,...)
 if type(fn)~='function'then return nil end
 local ok,a,b,c=pcall(fn,...);if ok then return a,b,c end
end
function M.text()
 local probes={core and core.get_game_version,core and core.get_client_version,core and core.get_build_info,
  core and core.game and core.game.get_version,core and core.game and core.game.get_build_info}
 for _,fn in ipairs(probes)do
  local a,b,c=read(fn);local value=table.concat({tostring(a or''),tostring(b or''),tostring(c or'')},' '):lower()
  if value:gsub('%s','')~=''then return value end
 end
 local nav=rawget(_G,'ArthasNav');return nav and tostring(nav.GAME_VERSION or''):lower()or''
end
function M.detect(allow_ready_probe)
 local v=M.text()
 if v:find('forever',1,true)or v:find('1.60.',1,true)then return'forever',v end
 if v:find('midnight',1,true)then return'midnight',v end
 -- Never probe the spell database during bootstrap. After the caller's
 -- readiness delay, Forever-only Mage spells can safely disambiguate hosts
 -- that report only the generic Classic family.
 if allow_ready_probe then
  local known=core and core.spell_book and core.spell_book.is_spell_known
  local forever=read(known,400574)==true or read(known,1312002)==true or read(known,400624)==true
  local era=read(known,30451)==true or read(known,190319)==true or read(known,84714)==true
  if forever and not era then return'forever','delayed Forever-only Mage spell fingerprint'end
 end
 return nil,v~=''and v or'client unavailable'
end
return M
