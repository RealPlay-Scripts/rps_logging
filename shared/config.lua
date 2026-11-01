-- ============================================================
--  GSRP Admin Logger — Shared Configuration v3.0
--  All logging routes through your Golden Shores RP website API.
-- ============================================================

Config = {}

-- ─── Website API ────────────────────────────────────────────
-- Set as server convars in server.cfg, never commit real values here:
--   set rps_logging_api_url "https://yoursite.example"
--   set rps_logging_api_key "your-api-key"   (write scope)
Config.API = {
    BaseURL  = GetConvar('rps_logging_api_url', 'https://yoursite.example'),  -- No trailing slash
    Key      = GetConvar('rps_logging_api_key', ''),  -- Sent as X-API-Key header AND ?api_key=
    Version  = "1.0",
    Timeout  = 10000,
}

-- ─── Permissions ────────────────────────────────────────────
Config.AdminAces = {
    "group.admin",
    "group.moderator",
    "group.headadmin",
    "group.superadmin",
}

Config.DevAces = {
    "group.developer",
    "group.owner",
}

-- ─── Heartbeat ──────────────────────────────────────────────
Config.HeartbeatInterval = 60000

-- ─── Manually Tracked Commands ──────────────────────────────
Config.TrackedCommands = {
    ["kick"]       = { label = "Kick Player",       category = "moderation", requiresTarget = true  },
    ["ban"]        = { label = "Ban Player",         category = "moderation", requiresTarget = true  },
    ["tempban"]    = { label = "Temp-Ban Player",    category = "moderation", requiresTarget = true  },
    ["warn"]       = { label = "Warn Player",        category = "moderation", requiresTarget = true  },
    ["freeze"]     = { label = "Freeze Player",      category = "moderation", requiresTarget = true  },
    ["unfreeze"]   = { label = "Unfreeze Player",    category = "moderation", requiresTarget = true  },
    ["tp"]         = { label = "Teleport to Player", category = "teleport",   requiresTarget = true  },
    ["tpm"]        = { label = "Teleport to Marker", category = "teleport",   requiresTarget = false },
    ["spectate"]   = { label = "Spectate Player",    category = "spectate",   requiresTarget = true  },
    ["noclip"]     = { label = "Toggle NoClip",      category = "other",      requiresTarget = false },
    ["god"]        = { label = "Toggle Godmode",     category = "other",      requiresTarget = false },
    ["giveweapon"] = { label = "Give Weapon",        category = "spawn",      requiresTarget = true  },
    ["givemoney"]  = { label = "Give Money",         category = "spawn",      requiresTarget = true  },
    ["setjob"]     = { label = "Set Job",            category = "other",      requiresTarget = true  },
    ["revive"]     = { label = "Revive Player",      category = "moderation", requiresTarget = true  },
    ["heal"]       = { label = "Heal Player",        category = "moderation", requiresTarget = true  },
    ["jail"]       = { label = "Jail Player",        category = "moderation", requiresTarget = true  },
    ["unjail"]     = { label = "Unjail Player",      category = "moderation", requiresTarget = true  },
    ["deletecar"]  = { label = "Delete Vehicle",     category = "other",      requiresTarget = false },
    ["spawncar"]   = { label = "Spawn Vehicle",      category = "spawn",      requiresTarget = false },
    ["bring"]      = { label = "Bring Player",       category = "teleport",   requiresTarget = true  },
    ["kill"]       = { label = "Kill Player",        category = "moderation", requiresTarget = true  },
    ["setmodel"]   = { label = "Set Player Model",   category = "other",      requiresTarget = true  },
}

-- ─── Scanner Settings ───────────────────────────────────────
Config.Scanner = {
    StartupDelay     = 3000,   -- ms after boot before scanning

    -- If true, auto-detected events from third-party menus skip the NUI
    -- form and file directly (useful when you trust your admin tools).
    AutoFileDetected = false,

    -- txAdmin always auto-files since actions come from the web panel.
    AutoFileTxAdmin  = true,

    -- Add any custom resource names to always treat as admin resources.
    ExtraAdminResources = {
        -- "gsrp_staff_menu",
    },

    -- Extra events to hook beyond what the scanner auto-detects.
    ExtraEvents = {
        -- ["myresource:kickPlayer"] = { action = "kick", category = "moderation" },
    },
}

-- ─── UI ─────────────────────────────────────────────────────
Config.UI = {
    FormTimeout = 120000,
    QuickReasons = {
        "Breaking Server Rules",
        "RDM / VDM",
        "Exploiting / Cheating",
        "Harassment / Toxicity",
        "LTAP (Leaving to Avoid Punishment)",
        "Fail RP",
        "Staff Assistance / Test",
        "Whitelisted Request",
        "Developer Test Action",
    },
}
