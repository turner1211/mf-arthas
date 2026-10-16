-- Offline checks for plugin_loader.lua. Runs under LuaJIT (the Sylvanas runtime):
--
--   luajit tools/test_loader.lua
--
-- A fake `core` keeps scripts_data in memory, answers core.http_get from a
-- table (synthetic project) or from plugins/ on disk (real projects), and
-- delivers responses asynchronously like the host does. Nothing touches the
-- network or the real scripts_data folder.

local REPO = (arg and arg[0] or ""):match("^(.*)[/\\]tools[/\\][^/\\]+$") or "."
local TEMPLATE = REPO .. "/tools/loader_template/plugin_loader.lua"
local SHA = string.rep("ab", 20)

local failures, checks = 0, 0
local function check(cond, label)
    checks = checks + 1
    if not cond then
        failures = failures + 1
        io.write("  FAIL ", label, "\n")
    end
end

local function read_disk(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

--------------------------------------------------------------------------------
-- Fake host
--------------------------------------------------------------------------------

local real_require = require

-- Permissive stand-in for host modules (common/..., root/...).
local function stub()
    return setmetatable({}, { __index = function(t, k) local v = stub(); rawset(t, k, v); return v end,
                              __call = function() return nil end })
end

local Host = {}
Host.__index = Host

-- remote(path_in_repo) -> body or nil, status override
function Host.new(remote)
    local h = setmetatable({ data = {}, remote = remote, queue = {}, updates = {}, log = {},
                             requests = {}, api_status = 200, class_id = nil }, Host)
    return h
end

function Host:install_globals()
    local h = self
    local core = {}
    core.time = function() return h.time or 0 end
    core.log = function(m) h.log[#h.log + 1] = m end
    core.log_warning = core.log
    core.log_error = function(m) h.log[#h.log + 1] = "E " .. m end
    core.read_data_file = function(p) return h.data[p] end
    core.get_data_file_size = function(p) local d = h.data[p]; return d and #d or 0 end
    core.create_data_folder = function() end
    core.create_data_file = function(p) h.data[p] = ""; return true end
    core.write_data_file = function(p, d) if h.data[p] then h.data[p] = h.data[p] .. d end end
    core.delete_data_file = function(p) local had = h.data[p] ~= nil; h.data[p] = nil; return had end
    core.read_dir = function(dir)
        local seen, out = {}, {}
        local prefix = dir .. "/"
        for path in pairs(h.data) do
            if path:sub(1, #prefix) == prefix then
                local name = path:sub(#prefix + 1):match("^[^/]+")
                if not seen[name] then seen[name] = true; out[#out + 1] = name end
            end
        end
        return out
    end
    core.register_on_update_callback = function(cb) h.updates[#h.updates + 1] = cb end
    core.object_manager = { get_local_player = function()
        if not h.class_id then return nil end
        return { is_valid = function() return true end, get_class = function() return h.class_id end }
    end }
    core.http_get = function(url, headers, cb)
        if type(headers) == "function" then cb = headers end
        h.requests[#h.requests + 1] = url
        local code, body = 404, ""
        if url:find("^https://api%.github%.com/") then
            code, body = h.api_status, h.api_status == 200 and SHA or "rate limited"
        else
            local path = url:match("^https://raw%.githubusercontent%.com/turner1211/mf%-arthas/[^/]+/(.+)$")
            path = path and path:gsub("%%(%x%x)", function(x) return string.char(tonumber(x, 16)) end)
            local got, status = h.remote(path, url)
            if got then code, body = status or 200, got end
        end
        h.queue[#h.queue + 1] = function() cb(code, code == 200 and "text/plain" or "error", body, "") end
    end
    _G.core = core
    _G.require = function(name)
        if h.modules[name] ~= nil then return h.modules[name] end
        if name == "mf_loader" or name == "plugin_loader" then
            -- Loaded from the loader folder like the host does, so the chunk
            -- name carries that folder.
            local fn = assert(loadfile(h.loader_dir .. "/" .. name .. ".lua"))
            h.modules[name] = fn()
            return h.modules[name]
        end
        if name:find("^common/") or name:find("^root/") then
            h.modules[name] = stub()
            return h.modules[name]
        end
        return real_require(name)
    end
end

-- Runs every queued HTTP callback (and the ones they queue) and update ticks.
function Host:pump()
    for _ = 1, 10000 do
        if #self.queue == 0 then break end
        table.remove(self.queue, 1)()
    end
    for _, cb in ipairs(self.updates) do cb() end
end

-- One plugin load, as the host does it: header.lua then main.lua from the
-- loader folder, sharing one module cache. The data folder survives between
-- sessions; modules and callbacks do not.
function Host:session(loader_dir, pump)
    self.modules, self.updates, self.requests, self.log = {}, {}, {}, {}
    self.loader_dir = loader_dir
    self:install_globals()
    local header = assert(loadfile(loader_dir .. "/header.lua"))()
    local ran_main = false
    if header.load ~= false then
        assert(loadfile(loader_dir .. "/main.lua"))()
        ran_main = true
    end
    if pump ~= false then self:pump() end
    return header, ran_main
end

function Host:file_requests()
    local n = 0
    for _, url in ipairs(self.requests) do
        if url:find("raw%.githubusercontent") and not url:find("manifest%.txt$") then n = n + 1 end
    end
    return n
end

function Host:logged(pattern)
    for _, line in ipairs(self.log) do if line:find(pattern) then return true end end
    return false
end

--------------------------------------------------------------------------------
-- Synthetic project
--------------------------------------------------------------------------------

local function sha_stub(s)
    -- Manifest hashes only need to differ when content differs.
    local h = 0
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 4294967296 end
    return string.format("%064x", h)
end

local function make_manifest(project, version, files)
    local paths = {}
    for p in pairs(files) do paths[#paths + 1] = p end
    table.sort(paths)
    local body = { "project " .. project, "version " .. version, "entry main.lua", "header header.lua" }
    for _, p in ipairs(paths) do body[#body + 1] = ("file %d %s %s"):format(#files[p], sha_stub(files[p]), p) end
    local text = table.concat(body, "\n") .. "\n"
    return "# mf-arthas-manifest 1\nbuild " .. sha_stub(text):sub(-16) .. "\n" .. text
end

local function synth_files(value, version)
    return {
        ["header.lua"] = 'return { name = "Synth", version = require("synth_version"), load = not SYNTH_BLOCK }\n',
        ["synth_version.lua"] = 'return "' .. version .. '"\n',
        ["main.lua"] = table.concat({
            'local a = require("lib.util")',
            'local b = require("lib/util")',
            'SYNTH_SAME = rawequal(a, b)',
            'SYNTH_VALUE = a.value',
            'SYNTH_RUNS = (SYNTH_RUNS or 0) + 1',
            'SYNTH_SOURCE = debug.getinfo(1, "S").source',
            'SYNTH_COMMON = type(require("common/enums")) == "table"',
            'core.register_on_update_callback(function() end)',
        }, "\n") .. "\n",
        ["lib/util.lua"] = "return { value = " .. value .. " }\n",
    }
end

local function write_loader_dir(dir, config)
    os.execute(('mkdir "%s" 2>nul || mkdir -p "%s" 2>/dev/null'):format(dir:gsub("/", "\\"), dir))
    local fields = {}
    for k, v in pairs(config) do
        fields[#fields + 1] = ("    %s = %s,"):format(k, type(v) == "table" and "{ " .. table.concat(v, ", ") .. " }" or ("%q"):format(v))
    end
    local cfg = 'require("plugin_loader").new({\n' .. table.concat(fields, "\n") .. "\n})"
    local function put(name, text) local f = assert(io.open(dir .. "/" .. name, "wb")); f:write(text); f:close() end
    put("header.lua", "return " .. cfg .. ":header()\n")
    put("main.lua", cfg .. ":main()\n")
    put("plugin_loader.lua", assert(read_disk(TEMPLATE)))
end

local function run_synthetic(tmp)
    io.write("synthetic project\n")
    local remote_files, served = {}, {}
    local function publish(files, version)
        remote_files = files
        served = { ["plugins/synth/manifest.txt"] = make_manifest("synth", version, files) }
        for p, d in pairs(files) do served["plugins/synth/" .. p] = d end
    end
    local overrides = {}
    local host = Host.new(function(path)
        if overrides[path] then return overrides[path][2], overrides[path][1] end
        return served[path]
    end)
    local dir = tmp .. "/synth_loader"
    write_loader_dir(dir, { project = "synth", name = "Synth", class_ids = { 8 } })

    -- 1. Wrong class before anything is installed: nothing loads, nothing downloads.
    host.class_id = 1
    publish(synth_files(42, "1.0.0"), "1.0.0")
    local header, ran = host:session(dir)
    check(header.load == false and not ran and #host.requests == 0, "other class skips the plugin before install")

    -- 2. First install: downloads everything, boots on the next update tick.
    host.class_id = 8
    SYNTH_RUNS = nil
    header, ran = host:session(dir)
    check(header.name == "Synth" and header.version == "not installed", "fallback header before install")
    check(host:file_requests() == 4, "first install downloads all 4 files (got " .. host:file_requests() .. ")")
    check(host.requests[1]:find("api%.github%.com") and host.requests[2]:find("/" .. SHA .. "/", 1, true), "download pinned to the commit sha")
    check(SYNTH_RUNS == 1 and SYNTH_VALUE == 42, "project booted after install")
    check(SYNTH_SAME == true, "a.b and a/b resolve to one module")
    check(SYNTH_COMMON == true, "common/ modules go through the host require")
    check(type(SYNTH_SOURCE) == "string" and SYNTH_SOURCE:find("synth_loader", 1, true) and SYNTH_SOURCE:find("main.lua$"),
        "chunk names point into the loader folder (" .. tostring(SYNTH_SOURCE) .. ")")
    local build1 = host.data["mf_arthas/synth/current.txt"]
    check(build1 and #build1 == 16, "current.txt written")

    -- 3. Reload with nothing new: boots from cache at once, downloads nothing.
    SYNTH_RUNS = nil
    header, ran = host:session(dir, false)
    check(SYNTH_RUNS == 1, "reload boots before any network reply")
    check(header.name == "Synth" and header.version == "1.0.0", "header comes from the installed project")
    host:pump()
    check(host:file_requests() == 0, "unchanged build downloads no files")

    -- 4. Header logic is the project's: it can refuse to load.
    SYNTH_BLOCK, SYNTH_RUNS = true, nil
    header, ran = host:session(dir)
    check(header.load == false and SYNTH_RUNS == nil, "project header can stop the load")
    SYNTH_BLOCK = nil

    -- 5. Main project logic updated upstream: the loader files are untouched,
    --    the running session keeps the old build, only changed files download.
    local loader_before = read_disk(dir .. "/plugin_loader.lua") .. read_disk(dir .. "/main.lua") .. read_disk(dir .. "/header.lua")
    publish(synth_files(43, "1.1.0"), "1.1.0")
    SYNTH_RUNS = nil
    host:session(dir)
    check(SYNTH_VALUE == 42 and SYNTH_RUNS == 1, "update is not swapped in mid-session")
    check(host:file_requests() == 2, "only the 2 changed files download (got " .. host:file_requests() .. ")")
    check(host:logged("1%.1%.0 downloaded; reload"), "player is told to reload")
    local build2 = host.data["mf_arthas/synth/current.txt"]
    check(build2 and build2 ~= build1, "current.txt moved to the new build")

    header = host:session(dir)
    check(SYNTH_VALUE == 43 and header.version == "1.1.0", "next load runs the updated logic")
    check(host.data["mf_arthas/synth/" .. build1 .. "/src/main.lua"] == nil, "old build cleaned up")
    local loader_after = read_disk(dir .. "/plugin_loader.lua") .. read_disk(dir .. "/main.lua") .. read_disk(dir .. "/header.lua")
    check(loader_before == loader_after, "loader files unchanged by the update")

    -- 6. A failed download never replaces the installed build.
    publish(synth_files(44, "1.2.0"), "1.2.0")
    overrides["plugins/synth/lib/util.lua"] = { 500, "" }
    host:session(dir)
    check(host.data["mf_arthas/synth/current.txt"] == build2, "failed download keeps the installed build")
    check(host:logged("^E .*download failed, keeping"), "failure is logged")
    host:session(dir)
    check(SYNTH_VALUE == 43, "still runs the installed build after a failure")

    -- 7. A truncated file (size differs from the manifest) is rejected too.
    overrides["plugins/synth/lib/util.lua"] = { 200, "return {}" }
    host:session(dir)
    check(host.data["mf_arthas/synth/current.txt"] == build2, "size mismatch keeps the installed build")
    overrides = {}

    -- 8. GitHub API unavailable: falls back to the branch and still updates.
    host.api_status = 403
    host:session(dir)
    check(host.requests[2] and host.requests[2]:find("/main/plugins/synth/manifest%.txt$"), "falls back to the branch name")
    host:session(dir)
    check(SYNTH_VALUE == 44, "update applied through the branch fallback")
    host.api_status = 200

    -- 9. Installed files damaged on disk: downloads again instead of booting.
    local build3 = host.data["mf_arthas/synth/current.txt"]
    host.data["mf_arthas/synth/" .. build3 .. "/src/lib/util.lua"] = "x"
    SYNTH_RUNS = nil
    host:session(dir)
    check(host:logged("incomplete") and SYNTH_RUNS == 1 and SYNTH_VALUE == 44, "damaged install is repaired and booted")
end

--------------------------------------------------------------------------------
-- Real projects in plugins/
--------------------------------------------------------------------------------

local function list_dirs(path)
    local out = {}
    local p = io.popen(('dir /b /ad "%s" 2>nul'):format(path:gsub("/", "\\")))
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    if #out == 0 then
        p = io.popen(('ls -1 "%s" 2>/dev/null'):format(path))
        for line in p:lines() do out[#out + 1] = line end
        p:close()
    end
    table.sort(out)
    return out
end

local function run_real()
    io.write("real projects\n")
    for _, loader_name in ipairs(list_dirs(REPO .. "/loaders")) do
        local id = loader_name:match("^(.+)_loader$")
        local manifest = id and read_disk(REPO .. "/plugins/" .. id .. "/manifest.txt")
        if manifest then
            local loader_dir = REPO .. "/loaders/" .. loader_name
            check(read_disk(loader_dir .. "/plugin_loader.lua") == read_disk(TEMPLATE), id .. ": plugin_loader.lua matches the template")

            -- Every manifest entry matches the published bytes and compiles.
            local count = 0
            for size, path in manifest:gmatch("\nfile (%d+) %x+ ([^\n]+)") do
                count = count + 1
                local data = read_disk(REPO .. "/plugins/" .. id .. "/" .. path)
                check(data and #data == tonumber(size), id .. ": size of " .. path)
                if data and path:find("%.lua$") then
                    local fn, err = loadstring(data, "@" .. path)
                    check(fn ~= nil, id .. ": " .. path .. " compiles: " .. tostring(err))
                end
            end

            -- Full install through the loader with HTTP served from plugins/.
            local host = Host.new(function(path) return path and read_disk(REPO .. "/" .. path) end)
            host:session(loader_dir)
            local build = host.data["mf_arthas/" .. id .. "/current.txt"]
            check(build ~= nil and host:file_requests() == count,
                ("%s: installs all %d files (got %d)"):format(id, count, host:file_requests()))
            -- Booting real code against a stub core only proves the loader
            -- reached it: loader-level failures are what this looks for.
            local loader_error = host:logged("missing downloaded file") or host:logged("loop requiring")
                or host:logged("binary chunks") or host:logged("neither load")
            check(not loader_error, id .. ": no loader-level error")
            io.write(("  %-24s %4d files  %s\n"):format(id, count, build and "installed" or "NOT INSTALLED"))
        end
    end
end

local tmp = (os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp") .. "/mf_loader_test_" .. os.time()
run_synthetic(tmp)
run_real()
io.write(("%d checks, %d failed\n"):format(checks, failures))
os.exit(failures == 0 and 0 or 1)
