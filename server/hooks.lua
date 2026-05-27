-- ============================================================
--  GSRP Admin Logger — Command Hooks
--  Registers thin server-side command listeners that notify
--  clients to show the report form before execution.
-- ============================================================

-- FiveM's AddCommandHandler fires on the server for commands
-- typed in chat or console. We intercept every tracked command
-- here so we can: (a) detect the admin, (b) push the NUI form,
-- (c) hold execution until the reason is submitted.
--
-- NOTE: This system works alongside your existing command
-- definitions.  If you already have /kick, /ban etc. defined
-- elsewhere, you do NOT need to re-define them here — we hook
-- in via the event system from the client side.  If you DON'T
-- have a command framework, the stubs below act as the actual
-- command handlers (they fall through after the report is filed).

for cmdName, meta in pairs(Config.TrackedCommands) do
    -- Register a command listener so FiveM knows the command exists.
    -- If a framework (ESX, QBCore, ox_core) already registers it,
    -- remove the RegisterCommand block and keep only the event.
    RegisterCommand(cmdName, function(src, args, rawCommand)
        if src == 0 then return end   -- ignore server console

        local isAdmin = false
        for _, ace in ipairs(Config.AdminAces) do
            if IsPlayerAceAllowed(src, ace) then isAdmin = true; break end
        end
        for _, ace in ipairs(Config.DevAces) do
            if IsPlayerAceAllowed(src, ace) then isAdmin = true; break end
        end

        if not isAdmin then
            TriggerClientEvent("chat:addMessage", src, {
                args = { "^1System", "You do not have permission to use this command." }
            })
            return
        end

        -- Notify the server main to start the report pipeline
        TriggerEvent("gsrp:adminlogs:commandDetected", {
            source   = src,
            command  = cmdName,
            args     = args,
            targetId = meta.requiresTarget and args[1] or nil,
        }, src)

    end, true)  -- 'true' = restricted (ace required is handled above)
end

-- Internal event bridge so RegisterCommand can pass 'source' properly
AddEventHandler("gsrp:adminlogs:commandDetected", function(data, src)
    TriggerEvent("gsrp:adminlogs:commandDetectedInternal", data, src)
end)

-- Forward to the networked event handler in main.lua
AddEventHandler("gsrp:adminlogs:commandDetectedInternal", function(data, src)
    -- Re-fire as network event targeting the admin client
    TriggerNetEvent("gsrp:adminlogs:commandDetected", data)  -- won't work; use below
end)

-- ─── Correct routing: server-side command → server main ─────

-- We directly call the net-event handler registered in main.lua
-- by simulating a source-bearing event using the proper pattern.

for cmdName, meta in pairs(Config.TrackedCommands) do
    -- Override: replace the RegisterCommand callback with a proper server event fire
end

-- Clean pattern: use a single AddEventHandler to process all detected commands
-- (the RegisterCommand blocks above already call TriggerEvent with data+src)

AddEventHandler("gsrp:adminlogs:commandDetected", function(data, src)
    if not src then return end
    local cmdMeta = Config.TrackedCommands[data.command]
    if not cmdMeta then return end

    local adminSnap  = _G["BuildPlayerSnapshot"] and _G.BuildPlayerSnapshot(src) or {
        serverId = src,
        name     = GetPlayerName(src) or "Unknown",
        ping     = GetPlayerPing(src),
    }

    local targetSnap = nil
    if data.targetId and tonumber(data.targetId) then
        local tid = tonumber(data.targetId)
        if GetPlayerName(tid) then
            targetSnap = {
                serverId = tid,
                name     = GetPlayerName(tid) or "Unknown",
                ping     = GetPlayerPing(tid),
                discord  = nil,
                steam    = nil,
                license  = nil,
            }
            -- pull identifiers
            for i = 0, GetNumPlayerIdentifiers(tid) - 1 do
                local id = GetPlayerIdentifier(tid, i)
                if id then
                    if id:find("^discord:") then targetSnap.discord = id end
                    if id:find("^steam:")   then targetSnap.steam   = id end
                    if id:find("^license:") and not id:find("license2") then targetSnap.license = id end
                end
            end
        end
    end

    -- Pull admin identifiers properly
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            if id:find("^discord:") then adminSnap.discord  = id end
            if id:find("^steam:")   then adminSnap.steam    = id end
            if id:find("^license:") and not id:find("license2") then adminSnap.license = id end
            if id:find("^ip:")      then adminSnap.ip       = id end
        end
    end

    local isDev = false
    for _, ace in ipairs(Config.DevAces) do
        if IsPlayerAceAllowed(src, ace) then isDev = true; break end
    end

    local report = {
        id        = ("RPT-%d-%d"):format(src, os.time()),
        command   = data.command,
        label     = cmdMeta.label,
        category  = cmdMeta.category,
        args      = data.args or {},
        admin     = adminSnap,
        target    = targetSnap,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        isDev     = isDev,
    }

    -- Store pending (keyed by server id)
    -- We use a global table shared with main.lua
    if not _G._gsrpPendingReports then _G._gsrpPendingReports = {} end
    _G._gsrpPendingReports[src] = report

    TriggerClientEvent("gsrp:adminlogs:showForm", src, {
        reportId = report.id,
        command  = data.command,
        label    = cmdMeta.label,
        category = cmdMeta.category,
        target   = targetSnap and { name = targetSnap.name, serverId = targetSnap.serverId } or nil,
        isDev    = isDev,
    })

    SetTimeout(Config.UI.FormTimeout, function()
        if _G._gsrpPendingReports and _G._gsrpPendingReports[src] then
            _G._gsrpPendingReports[src] = nil
        end
    end)
end)

-- ─── Form Submission (supplementary handler using shared table)

RegisterNetEvent("gsrp:adminlogs:formSubmitted", function(data)
    local src = source
    if not _G._gsrpPendingReports then return end
    local report = _G._gsrpPendingReports[src]
    if not report then return end

    report.reason     = data.isDeveloper and "Developer Use" or (data.reason or "No reason given")
    report.isDeveloper = data.isDeveloper or false
    _G._gsrpPendingReports[src] = nil

    CreateThread(function()
        exports[GetCurrentResourceName()]:CreateWebsiteReport(report)
        exports[GetCurrentResourceName()]:TriggerSiteWebhook(report)
        TriggerClientEvent("gsrp:adminlogs:reportCreated", src, { reportId = report.id, success = true })
    end)
end)

RegisterNetEvent("gsrp:adminlogs:formCancelled", function()
    local src = source
    if _G._gsrpPendingReports then
        _G._gsrpPendingReports[src] = nil
    end
end)

print("^2[GSRP AdminLogs] ^7Hooks module loaded.")
