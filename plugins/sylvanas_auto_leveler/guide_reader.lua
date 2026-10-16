-- WoW-Pro source is parsed as data, never load()/loadstring() executed.
local M = {}
local schema = require("tag_schema")
function M.parse_step(line)
    local action, title, tail = line:match("^%s*([^%s;])%s+([^|]+)(.*)$")
    if not action then return nil end
    local tags, tokens = {}, {}
    for token in (tail .. "|"):gmatch("(.-)|") do tokens[#tokens+1] = token end
    local i = 2
    while i <= #tokens do
        local key, value = tokens[i], tokens[i+1]
        if key:match("^[A-Z][A-Z0-9_]*$") or key=="S!US" then
            if schema[key]=="boolean" then
                tags[key] = true; i = i+1
            else tags[key] = value or ""; i = i+2 end
        else i = i+1 end
    end
    return { action=action, title=title, tags=tags }
end
function M.parse(text)
    local equals, start = text:match("return%s*%[(=*)%[()")
    local body
    if start then
        local finish=text:find("]"..equals.."]",start,true)
        if finish then body=text:sub(start,finish-1) end
    end
    if not body then return nil, "literal_guide_body_required" end
    local steps,area_bonus = {},{}
    -- Commented acceptance is metadata only; never execute commented rows.
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local commented=line:match("^%s*;%s*(A%s+.+)")
        local row=commented and M.parse_step(commented)
        local note=row and tostring(row.tags.N or ""):lower() or ""
        if row and note:find("bonus objective",1,true) and note:find("autoaccepted",1,true) then
            local id=tonumber(row.tags.QID);if id then area_bonus[id]=true end
        end
    end
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local step = M.parse_step(line:gsub("\r$", ""))
        if step then steps[#steps+1] = step end
    end
    for _,step in ipairs(steps) do
        if area_bonus[tonumber(step.tags.QID)] and (step.action=="C" or step.action=="T" or step.action=="t") then
            step.optional_area_objective=true
        end
    end
    return steps
end
function M.read(relative_path)
    -- Restrict input to a Lua guide under the installed Retail guide directory.
    local edition=type(relative_path)=="string" and relative_path:match("^([^/]+)/")
    if type(relative_path) ~= "string" or relative_path:find("..", 1, true)
        or not ({Retail=true,MoP=true,TBC=true,Vanilla=true})[edition]
        or not relative_path:match("^[A-Za-z]+/[A-Za-z]+/[^/\\]+%.lua$") then
        return nil, "invalid_guide_path"
    end
    local text = core.read_file("_retail_/Interface/AddOns/WoWPro_Leveling/" .. relative_path)
    if not text or text == "" then return nil, "guide_unreadable" end
    return M.parse(text)
end
return M
