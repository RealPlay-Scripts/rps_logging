-- ============================================================
--  GSRP Admin Logger — Website API Module (No Discord)
--  All logging routes through your Golden Shores RP website API.
--  Auth: X-API-Key header + ?api_key= query param (both sent)
-- ============================================================

local BASE   = Config.API.BaseURL
local APIKEY = Config.API.Key

local function Headers()
    return {
        ["Content-Type"] = "application/json",
        ["X-API-Key"]    = APIKEY,
        ["Accept"]       = "application/json",
        ["X-Resource"]   = GetCurrentResourceName(),
        ["X-Version"]    = Config.API.Version,
    }
end

local function BuildURL(path)
    local sep = path:find("%?") and "&" or "?"
    return BASE .. path .. sep .. "api_key=" .. APIKEY
end

local function POST(path, payload, cb)
    local url  = BuildURL(path)
    local body = json.encode(payload)
    PerformHttpRequest(url, function(code, response, _)
        local ok = (code >= 200 and code < 300)
        local data = nil
        if response and #response > 0 then
            local s, d = pcall(json.decode, response)
            if s then data = d end
        end
        if cb then cb(ok, code, data) end
        if not ok then
            local errBody = (response and #response > 0) and response or "no body"
            print(("^1[GSRP API] POST %s — HTTP %d: %s^7"):format(path, code, errBody))
        end
    end, "POST", body, Headers())
end

local function GET(path, cb)
    PerformHttpRequest(BuildURL(path), function(code, response, _)
        local ok = (code >= 200 and code < 300)
        local data = nil
        if response and #response > 0 then
            local s, d = pcall(json.decode, response)
            if s then data = d end
        end
        if cb then cb(ok, code, data) end
    end, "GET", "", Headers())
end

local function PATCH(path, payload, cb)
    PerformHttpRequest(BuildURL(path), function(code, response, _)
        local ok = (code >= 200 and code < 300)
        if cb then cb(ok, code) end
        if not ok then
            print(("^1[GSRP API] PATCH %s — HTTP %d^7"):format(path, code))
        end
    end, "PATCH", json.encode(payload), Headers())
end

-- ─── Exports ─────────────────────────────────────────────────
exports("PostAPI",  function(path, payload, cb) POST(path, payload, cb)  end)
exports("GetAPI",   function(path, cb)          GET(path, cb)            end)
exports("PatchAPI", function(path, payload, cb) PATCH(path, payload, cb) end)

-- ─── User ID Resolution Cache ────────────────────────────────
local userCache = {}

local function ResolveUserByDiscord(rawDiscordId, cb)
    if not rawDiscordId then cb(nil); return end
    local discordId = rawDiscordId:gsub("discord:", "")
    if userCache[discordId] then cb(userCache[discordId]); return end
    GET("/api/users/discord/" .. discordId, function(ok, _, data)
        local uid = ok and data and data.id or nil
        if uid then userCache[discordId] = uid end
        cb(uid)
    end)
end

-- ─── Build Report Payload ─────────────────────────────────────
local function BuildPayload(report, adminUid, targetUid)
    return {
        reportId       = report.id,
        adminUserId    = adminUid,
        targetUserId   = targetUid,
        command        = report.command,
        commandLabel   = report.label,
        category       = report.category,
        reason         = report.reason,
        isDeveloper    = report.isDeveloper or false,
        fromScanner    = report.fromScanner or false,
        sourceResource = report.resource or "manual",
        timestamp      = report.timestamp,
        admin = report.admin and {
            serverId = report.admin.serverId,
            name     = report.admin.name,
            discord  = report.admin.discord,
            steam    = report.admin.steam,
            license  = report.admin.license,
            ip       = report.admin.ip,
            ping     = report.admin.ping,
        } or nil,
        target = report.target and {
            serverId = report.target.serverId,
            name     = report.target.name,
            discord  = report.target.discord,
            steam    = report.target.steam,
            license  = report.target.license,
            ip       = report.target.ip,
            ping     = report.target.ping,
        } or nil,
    }
end

-- ─── Create Website Report ────────────────────────────────────
exports("CreateWebsiteReport", function(report)
    ResolveUserByDiscord(report.admin and report.admin.discord or nil, function(adminUid)
        ResolveUserByDiscord(report.target and report.target.discord or nil, function(targetUid)
            POST("/api/admin-logs", BuildPayload(report, adminUid, targetUid), function(ok, code)
                if ok then
                    print(("^2[GSRP API] Report %s filed on website.^7"):format(report.id))
                else
                    print(("^1[GSRP API] Report %s failed (HTTP %d).^7"):format(report.id, code))
                end
            end)
        end)
    end)
end)

-- ─── Trigger Site Webhook (live dashboard feed) ───────────────
exports("TriggerSiteWebhook", function(report)
    POST("/api/webhooks/trigger", {
        event   = "admin_action",
        version = Config.API.Version,
        data    = {
            id           = report.id,
            command      = report.command,
            label        = report.label,
            category     = report.category,
            reason       = report.reason,
            isDeveloper  = report.isDeveloper or false,
            fromScanner  = report.fromScanner or false,
            resource     = report.resource,
            timestamp    = report.timestamp,
            admin  = report.admin  and { name = report.admin.name,  discord = report.admin.discord,  license = report.admin.license  } or nil,
            target = report.target and { name = report.target.name, discord = report.target.discord, license = report.target.license } or nil,
        },
    })
end)

-- ─── Analytics ────────────────────────────────────────────────
exports("GetLiveAnalytics", function(cb)         GET("/api/analytics/live", cb) end)
exports("GetServerSummary", function(cb)         GET("/api/analytics/summary", cb) end)
exports("GetLeaderboard",   function(period, cb) GET("/api/analytics/leaderboard?period=" .. (period or "weekly"), cb) end)
exports("GetKillFeed",      function(cb)         GET("/api/analytics/killfeed", cb) end)
exports("GetCrashStats",    function(cb)         GET("/api/analytics/crashes", cb) end)

-- ─── User & Role Management ───────────────────────────────────
exports("AssignRole",       function(uid, roleId, remove, cb) POST("/api/users/" .. uid .. "/roles",        { roleId = roleId, action = remove and "remove" or "assign" }, cb) end)
exports("SyncDiscordRoles", function(uid, cb)                 POST("/api/users/" .. uid .. "/sync-discord", {}, cb) end)

-- ─── Server Reporting ─────────────────────────────────────────
exports("SendHeartbeat",  function(p) POST("/api/server/heartbeat",   p) end)
exports("SendStats",      function(p) POST("/api/server/stats",       p) end)
exports("SendDisconnect", function(p) POST("/api/server/disconnect",  p) end)

-- ─── Health Check on Boot ─────────────────────────────────────
CreateThread(function()
    Wait(5000)
    GET("/api/health", function(ok, code, data)
        if ok then
            print("^2[GSRP API] ^7Website API reachable — status: " .. (data and data.status or "ok"))
        else
            print(("^1[GSRP API] Website API health check FAILED (HTTP %d). Verify Config.API.BaseURL and Config.API.Key.^7"):format(code))
        end
    end)
end)

print("^2[GSRP AdminLogs] ^7API module loaded.")
