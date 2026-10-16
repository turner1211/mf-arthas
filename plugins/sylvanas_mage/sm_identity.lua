local U,Client=require('sm_util'),require('sm_client')
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
 local family,evidence=Client.detect()
 if not family then return nil,'client_unconfirmed_'..tostring(evidence)end
 if family=='forever'then
  if class~=8 then return nil,'not_mage'end
  local known=core.spell_book and core.spell_book.is_spell_known
  local trees={
   [62]={6057,11222,11237,11210,29441,11213,28574,11247,11242,400574,11252,11255,18462,400588,12043,11232,15058,12042},
   [63]={11078,18459,11069,11119,11100,11103,11083,11108,11366,11095,11094,400624,29074,11115,11113,11124,11129},
   [64]={11189,11070,29438,11207,11175,11165,11071,11151,11160,1312002,11185,16757,11958,11170,11190,12472,400647,11180,11426}}
  local score={[62]=0,[63]=0,[64]=0};local cap={[62]={12042,400574},[63]={11129,400624},[64]={11426,400647}}
  for id,list in pairs(trees)do for _,spell in ipairs(list)do if U.fn(known,spell)==true then score[id]=score[id]+1 end end end
  for id,list in pairs(cap)do for _,spell in ipairs(list)do if U.fn(known,spell)==true then score[id]=score[id]+3 end end end
  local id,best,tie=nil,-1,false
  for _,candidate in ipairs(I.ids)do local n=score[candidate];if n>best then id,best,tie=candidate,n,false elseif n==best then tie=true end end
  if not id or best<=0 or tie then return nil,'forever_tree_unavailable_or_tied'end
  if not U.guid(player)then return nil,'player_identity_unavailable'end
  return{id=id,spec=I.specs[id],role='DAMAGER',assigned='NONE',role_conflict=false,
   player=U.guid(player),version='Forever',client_family='forever',client_evidence=evidence,tree_score=score}
 end
 local raw=core.spell_book and U.fn(core.spell_book.get_specialization_id)
 local index=core.game_ui and U.fn(core.game_ui.get_specialization)
 local id,why=I.resolve(class,raw,index)
 local version=U.fn(core.get_game_version)
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
  role_conflict=role~='NONE' and role~=expected,player=U.guid(player),version=version,client_family='midnight',client_evidence=evidence}
end
return I
