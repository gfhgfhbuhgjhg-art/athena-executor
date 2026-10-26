-- Athena Explorer + OpenCode MCP bridge.
-- Runs on inject. Delete this file to stop auto-starting.
--
-- Loads, from the executor workspace (no internet needed):
--   Athena/Athena.lua     the explorer + MCP connector in one file
--   Athena/connector.luau offline connector, used for retries
--
-- Everything is mirrored into Athena/diag.txt so the result can be read
-- from outside the game even when nothing connects.

local genv = getgenv and getgenv() or _G
local HttpService = game:GetService("HttpService")
local FOLDER = "Athena/"
local DIAG = FOLDER .. "diag.txt"

local diagOk = type(writefile) == "function"
local function writeDiag(text)
    if not diagOk then
        return
    end
    local line = os.date("[%H:%M:%S] ") .. text .. "\n"
    if type(appendfile) == "function" then
        local ok = pcall(appendfile, DIAG, line)
        if ok then
            return
        end
    end
    local ok = pcall(writefile, DIAG, line)
    if not ok then
        diagOk = false
    end
end

local function log(...)
    local parts = {}
    for index = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(index, ...))
    end
    local text = table.concat(parts, " ")
    print("[athena] " .. text)
    writeDiag(text)
end

local function candidates(name)
    return {
        FOLDER .. name,
        string.gsub(FOLDER .. name, "/", "\\"),
    }
end

local function readLocal(name)
    if type(readfile) ~= "function" then
        return nil, "readfile is not available in this executor"
    end
    for _, path in ipairs(candidates(name)) do
        local ok, source = pcall(readfile, path)
        if ok and type(source) == "string" and #source > 100 then
            return source, path
        end
    end
    return nil, "missing " .. FOLDER .. name .. " in the workspace"
end

local function clientCount()
    local ok, body = pcall(function()
        return game:HttpGet("http://127.0.0.1:16384/api/status")
    end)
    if not ok then
        return nil, "HttpGet failed: " .. tostring(body)
    end
    local decoded, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not decoded or type(data) ~= "table" then
        return nil, "bad status body"
    end
    return tonumber(data.clientCount) or 0
end

local function run(source, label)
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

pcall(writefile, DIAG, "")

task.spawn(function()
    log("=== athena explorer auto-start ===")
    log("websocket:", tostring(WebSocket), "httpget:", tostring(game.HttpGet))

    local bridge, bridgeError = clientCount()
    if bridge then
        log("bridge reachable, clients=" .. bridge)
    else
        log("bridge not reachable:", tostring(bridgeError))
    end

    local source, path = readLocal("Athena.lua")
    if source then
        log("loading explorer from " .. tostring(path))
        run(source, "explorer")
    else
        log("explorer unavailable:", tostring(path))
    end

    -- If the connector did not register, retry it a few times.
    for attempt = 1, 5 do
        task.wait(attempt == 1 and 6 or 10)
        local count, countError = clientCount()
        if count and count > 0 then
            log("connected, bridge clients=" .. count)
            return
        end
        if countError then
            log("status check failed:", countError)
        end
        log("not connected yet (attempt " .. attempt .. ")")
        local connector = readLocal("connector.luau")
        if connector then
            genv.MCP_Loaded = false
            log("retrying connector")
            run(connector, "connector")
        else
            log("connector unavailable:", tostring(connector))
            return
        end
    end

    log("giving up - the executor may not support WebSocket")
end)
