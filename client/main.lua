-- ============================================================
--  GSRP Admin Logger — Client Main
--  Detects when the local player types a tracked command and
--  notifies the server to start the report pipeline.
-- ============================================================

local formOpen    = false
local isAdmin     = false
local isDev       = false

-- ─── Permission Check ───────────────────────────────────────

CreateThread(function()
    Wait(2000)  -- Wait for ACE sync
    -- We ask the server whether we are admin/dev via a callback
    TriggerServerEvent("gsrp:adminlogs:checkPermissions")
end)

RegisterNetEvent("gsrp:adminlogs:permissionsResult", function(data)
    isAdmin = data.isAdmin
    isDev   = data.isDev
end)

RegisterServerEvent = RegisterServerEvent or function() end

-- ─── Chat Command Interception ──────────────────────────────
-- Hook into the chat input so we can detect tracked commands
-- before they are processed.

AddEventHandler("chat:chatMessage", function(author, _, message)
    -- message arrives as "/command args..."
    if not message:find("^/") then return end
    if not isAdmin then return end

    local parts   = {}
    for part in message:gmatch("%S+") do table.insert(parts, part) end
    if #parts == 0 then return end

    local cmd  = parts[1]:sub(2):lower()  -- strip leading /
    local args = {}
    for i = 2, #parts do args[i - 1] = parts[i] end

    if Config.TrackedCommands[cmd] then
        -- Cancel the default chat send so the UI appears first
        -- (The actual command is executed server-side after reason is filed)
        CancelEvent()
        TriggerServerEvent("gsrp:adminlogs:commandDetected", {
            command  = cmd,
            args     = args,
            targetId = args[1],
        })
    end
end)

-- ─── Notification Helpers ───────────────────────────────────

local function Notify(msg, type)
    -- Try ox_lib, fall back to simple chat message
    if GetResourceState("ox_lib") == "started" then
        exports["ox_lib"]:notify({ title = "Admin Logger", description = msg, type = type or "info" })
    else
        TriggerEvent("chat:addMessage", { args = { "^3AdminLogger", msg } })
    end
end

-- ─── Report Created Feedback ────────────────────────────────

RegisterNetEvent("gsrp:adminlogs:reportCreated", function(data)
    if data.success then
        Notify("✅ Report " .. data.reportId .. " filed successfully.", "success")
    else
        Notify("❌ Report filing failed. Check server console.", "error")
    end
end)


print("^2[GSRP AdminLogs] ^7Client main loaded.")
