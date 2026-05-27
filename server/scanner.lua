-- ============================================================
--  GSRP Admin Logger — Resource Scanner & Auto-Detection Engine
--  Runs at startup. Scans every resource on the server for:
--    • Known admin menu frameworks
--    • txAdmin integration
--    • Generic admin-action patterns (teleport, freeze, kill, etc.)
--    • Custom command exports/events in any resource
-- ============================================================

local Scanner = {}
_G.GSRP_Scanner = Scanner

-- ─── Known Admin Menu Signatures ────────────────────────────
-- Each entry describes a known resource. "events" are server-
-- events we hook; "exports" are export functions we wrap;
-- "netEvents" are client→server events we listen on.

local KNOWN_FRAMEWORKS = {
    -- ── ES Admin / ESX Admin ──────────────────────────────
    {
        names     = { "es_admin", "es_admin2", "esx_adminplus", "esx_admin" },
        label     = "ESX Admin",
        events    = {
            ["esx_admin:kick"]     = { action = "kick",     category = "moderation", targetArg = 1 },
            ["esx_admin:ban"]      = { action = "ban",      category = "moderation", targetArg = 1 },
            ["esx_admin:teleport"] = { action = "teleport", category = "teleport",   targetArg = 1 },
            ["esx_admin:freeze"]   = { action = "freeze",   category = "moderation", targetArg = 1 },
            ["esx_admin:revive"]   = { action = "revive",   category = "moderation", targetArg = 1 },
            ["esx_admin:kill"]     = { action = "kill",     category = "moderation", targetArg = 1 },
            ["esx_admin:spectate"] = { action = "spectate", category = "spectate",   targetArg = 1 },
        },
    },

    -- ── QBCore Admin ──────────────────────────────────────
    {
        names     = { "qb-admin", "qbcore-admin", "qb-adminmenu" },
        label     = "QBCore Admin",
        events    = {
            ["QBAdmin:Server:KickPlayer"]      = { action = "kick",       category = "moderation", targetArg = 1 },
            ["QBAdmin:Server:BanPlayer"]       = { action = "ban",        category = "moderation", targetArg = 1 },
            ["QBAdmin:Server:FreezePlayer"]    = { action = "freeze",     category = "moderation", targetArg = 1 },
            ["QBAdmin:Server:RevivePlayer"]    = { action = "revive",     category = "moderation", targetArg = 1 },
            ["QBAdmin:Server:TeleportToPlayer"]= { action = "teleport",   category = "teleport",   targetArg = 1 },
            ["QBAdmin:Server:SpectatePlayer"]  = { action = "spectate",   category = "spectate",   targetArg = 1 },
            ["QBAdmin:Server:SetJob"]          = { action = "setjob",     category = "other",      targetArg = 1 },
            ["QBAdmin:Server:GiveMoney"]       = { action = "givemoney",  category = "spawn",      targetArg = 1 },
            ["QBAdmin:Server:DeleteVehicle"]   = { action = "deleteveh",  category = "other",      targetArg = 1 },
        },
    },

    -- ── vMenu ─────────────────────────────────────────────
    {
        names     = { "vmenu", "vMenu" },
        label     = "vMenu",
        events    = {
            ["vMenu:KickPlayer"]          = { action = "kick",     category = "moderation", targetArg = 1 },
            ["vMenu:TempBanPlayer"]       = { action = "tempban",  category = "moderation", targetArg = 1 },
            ["vMenu:BanPlayer"]           = { action = "ban",      category = "moderation", targetArg = 1 },
            ["vMenu:ClearPlayerArea"]     = { action = "cleararea",category = "other",      targetArg = 1 },
            ["vMenu:SummonPlayer"]        = { action = "bring",    category = "teleport",   targetArg = 1 },
            ["vMenu:GoToPlayer"]          = { action = "teleport", category = "teleport",   targetArg = 1 },
            ["vMenu:KillPlayer"]          = { action = "kill",     category = "moderation", targetArg = 1 },
            ["vMenu:FreezePlayer"]        = { action = "freeze",   category = "moderation", targetArg = 1 },
            ["vMenu:GodmodePlayer"]       = { action = "godmode",  category = "other",      targetArg = 1 },
            ["vMenu:GetArmourForPlayer"]  = { action = "armour",   category = "other",      targetArg = 1 },
            ["vMenu:HealPlayer"]          = { action = "heal",     category = "moderation", targetArg = 1 },
        },
    },

    -- ── Nucleus (Common FiveM Admin) ─────────────────────
    {
        names  = { "nucleus", "nucleus-coop" },
        label  = "Nucleus Admin",
        events = {
            ["nucleus:kick"]      = { action = "kick",     category = "moderation", targetArg = 1 },
            ["nucleus:ban"]       = { action = "ban",      category = "moderation", targetArg = 1 },
            ["nucleus:freeze"]    = { action = "freeze",   category = "moderation", targetArg = 1 },
            ["nucleus:teleport"]  = { action = "teleport", category = "teleport",   targetArg = 1 },
        },
    },

    -- ── AdminESX / Emerald Admin ──────────────────────────
    {
        names  = { "adminesx", "emerald_admin", "admin_system", "admin-menu" },
        label  = "Generic ESX Admin Panel",
        events = {
            ["admin:kickPlayer"]    = { action = "kick",     category = "moderation", targetArg = 1 },
            ["admin:banPlayer"]     = { action = "ban",      category = "moderation", targetArg = 1 },
            ["admin:freezePlayer"]  = { action = "freeze",   category = "moderation", targetArg = 1 },
            ["admin:teleport"]      = { action = "teleport", category = "teleport",   targetArg = 1 },
            ["admin:revive"]        = { action = "revive",   category = "moderation", targetArg = 1 },
            ["admin:spectate"]      = { action = "spectate", category = "spectate",   targetArg = 1 },
        },
    },

    -- ── ox_lib / Overextended Admin ───────────────────────
    {
        names  = { "ox_admin", "overextended-admin" },
        label  = "Ox Admin",
        events = {
            ["ox_admin:kick"]      = { action = "kick",     category = "moderation", targetArg = 1 },
            ["ox_admin:ban"]       = { action = "ban",      category = "moderation", targetArg = 1 },
            ["ox_admin:freeze"]    = { action = "freeze",   category = "moderation", targetArg = 1 },
            ["ox_admin:teleport"]  = { action = "teleport", category = "teleport",   targetArg = 1 },
            ["ox_admin:revive"]    = { action = "revive",   category = "moderation", targetArg = 1 },
            ["ox_admin:warn"]      = { action = "warn",     category = "moderation", targetArg = 1 },
        },
    },

    -- ── AduimAdmin / Any resource with "admin" in name ───
    -- (handled generically below)
}

