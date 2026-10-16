-- Manifest entry shared by every project; installed loader files stay fixed.
-- The original main.lua remains the application and is run exactly once.
local Language=require('mf_i18n')
Language.start(require('mf_project'))
return Language.with_scope(function()return require('main')end)
