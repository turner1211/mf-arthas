-- Client-family and Rogue-tree detection. Retail and Forever fingerprints are
-- intentionally kept here so neither rotation imports the other's rules.
local M={branch='retail',spec='assassination',evidence='default retail',branch_locked=false}
local function read(fn,...)
 if type(fn)~='function' then return nil end
 local ok,v=pcall(fn,...);if ok then return v end
end
local function known(id)
 return read(core.spell_book and core.spell_book.is_spell_known,id)==true
end
local function version_text()
 local probes={core.get_game_version,core.get_client_version,core.get_build_info,
  core.game and core.game.get_version,core.game and core.game.get_build_info}
 for _,fn in ipairs(probes) do
  local a,b,c=read(fn)
  local value=table.concat({tostring(a or ''),tostring(b or ''),tostring(c or '')},' '):lower()
  if value~='  ' then return value end
 end
 return ''
end
local function talent_names()
 local rows=read(core.game_ui and core.game_ui.get_active_talents)
 local names={}
 if type(rows)=='table' then for _,v in pairs(rows) do
  if type(v)=='table' then names[#names+1]=tostring(v.name or v.spell_name or ''):lower()
  else names[#names+1]=tostring(v):lower() end
 end end
 return table.concat(names,' ')
end
function M.detect(raw_spec,converted_spec)
 local v=''
 local forever=M.branch=='forever'
 if not M.branch_locked then
  v=version_text()
  local forever_version=v:find('forever',1,true)~=nil or v:find('1.60.',1,true)~=nil
  local retail_signature=converted_spec==259 or converted_spec==260 or converted_spec==261
   or raw_spec==259 or raw_spec==260 or raw_spec==261
   or known(1329) or known(193315) or known(185438)
   or known(360194) or known(315341) or known(185313)
  -- Rank-one Sinister Strike lets a brand-new Forever Rogue identify the
  -- client before Mutilate exists. Retail signatures veto overlapping IDs.
  local forever_signature=(known(1310707) or known(1752)) and not retail_signature
  forever=forever_version or forever_signature
  M.branch=forever and 'forever' or 'retail'
  M.evidence=forever_version and ('client '..v) or forever_signature and 'Forever spell fingerprint'
   or retail_signature and 'Retail spell fingerprint' or 'unconfirmed client; detection will retry'
  -- Never freeze an unconfirmed default. Some hosts expose build information
  -- one or two frames after the spellbook and player object become available.
  M.branch_locked=forever_version or forever_signature or retail_signature
 end
 if not forever then
  M.branch='retail'
  M.spec=(converted_spec==260 or raw_spec==2) and 'outlaw'
   or (converted_spec==261 or raw_spec==3) and 'subtlety' or 'assassination'
  return M.branch,M.spec,M.evidence
 end
 local talents=talent_names()
 M.branch='forever'
 if talents:find('hemorrhage',1,true) or talents:find('premeditation',1,true) or known(16511) then M.spec='subtlety'
 elseif talents:find('adrenaline rush',1,true) or talents:find('blade flurry',1,true) then M.spec='combat'
 elseif talents:find('mutilate',1,true) or talents:find('venom',1,true) or known(1310707) then M.spec='assassination'
 elseif known(13750) or known(13877) then M.spec='combat'
 else M.spec='assassination' end
 if M.evidence=='Forever spell fingerprint' then M.evidence='Forever spell/talent fingerprint' end
 return M.branch,M.spec,M.evidence
end
function M.forever_spell(family,is_known)
 if M.branch~='forever' or type(is_known)~='function' then return nil end
 local families=require('ar_forever_spells')
 for _,id in ipairs(families[family] or {}) do if is_known(id) then return id end end
end
return M