-- ─── txAdmin Detection & Integration ────────────────────────
-- txAdmin emits its own events for bans, kicks, and warnings.
-- We hook these separately since txAdmin is a host-level tool.

local TXADMIN_EVENTS = {
    ["txAdmin:events:playerKicked"] = {
        action   = "kick",
        category = "moderation",
        -- txAdmin passes { target, reason, author }
        mapper   = function(data)
            return {
                adminName  = data.author or "txAdmin",
                targetName = data.target and data.target.name or "Unknown",
                targetId   = data.target and data.target.id   or nil,
                reason     = data.reason or "Kicked via txAdmin",
            }
        end,
    },
    ["txAdmin:events:playerBanned"] = {
        action   = "ban",
        category = "moderation",
        mapper   = function(data)
            return {
                adminName  = data.author or "txAdmin",
                targetName = data.target and data.target.name or "Unknown",
                targetId   = data.target and data.target.id   or nil,
                reason     = data.reason or "Banned via txAdmin",
            }
        end,
    },
    ["txAdmin:events:playerWarned"] = {
        action   = "warn",
        category = "moderation",
        mapper   = function(data)
            return {
                adminName  = data.author or "txAdmin",
                targetName = data.target and data.target.name or "Unknown",
                targetId   = data.target and data.target.id   or nil,
                reason     = data.message or "Warned via txAdmin",
            }
        end,
    },
    ["txAdmin:events:healedPlayer"] = {
        action   = "heal",
        category = "moderation",
        mapper   = function(data)
            return {
                adminName  = data.author or "txAdmin",
                targetName = data.target and data.target.name or "Unknown",
                targetId   = data.target and data.target.id   or nil,
                reason     = "Healed via txAdmin",
            }
        end,
    },
    ["txAdmin:events:serverShuttingDown"] = {
        action   = "shutdown",
        category = "other",
        mapper   = function(data)
            return {
                adminName  = data.author or "txAdmin",
                targetName = "Server",
                targetId   = nil,
                reason     = data.message or "Server shutdown via txAdmin",
            }
        end,
    },
}

