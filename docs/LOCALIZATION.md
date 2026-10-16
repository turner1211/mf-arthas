# Shared language support

All 16 projects ship the same `mf_i18n.lua`, `mf_locales.lua`, `mf_unicode_font.lua` and `mf_game_ids.lua`, generated from `shared/`. Edit the shared originals; `tools/update_manifests.py` distributes them and refreshes each project's file sizes, SHA-256 values and build identifier.

## Languages and honest coverage

The bundled catalogs contain the same 269 keys for English, German, French, Spanish, Italian, Portuguese, Russian, Korean, Simplified Chinese, Traditional Chinese and Japanese. English UK, Spanish Mexico and Portuguese Portugal use the corresponding language catalogs. Chinese script/region variants map to the appropriate Chinese catalog. These are interface translations, not new gameplay rules.

This is a shared localization framework across every compatible plugin, **not a claim that every human language or every plugin-specific sentence has been translated**. Missing phrases stay in English. Technical logs, spell IDs, route protocol fields, setting identifiers and exact user-entered character names are not translated. Existing locale-sensitive heuristics outside the specifically changed ID lookups can still require review. Long custom guides and downstream addon content need their own translated data.

Choose **Interface language** in any installed plugin's native menu, or use the language button on MasterArthasNav's Setup tab. The selection is shared between loaded plugins and saved to `scripts_data/master_arthas_nav.locale`. Automatic mode uses a supported `GetLocale`/host locale reader when one is exposed. Otherwise it selects English until the user chooses a language. It does not guess the game language from the Windows account or folder name.

## Additional language packs

Any valid locale tag is accepted. Register a pack with `require('mf_i18n').register('pl-PL', {SETTINGS='USTAWIENIA'})`, then select it with `set_locale('pl-PL')`. For a persistent pack, provide `mf_locales/pl-pl.lua` returning the phrase table, or add it to `shared/mf_locales.lua` and the shared `languages` selector. Locale tags are validated before module lookup; paths are rejected. Missing keys or missing packs use the original English bytes.

## Rendering

The shared scope wraps only the owning plugin's initialization and callbacks. Native menu constructors and graphics functions are restored after each call, including when a callback raises an error. Control IDs, stored values, click coordinates, callback arguments and return values are preserved. Old language-layer callbacks are generation-guarded after reload. The original `header.lua`, `main.lua` and the installed HTTP loader files keep their roles; the downloaded manifest enters through `mf_entry.lua` before requiring the original application.

Twenty-three GUI/text helpers were changed to preserve UTF-8 instead of replacing non-ASCII characters with underscores or splitting multibyte strings. MasterArthasNav also measures translated strings before drawing to avoid oversized labels.

The bundled, openly licensed GNU Unifont 18.0.01 fallback covers the Unicode BMP. It is fetched asynchronously from this repository and cached once when a non-English custom GUI needs it. The local installer seeds the cache. The host's font loader and native menu widgets must still be checked in the actual game; neither the font nor this layer guarantees complex-script shaping or right-to-left layout. A host-specific font can be supplied with `set_font(font_id)`.

## Gameplay language boundaries

Known dangerous casts in Warrior, Hunter, Mage, Retribution and Paladin Trinity use spell IDs already verified in the Guardian priority data. Retribution/Trinity dungeon route selection also resolves the known dungeon names from the instance ID, retaining the client's localized name for display. Other game API inputs and outputs are not globally rewritten. Unknown casts keep the existing fallback behavior.

## Tests

`python tools/verify.py` validates every manifest, installs all 16 synthetic plugin packages through the existing async loader, compiles downloaded Lua, and exercises locale aliases, every catalog key, Unicode clipping, numeric combat identities, shared language changes, native-control forwarding, reload guards, callback cleanup, and asynchronous font loading. These are offline tests, not live WoW validation.
