local M={spells={},names={},updated=-math.huge}
function M.refresh()
    if core.time()-M.updated<2 then return end
    M.updated=core.time();M.spells={};M.names={}
    if not core.game_ui.get_active_talents then return end
    local ok,list=pcall(core.game_ui.get_active_talents)
    if not ok or type(list)~="table" then return end
    for _,t in pairs(list) do
        if (tonumber(t.rank) or 0)>0 then
            if tonumber(t.spell_id) then M.spells[tonumber(t.spell_id)]=true end
            if t.name then M.names[t.name:lower()]=true end
        end
    end
end
function M.has(id,name)
    M.refresh()
    return (id and M.spells[id]==true) or (name and M.names[name:lower()]==true)
        or (id and core.spell_book.is_spell_known(id)==true) or false
end
function M.hero()
    if M.has(444995,"Surging Totem") then return "Totemic" end
    if M.has(443454,"Ancestral Swiftness") or M.has(443450,"Call of the Ancestors") then return "Farseer" end
    return "Base Restoration / hero tree not detected"
end
return M