-- ─── txAdmin Player Mode Hook ────────────────────────────────
-- txAdmin fires 'txsv:logger:menuEvent' (a local server event, not a net event)
-- after every in-game menu action. Signature: (src, actionName, allowed, extraData)
-- We listen for playerMode actions to catch noclip and god mode toggles.

AddEventHandler("txsv:logger:menuEvent", function(src, action, allowed, extraData)
    if not allowed then return end
    if action ~= "playerMode" then return end
    if not src or src == 0 then return end

    -- extraData is the mode string: "noclip", "godmode", "superjump"
    local mode = type(extraData) == "string" and extraData:lower() or ""

    -- Only report noclip and god mode
    local modeMap = {
        noclip  = { label = "Toggle NoClip (txAdmin)",  category = "other" },
        godmode = { label = "Toggle God Mode (txAdmin)", category = "other" },
    }
    local meta = modeMap[mode]
    if not meta then return end

    local isAdmin = false
    for _, ace in ipairs(Config.AdminAces) do
        if IsPlayerAceAllowed(src, ace) then isAdmin = true; break end
    end
    for _, ace in ipairs(Config.DevAces) do
        if IsPlayerAceAllowed(src, ace) then isAdmin = true; break end
    end
    if not isAdmin then return end

    local report = {
        id          = ("RPT-%d-%d"):format(src, os.time()),
        command     = tostring(mode):lower(),
        label       = meta.label,
        category    = meta.category,
        args        = {},
        admin       = nil,  -- built below
        target      = nil,
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        reason      = meta.label,
        isDeveloper = false,
        fromScanner = true,
        resource    = "txAdmin",
        txAdmin     = true,
    }

    -- Build admin snapshot inline (BuildPlayerSnapshot is local in main.lua)
    local adminSnap = { serverId = src, name = GetPlayerName(src) or "Unknown", ping = GetPlayerPing(src) }
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            if id:find("^discord:") then adminSnap.discord  = id end
            if id:find("^steam:")   then adminSnap.steam    = id end
            if id:find("^license:") and not id:find("license2") then adminSnap.license = id end
            if id:find("^ip:")      then adminSnap.ip       = id end
        end
    end
    report.admin = adminSnap

    CreateThread(function()
        exports[GetCurrentResourceName()]:CreateWebsiteReport(report)
        exports[GetCurrentResourceName()]:TriggerSiteWebhook(report)
        TriggerClientEvent("gsrp:adminlogs:reportCreated", src, { reportId = report.id, success = true })
    end)
end)

-- ─── Generic Pattern Keywords ────────────────────────────────
-- When scanning unknown resources, we look for these patterns
-- in their registered net events and commands.

