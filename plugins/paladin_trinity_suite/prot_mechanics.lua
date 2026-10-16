-- Method Midnight Season 2 dungeon mechanics used by predictive defense.
-- BigWigs/LittleWigs bar text and live cast names are matched inside the
-- current dungeon only. Scores represent defensive urgency, not raw damage.
local M = {}
local Dungeon=require("prot_dungeon")
local SpellIDs=require("prot_spell_ids")

local DATA = {
    altaroffangs = {
        critical = { "Chop Down", "Tail Scythe" },
        heavy = { "Corrosive Fangs", "Noxious Spray", "Dismember" },
        moderate = { "Ravenous Stomp", "Death Rattle", "Rattle", "Blood Sacrifice" },
    },
    denofnalorakk = {
        critical = { "Shredding Claws" },
        heavy = { "Bestial Wrath", "Shred Armor", "Mother's Wrath", "Mothers Wrath" },
        moderate = { "Feast of Misery", "Feast Of Misery", "Ravenous Bellow", "Hearty Bellow", "Primal Echo" },
    },
    kingsrest = {
        critical = { "Debilitating Backhand", "Soul Crush", "Blade Combo" },
        heavy = { "Mortal Bleed", "Tail Thrash" },
        moderate = { "Seismic Upheaval", "Barrel Through", "Drain Fluids",
            "Serpentine Gust", "Awakening Slam" },
    },
    murderrow = {
        critical = { "Demonic Frenzy", "Envenom" },
        heavy = { "Shield Bash", "Glaive Toss", "Infernal Crush", "Demonic Rage",
            "Chaos Barrage" },
        moderate = { "Killing Spree", "Destabilized" },
    },
    rubylifepools = {
        critical = { "Searing Blows", "Steel Barrage", "Flaming Barrage" },
        heavy = { "Crushing Smash", "Fire Maw", "Fiery Blast", "Stormslam" },
        moderate = { "Inferno", "Excavating Blast", "Molten Blood" },
    },
    templeofsethraliss = {
        critical = { "Lightning Bite", "Sunder Slam", "Consume Charge", "Heart Attack" },
        heavy = { "Venomous Slash", "Overload", "Vile Charge", "Tainted Strike" },
        moderate = { "Caustic Stomp", "Ground Pound", "Serpentstorm" },
    },
    theblindingvale = {
        critical = { "Bedrock Slam" },
        heavy = { "Grievous Gash", "Grievous Thrash", "Thornspike" },
        moderate = { "Toxic Spew", "Thornblade", "Thorncaller Roar" },
    },
    blindingvale = false,
    voidscararena = {
        critical = { "Hulking Claw", "Void Blast" },
        heavy = { "Rip And Slice", "Rip and Slice", "Shred Defense", "Head Bash", "Melt Armor" },
        moderate = { "Corrosive Essence", "Monstrous Roar", "Insidious Aura" },
    },
}
DATA.blindingvale = DATA.theblindingvale

local function current_data()
    local key=Dungeon.key()
    return key and DATA[key] or nil
end

local function contains(text, names)
    text = string.lower(tostring(text or ""))
    for _, name in ipairs(names or {}) do
        if text:find(string.lower(name), 1, true) then return name end
    end
end

function M.classify(name,spell_id)
    local data = current_data()
    if not data then return 0, nil, nil end
    local key=Dungeon.key()
    local function id_match(names)
        for _,candidate in ipairs(names or {}) do
            if SpellIDs.matches(key,candidate,spell_id) then return candidate end
        end
    end
    local matched = id_match(data.critical) or contains(name, data.critical)
    if matched then return 30, "critical", matched end
    matched = id_match(data.heavy) or contains(name, data.heavy)
    if matched then return 20, "heavy", matched end
    matched = id_match(data.moderate) or contains(name, data.moderate)
    if matched then return 12, "moderate", matched end
    return 0, nil, nil
end

return M
