-- mf-arthas stable asynchronous plugin loader.
--
-- This file never changes between plugin updates. It downloads a project from
-- github.com/turner1211/mf-arthas with core.http_get, keeps it in scripts_data/,
-- and runs it from there with a require() that resolves the project's own
-- modules from the downloaded files. Shared host modules (common/..., root/...)
-- still go through the normal require.
--
-- Cache layout, relative to scripts_data/:
--   mf_arthas/<project>/current.txt        build id that boots
--   mf_arthas/<project>/<build>/.manifest  manifest of that build
--   mf_arthas/<project>/<build>/src/...    the project's files
--
-- A build is only marked current after every file is written and checked, so
-- a failed or interrupted download never replaces a working install. Updates
-- found while playing are applied the next time the plugin loads.

local M = {}

M.PROTOCOL = 1

local DEFAULTS = {
    owner = "turner1211",
    repo = "mf-arthas",
    branch = "main",
    folder = "plugins",
    cache_root = "mf_arthas",
    concurrency = 4,
    retries = 3,
    check_updates = true,
    boot_after_install = true,
}

local USER_AGENT = "MfArthasLoader/1"
local MANIFEST_TAG = "# mf%-arthas%-manifest"
local REF_TTL = 120
local native_require = require
local G = _G

-- Header and main of one plugin share this table when the host shares the
-- module between them; main then skips running the project's header twice.
M.gate = M.gate or {}
-- One commit lookup per repository and load, shared by every loader that sees
-- this module table, so a reload does not spend one GitHub API call per plugin.
M.refs = M.refs or {}

local Loader = {}
Loader.__index = Loader

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    return pcall(fn, ...)
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function now()
    local ok, t = call(core and core.time)
    return ok and type(t) == "number" and t or os.time()
end

