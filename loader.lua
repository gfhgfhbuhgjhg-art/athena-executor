--[[
    Athena Explorer + MCP loader
    ----------------------------
    Run this once from the executor console (Athena, Xeno, ...).

    It loads, from disk:
      1. connector.luau   - the roblox-executor-mcp client (offline copy)
      2. AthenaExplorer.lua - the explorer UI (without a second MCP connect)

    No internet is required: the connector usually downloads LuaEncode from
    GitHub, this copy has LuaEncode embedded.
]]

-- Tried in order. The first one is relative to the executor workspace.
local ROOTS = {
    "Athena",
    "C:\\Users\\bob\\AppData\\Local\\athena\\workspace\\Athena",
    "C:\\Users\\bob\\Documents\\athena-explorer",
}
local genv = getgenv and getgenv() or _G
local HttpService = game:GetService("HttpService")

local function log(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    print("[athena] " .. table.concat(parts, " "))
end

local function readLocal(name)
    if type(readfile) ~= "function" then
        return nil, "readfile is not available in this executor"
    end
    local tried = {}
    for _, root in ipairs(ROOTS) do
        for _, joined in ipairs({
            root .. "/" .. name,
            root .. "\\" .. name,
        }) do
            tried[#tried + 1] = joined
            if type(isfile) == "function" and not isfile(joined) then
                continue
            end
            local ok, source = pcall(readfile, joined)
            if ok and type(source) == "string" and #source > 100 then
                return source, joined
            end
        end
    end
    return nil, "not found: " .. table.concat(tried, ", ")
end

local function bridgeStatus()
    local ok, body = pcall(function()
        return game:HttpGet("http://127.0.0.1:16384/api/status")
    end)
    if not ok or type(body) ~= "string" then
        return nil
    end
    local decoded, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not decoded or type(data) ~= "table" then
        return nil
    end
    return tonumber(data.clientCount) or 0
end

local function loadSource(source, label)
    if type(source) ~= "string" or #source < 100 then
        log(label, "source looks empty")
        return false
    end
    local chunk, compileError = loadstring(source)
    if not chunk then
        log(label, "compile error:", compileError)
        return false
    end
    local ok, runError = pcall(chunk)
    if not ok then
        log(label, "runtime error:", runError)
        return false
    end
    return true
end

-- 1. MCP connector -----------------------------------------------------------
local clients = bridgeStatus()
if clients and clients > 0 then
    log("bridge already has " .. clients .. " client(s), skipping connector")
else
    if genv.MCP_Loaded then
        log("MCP_Loaded was already true, resetting for a clean attempt")
    end
    genv.MCP_Loaded = false

    local source, readError = readLocal("connector.luau")
    if source then
        log("starting connector from disk")
        loadSource(source, "connector")
    else
        log("local connector unavailable:", readError)
        for _, host in ipairs({ "127.0.0.1:16384", "localhost:16384" }) do
            local ok, httpSource = pcall(function()
                return game:HttpGet("http://" .. host .. "/script.luau")
            end)
            if ok and type(httpSource) == "string" and #httpSource > 1000 then
                log("starting connector over HTTP via " .. host)
                if loadSource(httpSource, "connector") then
                    break
                end
            else
                log("HttpGet " .. host .. " failed:", httpSource)
            end
        end
    end
end

-- 2. Explorer ---------------------------------------------------------------
genv.ATHENA_EXPLORER_NO_MCP = true
local explorerSource, explorerError = readLocal("AthenaExplorer.lua")
if explorerSource then
    loadSource(explorerSource, "explorer")
else
    log("explorer unavailable:", explorerError)
end
genv.ATHENA_EXPLORER_NO_MCP = nil

-- 3. Report -----------------------------------------------------------------
task.delay(7, function()
    local count = bridgeStatus()
    if count then
        log("bridge clients now: " .. count)
    end
    if count == 0 then
        log("no client registered. The executor probably has no WebSocket support,")
        log("or ws://localhost:16384 is blocked. Check the console output above.")
    end
end)
