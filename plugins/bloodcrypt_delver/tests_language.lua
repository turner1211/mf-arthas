local old_core=_G.core
local old_locale=_G.GetLocale
local old_shared=rawget(_G,"__mf_arthas_locale_state_v1")
_G.GetLocale=nil
_G.__mf_arthas_locale_state_v1=nil
_G.core={time=function() return 0 end,get_language=function() return "deDE" end}
package.path="plugins/bloodcrypt_delver/?.lua;"..package.path
package.loaded.mf_i18n=nil
local L=require("mf_i18n")
assert(L.detect()=="deDE","reflected Sylvanas get_language API must drive automatic locale detection")
_G.core=old_core
_G.GetLocale=old_locale
_G.__mf_arthas_locale_state_v1=old_shared
print("sylvanas_language_fallback=PASS")
