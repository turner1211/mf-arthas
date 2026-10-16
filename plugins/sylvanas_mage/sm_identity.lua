local U=require('sm_util')
local I={specs={[62]='arcane',[63]='fire',[64]='frost'},ids={62,63,64}}
function I.resolve(class,reported,index)
 if class~=8 then return nil,'not_mage' end
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
 local id,why=I.resolve(class,raw,index)
 local version=U.fn(core.get_game_version)
 if version~='Midnight' then return nil,'unsupported_client_'..tostring(version) end
 if not id then return nil,why end
 local expected='DAMAGER'
 local assigned=U.call(player,'get_group_role')
 local enums=require('common/enums')
 local role='NONE'
 if assigned==enums.group_role.TANK then role='TANK'
 elseif assigned==enums.group_role.DAMAGER then role='DAMAGER'
 elseif assigned==enums.group_role.HEALER then role='HEALER' end
 if type(assigned)=='string' then role=assigned:upper() end
 if not U.guid(player) then return nil,'player_identity_unavailable' end
 return {id=id,spec=I.specs[id],role=expected,assigned=role,
  role_conflict=role~='NONE' and role~=expected,player=U.guid(player),version=version}
end
return I
