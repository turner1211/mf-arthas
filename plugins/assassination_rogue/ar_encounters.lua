-- Exact BigWigs timer keys or labels, by instance name. Localized labels must match.
-- Add known party-wide AoE bars to enable preemptive Feint without Elusiveness.
-- Personal mechanics should use targeted=true; the rotation then requires enemy
-- active spell target to confirm the player before spending Cloak or Evasion.
-- Example (replace with real observed names, do not enable the placeholder):
-- ["Instance Name"] = {["Exact Timer Label"]={kind="aoe"}}
-- Valid kinds: aoe, magic, physical. Unmapped bars are displayed and logged only.
-- Optional reviewed spatial fields: radius=<yards>, center="target" or "caster".
-- Never add a radius from a guess: BigWigs supplies timing, not ground geometry.
return { ["*"]={
 ["Shadowbolt Volley"]={kind="aoe"},
 [1299938]={kind="aoe"},
 ["Violent Sand"]={kind="aoe"},
 [1249621]={kind="aoe"},
 ["Mad Shriek"]={kind="aoe"},
 [1233398]={kind="aoe"},
 ["Piercing Hiss"]={kind="aoe"},
 [1294557]={kind="aoe"},
 ["Mass Envenom"]={kind="aoe"},
 [1307567]={kind="aoe"},
 ["Light Bolt Volley"]={kind="aoe"},
 [1301834]={kind="aoe"},
 ["Disorienting Screech"]={kind="aoe"},
 [1238294]={kind="aoe"},
 ["Frigid Roar"]={kind="aoe"},
 [1309919]={kind="aoe"},
 ["Ravenous Stomp"]={kind="aoe"},
 [1307915]={kind="aoe"},
 ["Thorncaller Roar"]={kind="aoe"},
 [1236709]={kind="aoe"},
 ["Ravenous Bellow"]={kind="aoe"},
 [1234681]={kind="aoe"},
 ["Insidious Aura"]={kind="aoe"},
 [1234855]={kind="aoe"},
 ["Steel Barrage"]={kind="aoe"},
 [372047]={kind="aoe"},
 ["Frost Overload"]={kind="aoe"},
 [373680]={kind="aoe"},
 ["Molten Blood"]={kind="aoe"},
 [392569]={kind="aoe"},
 ["Inferno"]={kind="aoe"},
 [373692]={kind="aoe"},
} }