local function url_encode_path(path)
    return (path:gsub("[^%w%-%._~/]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function compile(source, chunkname, env)
    if type(source) ~= "string" then return nil, "no source" end
    -- Refuse precompiled bytecode: only plain Lua text is accepted.
    if source:sub(1, 1) == "\27" then return nil, "binary chunks are not allowed" end
    if type(setfenv) == "function" and type(loadstring) == "function" then
        local fn, err = loadstring(source, chunkname)
        if not fn then return nil, err end
        setfenv(fn, env)
        return fn
    end
    if type(load) == "function" then
        return load(source, chunkname, "t", env)
    end
    return nil, "this client exposes neither load nor loadstring"
end

-- Folder of this file as the host named it ("@...\scripts\x_loader\"), or nil.
-- Downloaded chunks are named inside it, so anything the host resolves from
-- the Lua stack (owning plugin, menu persistence, error locations) points at
-- the loader plugin that runs them.
local function own_folder()
    if type(debug) ~= "table" then return nil end
    -- By function, not stack level: through pcall, level 1 is pcall itself.
    local ok, info = call(debug.getinfo, own_folder, "S")
    local src = ok and type(info) == "table" and info.source
    if type(src) ~= "string" or src:sub(1, 1) ~= "@" then return nil end
    return src:match("^(.*[/\\])[^/\\]+$")
end

local OWN_FOLDER = own_folder()

--------------------------------------------------------------------------------
-- Construction and logging
--------------------------------------------------------------------------------

---@param config table { project = "folder in plugins/", name = "display name", author?, class_ids?, ... }
function M.new(config)
    assert(type(config) == "table" and type(config.project) == "string", "plugin_loader: config.project is required")
    local self = setmetatable({}, Loader)
    local cfg = {}
    for k, v in pairs(DEFAULTS) do cfg[k] = v end
    for k, v in pairs(config) do cfg[k] = v end
    cfg.name = cfg.name or cfg.project
    self.cfg = cfg
    self.dir = cfg.cache_root .. "/" .. cfg.project
    self.folders = {}
    return self
end

function Loader:log(message, level)
    local text = "[mf-arthas:" .. self.cfg.project .. "] " .. tostring(message)
    local fn = core and ((level == "error" and core.log_error) or (level == "warning" and core.log_warning) or core.log)
    if not call(fn, text) then call(print, text) end
end

function Loader:chunkname(path)
    if OWN_FOLDER then
        local sep = OWN_FOLDER:find("\\", 1, true) and "\\" or "/"
        return OWN_FOLDER .. path:gsub("/", sep)
    end
    return "@" .. self.cfg.project .. "/" .. path
end

--------------------------------------------------------------------------------
-- scripts_data access
--------------------------------------------------------------------------------

function Loader:read(path)
    local ok, data = call(core.read_data_file, path)
    if ok and type(data) == "string" then return data end
    return nil
end

function Loader:size(path)
    local ok, n = call(core.get_data_file_size, path)
    if ok and type(n) == "number" then return n end
    return -1
end

function Loader:ensure_folder(path)
    local built = ""
    for part in path:gmatch("[^/]+") do
        built = built == "" and part or (built .. "/" .. part)
        if not self.folders[built] then
            call(core.create_data_folder, built)
            self.folders[built] = true
        end
    end
end

-- Replaces a file's contents and confirms the size on disk.
-- core.write_data_file appends, so the file is emptied by create_data_file first.
function Loader:write(path, data)
    local parent = path:match("^(.*)/[^/]+$")
    if parent then self:ensure_folder(parent) end
    local ok, created = call(core.create_data_file, path)
    if not ok or created == false then return false end
    if #data > 0 then call(core.write_data_file, path, data) end
    local n = self:size(path)
    return n == #data or (n < 0 and #data == 0)
end

--------------------------------------------------------------------------------
-- Manifests
--------------------------------------------------------------------------------
-- Text format written by tools/sync_plugins.ps1:
--   # mf-arthas-manifest 1
--   build <id>
--   project <name>
--   version <version>
--   entry main.lua
--   header header.lua
--   file <size> <sha256> <path>

local function parse_manifest(text)
    if type(text) ~= "string" or not text:find("^" .. MANIFEST_TAG) then return nil end
    local m = { files = {}, by_path = {} }
    for line in text:gmatch("[^\r\n]+") do
        local key, rest = line:match("^(%w+)%s+(.+)$")
        if key == "file" then
            local size, hash, path = rest:match("^(%d+)%s+(%x+)%s+(.+)$")
            if size then
                local f = { size = tonumber(size), hash = hash, path = trim(path) }
                m.files[#m.files + 1] = f
                m.by_path[f.path] = f
            end
        elseif key then
            m[key] = trim(rest)
        end
    end
    if not m.build or not m.entry or #m.files == 0 then return nil end
    m.text = text
    return m
end

function Loader:build_dir(build)
    return self.dir .. "/" .. build
end

function Loader:installed()
    local current = self:read(self.dir .. "/current.txt")
    current = current and trim(current) or ""
    if current == "" then return nil end
    return parse_manifest(self:read(self:build_dir(current) .. "/.manifest"))
end

function Loader:verify(manifest)
    local src = self:build_dir(manifest.build) .. "/src/"
    for _, f in ipairs(manifest.files) do
        if self:size(src .. f.path) ~= f.size then return false, f.path end
    end
    return true
end

--------------------------------------------------------------------------------
-- Running the project
--------------------------------------------------------------------------------

function Loader:module_path(manifest, name)
    local base = name:gsub("%.lua$", "")
    local candidates = { base .. ".lua", base:gsub("%.", "/") .. ".lua", base .. "/init.lua" }
    for _, path in ipairs(candidates) do
        if manifest.by_path[path] then return path end
    end
    return nil
end

function Loader:make_env(manifest)
    local src = self:build_dir(manifest.build) .. "/src/"
    local loaded, loading = {}, {}
    local env = setmetatable({}, { __index = G, __newindex = G })
    local loader = self

    local function run_file(path, ...)
        local source = loader:read(src .. path)
        if not source then error("missing downloaded file " .. path, 3) end
        local fn, err = compile(source, loader:chunkname(path), env)
        if not fn then error(err, 3) end
        return fn(...)
    end

    local function project_require(name)
        if type(name) ~= "string" then return native_require(name) end
        local path = loader:module_path(manifest, name)
        if not path then return native_require(name) end
        -- Keyed by file, so "a.b" and "a/b" share one module instance.
        if loaded[path] ~= nil then return loaded[path] end
        if loading[path] then error("loop requiring module '" .. name .. "'", 2) end
        loading[path] = true
        local ok, result = pcall(run_file, path, name, path)
        loading[path] = nil
        if not ok then error(result, 2) end
        if result == nil then result = true end
        loaded[path] = result
        return result
    end

    rawset(env, "require", project_require)
    return env, run_file
end

-- Runs the project's header.lua and returns its plugin table, or nil.
function Loader:run_header(manifest)
    if not manifest.header or not manifest.by_path[manifest.header] then return nil end
    local _, run_file = self:make_env(manifest)
    local ok, plugin = pcall(run_file, manifest.header)
    if not ok then
        self:log("project header failed: " .. tostring(plugin), "error")
        return nil
    end
    return type(plugin) == "table" and plugin or nil
end

function Loader:boot(manifest)
    if self.booted then return end
    self.booted = true
    local gate = M.gate[self.cfg.project]
    local allowed
    if gate and gate.build == manifest.build then
        allowed = gate.load
    else
        local plugin = self:run_header(manifest)
        allowed = not plugin or plugin.load ~= false
    end
    if not allowed then
        self:log("version " .. tostring(manifest.version) .. " is installed; its header says not to load on this character")
        return
    end
    local _, run_file = self:make_env(manifest)
    local ok, err = pcall(run_file, manifest.entry)
    if ok then
        self:log("started version " .. tostring(manifest.version) .. " (build " .. manifest.build .. ")")
    else
        self:log("project failed to start: " .. tostring(err), "error")
    end
end

-- Deletes files of builds other than the current one. Called at boot, so a
-- build that is running in this session is never touched.
function Loader:cleanup(current_build)
    local ok, names = call(core.read_dir, self.dir)
    if not ok or type(names) ~= "table" then return end
    for _, name in ipairs(names) do
        if name ~= current_build and name ~= "current.txt" then
            local dir = self:build_dir(name)
            local m = parse_manifest(self:read(dir .. "/.manifest") or self:read(dir .. "/.manifest.part"))
            if m then
                for _, f in ipairs(m.files) do call(core.delete_data_file, dir .. "/src/" .. f.path) end
            end
            call(core.delete_data_file, dir .. "/.manifest")
            call(core.delete_data_file, dir .. "/.manifest.part")
        end
    end
end

--------------------------------------------------------------------------------
-- Downloading
--------------------------------------------------------------------------------

-- core.http_get callback: (http_code, content_type, response_data, response_headers).
function Loader:get(url, headers, callback)
    local ok, err = call(core.http_get, url, headers, callback)
    if not ok then callback(-1, "error", tostring(err), "") end
end

-- Pins the download to one commit so every file comes from the same push.
-- Falls back to the branch name when the GitHub API is unavailable.
function Loader:resolve_ref(callback)
    local cfg = self.cfg
    local key = cfg.owner .. "/" .. cfg.repo .. "@" .. cfg.branch
    local entry = M.refs[key]
    if entry and entry.ref and now() - entry.time < REF_TTL then return callback(entry.ref) end
    if entry and entry.waiting then
        entry.waiting[#entry.waiting + 1] = callback
        return
    end
    entry = { waiting = { callback } }
    M.refs[key] = entry
    local url = "https://api.github.com/repos/" .. cfg.owner .. "/" .. cfg.repo .. "/commits/" .. cfg.branch
    self:get(url, { ["Accept"] = "application/vnd.github.sha", ["User-Agent"] = USER_AGENT }, function(code, _, body)
        local sha = type(body) == "string" and body:match("^%s*(%x+)%s*$")
        local ref = (code == 200 and sha and #sha == 40) and sha or cfg.branch
        local waiting = entry.waiting
        entry.waiting, entry.ref, entry.time = nil, ref, now()
        for _, cb in ipairs(waiting) do cb(ref) end
    end)
end

function Loader:raw_url(ref, path)
    local cfg = self.cfg
    return "https://raw.githubusercontent.com/" .. cfg.owner .. "/" .. cfg.repo .. "/" .. ref .. "/"
        .. url_encode_path(cfg.folder .. "/" .. cfg.project .. "/" .. path)
end

function Loader:fetch_manifest(ref, callback)
    self:get(self:raw_url(ref, "manifest.txt"), { ["User-Agent"] = USER_AGENT }, function(code, _, body)
        if code ~= 200 then return callback(nil, "manifest request returned " .. tostring(code)) end
        local m = parse_manifest(body)
        if not m then return callback(nil, "manifest could not be read") end
        callback(m)
    end)
end

-- Fills <build>/src from the previous build where a file is unchanged and from
-- GitHub otherwise.
function Loader:download(ref, manifest, previous, callback)
    local cfg = self.cfg
    local dir = self:build_dir(manifest.build)
    local src = dir .. "/src/"
    local old_src = previous and (self:build_dir(previous.build) .. "/src/")
    self:write(dir .. "/.manifest.part", manifest.text)

    local queue = {}
    for _, f in ipairs(manifest.files) do
        if self:size(src .. f.path) ~= f.size then
            local old = previous and previous.by_path[f.path]
            local copied = false
            if old and old.hash == f.hash and old.size == f.size then
                local data = self:read(old_src .. f.path)
                copied = data ~= nil and #data == f.size and self:write(src .. f.path, data)
            end
            if not copied then queue[#queue + 1] = { file = f, attempt = 1 } end
        end
    end

    local total, done, active, failed, finished = #queue, 0, 0, nil, false
    local next_report = 0.25
    if total > 0 then self:log("downloading " .. total .. " file(s) for version " .. tostring(manifest.version)) end

    local function finish()
        if finished then return end
        finished = true
        if failed then return callback(false, failed) end
        local ok, bad = self:verify(manifest)
        if not ok then return callback(false, "file check failed for " .. tostring(bad)) end
        if not self:write(dir .. "/.manifest", manifest.text) then return callback(false, "could not write manifest") end
        call(core.delete_data_file, dir .. "/.manifest.part")
        if not self:write(self.dir .. "/current.txt", manifest.build) then return callback(false, "could not write current.txt") end
        callback(true)
    end

    local pump
    local function start(item)
        active = active + 1
        local f = item.file
        self:get(self:raw_url(ref, f.path), { ["User-Agent"] = USER_AGENT }, function(code, _, body)
            active = active - 1
            local good = code == 200 and type(body) == "string" and #body == f.size and self:write(src .. f.path, body)
            if good then
                done = done + 1
                if total >= 8 and done / total >= next_report and done < total then
                    self:log(string.format("downloaded %d/%d files", done, total))
                    next_report = next_report + 0.25
                end
            elseif item.attempt < cfg.retries then
                item.attempt = item.attempt + 1
                queue[#queue + 1] = item
            else
                failed = failed or ("could not download " .. f.path .. " (http " .. tostring(code) .. ")")
                queue = {}
            end
            pump()
        end)
    end

    pump = function()
        while not failed and active < cfg.concurrency and #queue > 0 do
            start(table.remove(queue, 1))
        end
        if active == 0 and (#queue == 0 or failed) then finish() end
    end
    pump()
end

function Loader:update(previous, on_ready)
    if type(core) ~= "table" or type(core.http_get) ~= "function" then
        self:log("core.http_get is not available; cannot reach GitHub", "error")
        return
    end
    self:resolve_ref(function(ref)
        self:fetch_manifest(ref, function(manifest, err)
            if not manifest then
                self:log("update check failed: " .. tostring(err), previous and "warning" or "error")
                return
            end
            if previous and manifest.build == previous.build then return end
            self:download(ref, manifest, previous, function(ok, why)
                if not ok then
                    self:log("download failed, keeping the installed version: " .. tostring(why), "error")
                    return
                end
                on_ready(manifest)
            end)
        end)
    end)
end

--------------------------------------------------------------------------------
-- Entry points for header.lua and main.lua
--------------------------------------------------------------------------------

local function player_class()
    local ok, me = call(core and core.object_manager and core.object_manager.get_local_player)
    if not ok or not me then return nil end
    local valid_ok, valid = call(me.is_valid, me)
    if not valid_ok or valid ~= true then return nil end
    local class_ok, class_id = call(me.get_class, me)
    return class_ok and class_id or nil
end

-- Returns the plugin table for header.lua.
function Loader:header()
    local cfg = self.cfg
    local fallback = { name = cfg.name, version = "not installed", author = cfg.author or "mf-arthas", load = true }
    local manifest = self:installed()
    if not manifest then
        -- Nothing downloaded yet: skip characters this plugin can never run on.
        local class_id = player_class()
        if class_id and type(cfg.class_ids) == "table" then
            local match = false
            for _, id in ipairs(cfg.class_ids) do if id == class_id then match = true end end
            fallback.load = match
        end
        return fallback
    end
    fallback.version = manifest.version or manifest.build
    local plugin = self:run_header(manifest)
    if not plugin then
        M.gate[cfg.project] = { build = manifest.build, load = true }
        return fallback
    end
    plugin.name = plugin.name or cfg.name
    plugin.version = plugin.version or fallback.version
    M.gate[cfg.project] = { build = manifest.build, load = plugin.load ~= false }
    return plugin
end

-- Body of main.lua.
function Loader:main()
    local cfg = self.cfg
    local manifest = self:installed()
    if manifest then
        local ok, bad = self:verify(manifest)
        if not ok then
            self:log("installed files are incomplete (" .. tostring(bad) .. "); downloading again", "warning")
            manifest = nil
        end
    end

    if manifest then
        self:cleanup(manifest.build)
        self:boot(manifest)
        if cfg.check_updates then
            self:update(manifest, function(new)
                self:log("version " .. tostring(new.version) .. " downloaded; reload plugins to use it")
            end)
        end
        return
    end

    -- First install: download, then start from the next game update tick so
    -- the project registers its callbacks from the usual game-thread context.
    local pending
    self:log("not installed yet; downloading from github.com/" .. cfg.owner .. "/" .. cfg.repo)
    self:update(nil, function(new)
        self:log("installed version " .. tostring(new.version))
        if cfg.boot_after_install then pending = new else self:log("reload plugins to start it") end
    end)
    if not call(core.register_on_update_callback, function()
        if pending then
            local m = pending
            pending = nil
            self:boot(m)
        end
    end) then
        self:log("could not register an update callback; reload plugins after the download", "warning")
    end
end

return M
