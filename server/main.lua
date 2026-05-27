-- ============================================================
--  GSRP Admin Logger — Server Main
--  Intercepts admin commands, orchestrates the report pipeline.
-- ============================================================

local pendingReports = {}  -- [adminServerId] = reportData
local heartbeatTimer  = nil

-- ─── Utility ────────────────────────────────────────────────

local function IsAdmin(src)
    for _, ace in ipairs(Config.AdminAces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    return false
end

local function IsDev(src)
    for _, ace in ipairs(Config.DevAces) do
        if IsPlayerAceAllowed(src, ace) then return true end
    end
    return false
end

local function GetIdentifiers(src)
    local ids = {}
    local count = GetNumPlayerIdentifiers(src)
    for i = 0, count - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            local prefix = id:match("^(.-):")
            ids[prefix] = id
        end
    end
    return ids
end

local function BuildPlayerSnapshot(src)
    if not src or src == 0 then return nil end
    local ids  = GetIdentifiers(src)
    local ping = GetPlayerPing(src)
    return {
        serverId   = src,
        name       = GetPlayerName(src) or "Unknown",
        discord    = ids["discord"],
        steam      = ids["steam"],
        license    = ids["license"],
        license2   = ids["license2"],
        ip         = ids["ip"],
        fivem      = ids["fivem"],
        ping       = ping,
        endpoint   = GetPlayerEndpoint(src),
    }
end

local function Timestamp()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

-- ─── Command Interception ───────────────────────────────────
-- We wrap every tracked command in a pre-hook that intercepts
-- the call, fires the UI on the client, then either allows or
-- cancels depending on what the admin enters.

for cmdName, cmdMeta in pairs(Config.TrackedCommands) do
    AddEventHandler("rconCommand:" .. cmdName, function() end)  -- ensure registered

    -- Register a server-side command listener that fires BEFORE the real command.
    -- FiveM doesn't expose true pre-command hooks in Lua, so we register our own
    -- shadow command with the same name, which the client NUI captures instead.
    -- The real implementation relies on the client sending back the resolved reason.
end

-- ─── Core Events ────────────────────────────────────────────

-- Fired by client when an admin types a tracked command
RegisterNetEvent("gsrp:adminlogs:commandDetected", function(data)
    local src = source
    if not IsAdmin(src) then return end

    local cmdMeta = Config.TrackedCommands[data.command]
    if not cmdMeta then return end

    local adminSnap  = BuildPlayerSnapshot(src)
    local targetSnap = data.targetId and BuildPlayerSnapshot(tonumber(data.targetId)) or nil

    pendingReports[src] = {
        id          = ("RPT-%d-%d"):format(src, os.time()),
        command     = data.command,
        label       = cmdMeta.label,
        category    = cmdMeta.category,
        args        = data.args or {},
        admin       = adminSnap,
        target      = targetSnap,
        timestamp   = Timestamp(),
        isDev       = IsDev(src),
    }

    -- Tell client to show the form
    TriggerClientEvent("gsrp:adminlogs:showForm", src, {
        reportId  = pendingReports[src].id,
        command   = data.command,
        label     = cmdMeta.label,
        category  = cmdMeta.category,
        target    = targetSnap and { name = targetSnap.name, serverId = targetSnap.serverId } or nil,
        isDev     = IsDev(src),
    })

    -- Safety timeout — if admin closes without submitting, clean up
    SetTimeout(Config.UI.FormTimeout, function()
        if pendingReports[src] then
            pendingReports[src] = nil
        end
    end)
end)

-- Fired by client when admin submits the form (or clicks Developer button)
RegisterNetEvent("gsrp:adminlogs:formSubmitted", function(data)
    local src    = source
    local report = pendingReports[src]
    if not report then return end

    report.reason     = data.isDeveloper and "Developer Use" or (data.reason or "No reason given")
    report.isDeveloper = data.isDeveloper or false
    pendingReports[src] = nil

    -- Fire the full pipeline asynchronously
    CreateThread(function()
        -- 1. Website API — create report
        exports[GetCurrentResourceName()]:CreateWebsiteReport(report)

        -- 2. Trigger POST /api/webhooks/trigger on the site (live dashboard feed)
        exports[GetCurrentResourceName()]:TriggerSiteWebhook(report)

        -- 4. Notify admin in-game
        TriggerClientEvent("gsrp:adminlogs:reportCreated", src, {
            reportId = report.id,
            success  = true,
        })
    end)
end)

-- Fired by client when admin dismisses / cancels the form
RegisterNetEvent("gsrp:adminlogs:formCancelled", function()
    local src = source
    pendingReports[src] = nil
end)


-- ─── Permission Check (client request) ──────────────────────
-- Client fires this on load to know if it should intercept commands.

RegisterNetEvent("gsrp:adminlogs:checkPermissions", function()
    local src = source
    TriggerClientEvent("gsrp:adminlogs:permissionsResult", src, {
        isAdmin = IsAdmin(src),
        isDev   = IsDev(src),
    })
end)

-- ─── Heartbeat ──────────────────────────────────────────────

local function SendHeartbeat()
    local players = {}
    for _, pid in ipairs(GetPlayers()) do
        table.insert(players, {
            id   = pid,
            name = GetPlayerName(pid),
            ping = GetPlayerPing(pid),
        })
    end
    exports[GetCurrentResourceName()]:SendHeartbeat({
        timestamp    = Timestamp(),
        playerCount  = #players,
        maxPlayers   = GetConvarInt("sv_maxclients", 32),
        players      = players,
    })
end

CreateThread(function()
    while true do
        Wait(Config.HeartbeatInterval)
        SendHeartbeat()
    end
end)

-- ─── Kill Feed Stats ────────────────────────────────────────

RegisterNetEvent("gsrp:adminlogs:playerKilled", function(data)
    local src = source
    exports[GetCurrentResourceName()]:SendStats({
        type      = "kill",
        killer    = BuildPlayerSnapshot(src),
        victim    = data.victimId and BuildPlayerSnapshot(tonumber(data.victimId)) or nil,
        weapon    = data.weapon,
        timestamp = Timestamp(),
    })
end)

-- ─── Disconnect Logging ─────────────────────────────────────

AddEventHandler("playerDropped", function(reason)
    local src  = source
    local snap = BuildPlayerSnapshot(src)
    exports[GetCurrentResourceName()]:SendDisconnect({
        player    = snap,
        reason    = reason,
        timestamp = Timestamp(),
    })
end)

-- ─── Export shims (so other resources can log too) ──────────

exports("LogAdminAction", function(adminSrc, targetSrc, command, reason, category)
    local report = {
        id        = ("RPT-%d-%d"):format(adminSrc, os.time()),
        command   = command,
        label     = command,
        category  = category or "other",
        args      = {},
        admin     = BuildPlayerSnapshot(adminSrc),
        target    = targetSrc and BuildPlayerSnapshot(targetSrc) or nil,
        timestamp = Timestamp(),
        reason    = reason or "No reason given",
        isDeveloper = false,
        isDev     = IsDev(adminSrc),
    }
    CreateThread(function()
        exports[GetCurrentResourceName()]:CreateWebsiteReport(report)
        exports[GetCurrentResourceName()]:TriggerSiteWebhook(report)
    end)
end)

print("^2[GSRP AdminLogs] ^7Server main loaded.")