local ACTION_PATTERNS = {
    { pattern = "kick",      action = "kick",      category = "moderation" },
    { pattern = "ban",       action = "ban",       category = "moderation" },
    { pattern = "tempban",   action = "tempban",   category = "moderation" },
    { pattern = "warn",      action = "warn",      category = "moderation" },
    { pattern = "freeze",    action = "freeze",    category = "moderation" },
    { pattern = "unfreeze",  action = "unfreeze",  category = "moderation" },
    { pattern = "revive",    action = "revive",    category = "moderation" },
    { pattern = "heal",      action = "heal",      category = "moderation" },
    { pattern = "kill",      action = "kill",      category = "moderation" },
    { pattern = "jail",      action = "jail",      category = "moderation" },
    { pattern = "spectate",  action = "spectate",  category = "spectate"   },
    { pattern = "teleport",  action = "teleport",  category = "teleport"   },
    { pattern = "bring",     action = "bring",     category = "teleport"   },
    { pattern = "summon",    action = "summon",    category = "teleport"   },
    { pattern = "goto",      action = "teleport",  category = "teleport"   },
    { pattern = "noclip",    action = "noclip",    category = "other"      },
    { pattern = "godmode",   action = "godmode",   category = "other"      },
    { pattern = "god",       action = "godmode",   category = "other"      },
    { pattern = "givewep",   action = "giveweapon",category = "spawn"      },
    { pattern = "giveweapon",action = "giveweapon",category = "spawn"      },
    { pattern = "givemoney", action = "givemoney", category = "spawn"      },
    { pattern = "setjob",    action = "setjob",    category = "other"      },
    { pattern = "deletecar", action = "deleteveh", category = "other"      },
    { pattern = "deleteveh", action = "deleteveh", category = "other"      },
    { pattern = "spawncar",  action = "spawnveh",  category = "spawn"      },
    { pattern = "spawnveh",  action = "spawnveh",  category = "spawn"      },
}

-- ─── Scan Results Storage ────────────────────────────────────

Scanner.detected   = {}   -- [resourceName] = { label, hooks = {} }
Scanner.hookedEvents = {}  -- Set of event names already hooked (avoid duplicates)

-- ─── Helper: Get Action From Pattern Match ───────────────────

local function MatchPattern(str)
    local lower = str:lower()
    for _, p in ipairs(ACTION_PATTERNS) do
        if lower:find(p.pattern) then
            return p
        end
    end
    return nil
end

-- ─── Helper: Build Report From Generic Event ────────────────

local function FireGenericReport(source, action, category, args, resourceName, reason)
    local adminSrc = source
    local targetId = tonumber(args and args[1]) or nil

    -- Validate target is an online player
    if targetId and not GetPlayerName(targetId) then
        targetId = nil
    end

    local reportData = {
        command     = action,
        label       = action:sub(1,1):upper() .. action:sub(2) .. " (auto-detected)",
        category    = category,
        args        = args or {},
        reason      = reason or ("Action via " .. resourceName),
        isDeveloper = false,
        fromScanner = true,
        resource    = resourceName,
    }

    -- Trigger the main pipeline
    TriggerEvent("gsrp:adminlogs:autoDetectedAction", adminSrc, targetId, reportData)
end

-- ─── Hook a Single Event ─────────────────────────────────────

local function HookEvent(eventName, resourceName, meta)
    if Scanner.hookedEvents[eventName] then return end
    Scanner.hookedEvents[eventName] = true

    AddEventHandler(eventName, function(...)
        local args = { ... }
        local src  = source

        -- Try the meta mapper (txAdmin pattern)
        if meta.mapper then
            local mapped = meta.mapper(args[1] or {})
            local report = {
                command     = meta.action,
                label       = meta.action:sub(1,1):upper() .. meta.action:sub(2) .. " (txAdmin)",
                category    = meta.category,
                args        = {},
                reason      = mapped.reason or "txAdmin action",
                isDeveloper = false,
                fromScanner = true,
                resource    = "txAdmin",
                txAdmin     = true,
                adminName   = mapped.adminName,
                targetName  = mapped.targetName,
            }
            TriggerEvent("gsrp:adminlogs:autoDetectedAction", src, nil, report, mapped)
            return
        end

        -- Generic event hook
        local targetArg = meta.targetArg or 1
        FireGenericReport(src, meta.action, meta.category, args, resourceName, nil)
    end)

    print(("^3[GSRP Scanner] ^7Hooked event: ^5%s^7 (%s)"):format(eventName, resourceName))
end

-- ─── Main Scan Function ──────────────────────────────────────

