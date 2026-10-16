local U=require('ww_util')
local I={specs={[71]='arms',[72]='fury',[73]='protection'},ids={71,72,73}}
function I.resolve(class,reported,index)
 if class~=1 then return nil,'not_warrior' end
 reported,index=U.number(reported),U.number(index)
 local a=I.specs[reported] and reported or I.ids[reported or 0]
 local b=I.ids[index or 0]
 if a and b and a~=b then return nil,'specialization_conflict' end
 if not a then return nil,'specialization_unavailable' end
 return a
end
function I.read(player)
 local class=U.number(U.call(player,'get_class'))
 local raw=core.spell_book and U.fn(core.spell_book.get_specialization_id)
 local index=core.game_ui and U.fn(core.game_ui.get_specialization)
 local version=U.fn(core.get_game_version)
 if version~='Midnight'and version~='Forever' then return nil,'unsupported_client_'..tostring(version) end
 local id,why=I.resolve(class,raw,index)
 if not id and version=='Forever'and class==1 then
  local known=core.spell_book and core.spell_book.is_spell_known
  local signatures={{71,{1310222,12292,12294,21550,21551,21552,21553}},{72,{12328,23881,23891,23892,23893,23894,25251}},{73,{12809,23922,23923,23924,23925}}}
  local found
  for _,row in ipairs(signatures)do for _,spell in ipairs(row[2])do
   if U.fn(known,spell)==true then if found and found~=row[1]then return nil,'specialization_conflict'end;found=row[1];break end
  end end
  id=found;why=id and nil or why
 end
 if not id then return nil,why end
 local expected=id==73 and 'TANK' or 'DAMAGER'
 local assigned=U.call(player,'get_group_role')
 local enums=require('common/enums')
 local role='NONE'
 if assigned==enums.group_role.TANK then role='TANK'
 elseif assigned==enums.group_role.DAMAGER then role='DAMAGER'
 elseif assigned==enums.group_role.HEALER then role='HEALER' end
 if type(assigned)=='string' then role=assigned:upper() end
 return {id=id,spec=I.specs[id],role=expected,assigned=role,
  role_conflict=role~='NONE' and role~=expected,player=U.guid(player),version=version,runtime=version=='Forever'and'forever'or'midnight'}
end
return I
