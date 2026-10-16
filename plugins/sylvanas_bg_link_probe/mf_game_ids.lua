-- Locale-independent spell identities already verified by this repository's
-- guardian_dungeon_priorities.lua. English names are matching keys, not UI text.
local M={}
local spells={
 [372743]='ice shield',[372808]='frigid shard',[1305955]='fiery blast',[373017]='blaze volley',
 [1216570]='fel missiles',[1201554]='seduction',[1264106]='felstorm',[1214922]='fel rage',
 [474375]='chaos bolt',[1294557]='piercing hiss',[1306385]='evolve',[1307567]='mass envenom',
 [1289426]='envenom',[1297696]='healing breeze',[1235829]='shroud of winter',
 [1297778]='arc lightning',[1309919]='frigid roar',[1238294]='disorienting screech',
 [1301834]='light bolt volley',[1235616]='light bolt',[1239821]="warden's wrath",
 [1247669]='lightspore shot',[1298899]='demoralizing shout',[1299938]='shadowbolt volley',
 [1310324]='mending void',[1249621]='violent sand',[1233398]='mad shriek',
 [1308100]='poisoned cheap shot',[1293307]='addle mind',[267027]='poison spit',
 [1303535]='essence disruption',[268013]='flame shock',[269972]='hex volley',
 [270920]='bind soul',[270901]='unholy mending',[267763]='wretched discharge',
 [270492]='hex',[267273]='poison nova',[269369]='deathly roar',
 [1310547]='toxic atrophy',[1310358]='toxic atrophy',[1302158]='flame shock'
}
function M.spell_name(id,localized)
 return spells[tonumber(id)]or(type(localized)=='string'and localized or tostring(id or''))
end
function M.is_spell(id,names,localized)return names[M.spell_name(id,localized):lower()]==true end
local dungeons={[1762]="King's Rest",[1877]='Temple of Sethraliss',[2521]='Ruby Life Pools',[2813]='Murder Row',[2825]='Den of Nalorakk',[2859]='The Blinding Vale',[2923]='Voidscar Arena',[2966]="Torment's Rise",[2993]='Altar of Fangs',[3079]='Venomfall Deeps'}
function M.dungeon_name(id,localized)return dungeons[tonumber(id)]or localized end
return M