function Scanner.Scan()
    print("^3[GSRP Scanner] ^7Starting resource scan…")
    local found = {}

    local numResources = GetNumResources()
    for i = 0, numResources - 1 do
        local resName  = GetResourceByFindIndex(i)
        local resState = GetResourceState(resName)
        if resState ~= "started" and resState ~= "starting" then goto continue end
        if resName == GetCurrentResourceName() then goto continue end

        local resNameLower = resName:lower()

        -- ── 1. Check against known frameworks ──────────────
        for _, fw in ipairs(KNOWN_FRAMEWORKS) do
            for _, knownName in ipairs(fw.names) do
                if resNameLower == knownName:lower() then
                    Scanner.detected[resName] = { label = fw.label, hooks = {} }
                    table.insert(found, { name = resName, label = fw.label })
                    -- Register all event hooks for this framework
                    for eventName, meta in pairs(fw.events) do
                        HookEvent(eventName, fw.label, meta)
                        table.insert(Scanner.detected[resName].hooks, eventName)
                    end
                    print(("^2[GSRP Scanner] ^7Detected known admin resource: ^2%s^7 (%s)"):format(resName, fw.label))
                    break
                end
            end
        end

        -- ── 2. Generic name-based detection ────────────────
        -- If resource name contains admin-related keywords, scan its metadata.
        -- Exclude known FiveM system resources that match keywords but are not admin tools.
        local SYSTEM_RESOURCE_EXCLUSIONS = {
            ["mapmanager"]     = true,
            ["sessionmanager"] = true,
            ["spawnmanager"]   = true,
            ["hardcap"]        = true,
            ["baseevents"]     = true,
            ["chat"]           = true,
            ["monitor"]        = true,
        }

        local adminKeywords = { "admin", "staff", "mod", "moderation", "manage", "panel" }
        local isAdminResource = false
        if not SYSTEM_RESOURCE_EXCLUSIONS[resNameLower] then
            for _, kw in ipairs(adminKeywords) do
                if resNameLower:find(kw) then isAdminResource = true; break end
            end
        end

        if isAdminResource and not Scanner.detected[resName] then
            Scanner.detected[resName] = { label = resName .. " (auto)", hooks = {} }
            table.insert(found, { name = resName, label = resName .. " (auto-detected)" })
            print(("^3[GSRP Scanner] ^7Auto-flagged admin resource: ^3%s^7"):format(resName))

            -- Scan registered commands in this resource
            -- FiveM doesn't expose a command listing API, so we hook via pattern scanning
            -- of well-known event name formats used by this resource name prefix.
            for _, pattern in ipairs(ACTION_PATTERNS) do
                local candidateEvents = {
                    resName .. ":" .. pattern.pattern,
                    resName .. ":server:" .. pattern.pattern,
                    resName .. ":" .. pattern.pattern .. "Player",
                    resName .. ":Server:" .. pattern.pattern .. "Player",
                }
                for _, ev in ipairs(candidateEvents) do
                    HookEvent(ev, resName, { action = pattern.action, category = pattern.category, targetArg = 1 })
                    table.insert(Scanner.detected[resName].hooks, ev)
                end
            end
        end

        ::continue::
    end

    -- ── 3. Hook txAdmin events (always, regardless of whether txAdmin is listed)
    local txAdminPresent = GetResourceState("monitor") == "started"
        or GetResourceState("txAdmin") == "started"
        or GetResourceState("tx") == "started"

    if txAdminPresent then
        print("^2[GSRP Scanner] ^7txAdmin detected — hooking admin events.")
    else
        print("^3[GSRP Scanner] ^7txAdmin not detected — hooking its events anyway (hot-start safe).")
    end

    for eventName, meta in pairs(TXADMIN_EVENTS) do
        HookEvent(eventName, "txAdmin", meta)
    end

    -- ── 4. Hook universal low-level state patterns ──────────
    -- These catch actions done outside any menu (e.g. direct SetEntityCoords calls)
    Scanner.HookLowLevelPatterns()

    -- ── 5. Hook extra resources from config ─────────────────
    for _, resName in ipairs(Config.Scanner.ExtraAdminResources or {}) do
        if not Scanner.detected[resName] then
            Scanner.detected[resName] = { label = resName .. " (config)", hooks = {} }
            print(("^3[GSRP Scanner] ^7Extra admin resource from config: ^3%s^7"):format(resName))
            for _, pattern in ipairs(ACTION_PATTERNS) do
                local ev = resName .. ":" .. pattern.pattern
                HookEvent(ev, resName, { action = pattern.action, category = pattern.category, targetArg = 1 })
            end
        end
    end

    -- ── 6. Hook extra events from config ─────────────────
    for eventName, meta in pairs(Config.Scanner.ExtraEvents or {}) do
        HookEvent(eventName, "config", { action = meta.action, category = meta.category, targetArg = 1 })
    end

    -- ── 7. Log detected resources locally (no API call — website doesn't accept scanner_startup)
    if #found > 0 then
        local names = {}
        for _, f in ipairs(found) do table.insert(names, f.label) end
        print(("^2[GSRP Scanner] ^7Detected resources: %s"):format(table.concat(names, ", ")))
    end

    print(("^2[GSRP Scanner] ^7Scan complete. %d admin resource(s) detected, %d event(s) hooked."):format(
        #found,
        (function() local c = 0; for _ in pairs(Scanner.hookedEvents) do c = c + 1 end; return c end)()
    ))
end

-- ─── Low-Level Pattern Hooks ─────────────────────────────────
-- These are net-events that almost every admin menu fires for
-- basic actions, regardless of framework.

function Scanner.HookLowLevelPatterns()

    -- Universal teleport detection (admin→player / player→admin)
    local teleportEvents = {
        "adminTP", "admin:tp", "admin:teleport", "playerBring", "admin:bring",
        "adminBring", "tpToPlayer", "bringPlayer", "goToPlayer",
    }
    for _, ev in ipairs(teleportEvents) do
        if not Scanner.hookedEvents[ev] then
            Scanner.hookedEvents[ev] = true
            AddEventHandler(ev, function(targetId, ...)
                FireGenericReport(source, "teleport", "teleport", { targetId }, ev, nil)
            end)
        end
    end

    -- Universal freeze detection
    local freezeEvents = {
        "adminFreeze", "admin:freeze", "freezePlayer", "admin:freezePlayer",
    }
    for _, ev in ipairs(freezeEvents) do
        if not Scanner.hookedEvents[ev] then
            Scanner.hookedEvents[ev] = true
            AddEventHandler(ev, function(targetId, ...)
                FireGenericReport(source, "freeze", "moderation", { targetId }, ev, nil)
            end)
        end
    end

    -- Universal kill detection
    local killEvents = {
        "adminKill", "admin:kill", "killPlayer", "admin:killPlayer",
    }
    for _, ev in ipairs(killEvents) do
        if not Scanner.hookedEvents[ev] then
            Scanner.hookedEvents[ev] = true
            AddEventHandler(ev, function(targetId, ...)
                FireGenericReport(source, "kill", "moderation", { targetId }, ev, nil)
            end)
        end
    end

    -- Universal spectate
    local specEvents = { "adminSpectate", "admin:spectate", "spectatePlayer" }
    for _, ev in ipairs(specEvents) do
        if not Scanner.hookedEvents[ev] then
            Scanner.hookedEvents[ev] = true
            AddEventHandler(ev, function(targetId, ...)
                FireGenericReport(source, "spectate", "spectate", { targetId }, ev, nil)
            end)
        end
    end

    print("^3[GSRP Scanner] ^7Low-level pattern hooks registered.")
end

-- ─── Auto-Detected Action Handler ───────────────────────────
-- Receives from HookEvent and low-level hooks. Decides whether
-- to show the NUI form or auto-file the report (txAdmin = auto).

AddEventHandler("gsrp:adminlogs:autoDetectedAction", function(adminSrc, targetId, reportData, txAdminMeta)
    local src = adminSrc

    -- Validate admin permission
    local isAdmin = false
    for _, ace in ipairs(Config.AdminAces) do
        if IsPlayerAceAllowed(src, ace) then isAdmin = true; break end
    end
    for _, ace in ipairs(Config.DevAces) do
        if IsPlayerAceAllowed(src, ace) then isAdmin = true; break end
    end

    -- For txAdmin actions, src is 0 (server) — allow through
    if src == 0 and reportData.txAdmin then isAdmin = true end

    if not isAdmin and src ~= 0 then return end

    local isDev = false
    for _, ace in ipairs(Config.DevAces) do
        if IsPlayerAceAllowed(src, ace) then isDev = true; break end
    end

    -- Build snapshots
    local adminSnap = nil
    if src and src > 0 then
        adminSnap = {
            serverId = src,
            name     = GetPlayerName(src) or "Unknown",
            ping     = GetPlayerPing(src),
        }
        for i = 0, GetNumPlayerIdentifiers(src) - 1 do
            local id = GetPlayerIdentifier(src, i)
            if id then
                if id:find("^discord:") then adminSnap.discord  = id end
                if id:find("^steam:")   then adminSnap.steam    = id end
                if id:find("^license:") and not id:find("license2") then adminSnap.license = id end
                if id:find("^ip:")      then adminSnap.ip       = id end
            end
        end
    elseif txAdminMeta then
        adminSnap = {
            serverId = 0,
            name     = txAdminMeta.adminName or "txAdmin",
            ping     = 0,
        }
    end

    local targetSnap = nil
    if targetId and targetId > 0 and GetPlayerName(targetId) then
        targetSnap = {
            serverId = targetId,
            name     = GetPlayerName(targetId) or "Unknown",
            ping     = GetPlayerPing(targetId),
        }
        for i = 0, GetNumPlayerIdentifiers(targetId) - 1 do
            local id = GetPlayerIdentifier(targetId, i)
            if id then
                if id:find("^discord:") then targetSnap.discord  = id end
                if id:find("^steam:")   then targetSnap.steam    = id end
                if id:find("^license:") and not id:find("license2") then targetSnap.license = id end
            end
        end
    elseif txAdminMeta and txAdminMeta.targetName then
        targetSnap = { serverId = nil, name = txAdminMeta.targetName, ping = 0 }
    end

    local report = {
        id          = ("RPT-%d-%d"):format(src or 0, os.time()),
        command     = reportData.command,
        label       = reportData.label,
        category    = reportData.category,
        args        = reportData.args or {},
        admin       = adminSnap,
        target      = targetSnap,
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        isDev       = isDev,
        fromScanner = true,
        resource    = reportData.resource,
    }

    -- txAdmin actions: always auto-file (no NUI possible from web panel)
    -- Also auto-file if Config.Scanner.AutoFileDetected is true
    local shouldAutoFile = (reportData.txAdmin or src == 0) or Config.Scanner.AutoFileDetected
    if shouldAutoFile then
        report.reason      = reportData.reason or ("Auto-detected action via " .. (reportData.resource or "scanner"))
        report.isDeveloper = false
        CreateThread(function()
            exports[GetCurrentResourceName()]:CreateWebsiteReport(report)
            exports[GetCurrentResourceName()]:TriggerSiteWebhook(report)
        end)
        return
    end

    -- Show the NUI form so admin can enter a reason
    if not _G._gsrpPendingReports then _G._gsrpPendingReports = {} end
    _G._gsrpPendingReports[src] = report

    TriggerClientEvent("gsrp:adminlogs:showForm", src, {
        reportId = report.id,
        command  = report.command,
        label    = report.label,
        category = report.category,
        target   = targetSnap and { name = targetSnap.name, serverId = targetSnap.serverId } or nil,
        isDev    = isDev,
        source   = reportData.resource or "auto-detected",
    })

    SetTimeout(Config.UI.FormTimeout, function()
        if _G._gsrpPendingReports and _G._gsrpPendingReports[src] then
            _G._gsrpPendingReports[src] = nil
        end
    end)
end)

-- ─── Re-scan on Resource Start ───────────────────────────────
-- If a new admin resource is started after boot, hook it too.

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then return end
    Wait(500)  -- Let the resource initialise

    local resNameLower = resourceName:lower()
    for _, fw in ipairs(KNOWN_FRAMEWORKS) do
        for _, knownName in ipairs(fw.names) do
            if resNameLower == knownName:lower() then
                print(("^3[GSRP Scanner] ^7Late-start resource detected: ^3%s^7 — hooking events."):format(resourceName))
                for eventName, meta in pairs(fw.events) do
                    HookEvent(eventName, fw.label, meta)
                end
                break
            end
        end
    end
end)

-- ─── Startup ─────────────────────────────────────────────────

CreateThread(function()
    Wait(3000)  -- Wait for all resources to finish starting
    Scanner.Scan()
end)

print("^2[GSRP AdminLogs] ^7Scanner module loaded.")
