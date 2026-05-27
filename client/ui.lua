-- ============================================================
--  GSRP Admin Logger — Client UI (NUI Bridge)
-- ============================================================

local nuiOpen = false

local function OpenNUI(data)
    if nuiOpen then return end
    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openForm",
        data   = data,
    })
end

local function CloseNUI()
    nuiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "closeForm" })
end

-- ─── Server → Client: Show Form ─────────────────────────────

RegisterNetEvent("gsrp:adminlogs:showForm", function(data)
    OpenNUI(data)
end)

-- ─── NUI Callbacks ──────────────────────────────────────────

RegisterNUICallback("submitForm", function(data, cb)
    CloseNUI()
    TriggerServerEvent("gsrp:adminlogs:formSubmitted", {
        reason      = data.reason,
        isDeveloper = data.isDeveloper or false,
    })
    cb({ ok = true })
end)

RegisterNUICallback("cancelForm", function(_, cb)
    CloseNUI()
    TriggerServerEvent("gsrp:adminlogs:formCancelled")
    cb({ ok = true })
end)

RegisterNUICallback("devButton", function(_, cb)
    CloseNUI()
    TriggerServerEvent("gsrp:adminlogs:formSubmitted", {
        reason      = "Developer Use",
        isDeveloper = true,
    })
    cb({ ok = true })
end)

-- Close on Escape key
CreateThread(function()
    while true do
        Wait(0)
        if nuiOpen and IsControlJustReleased(0, 200) then  -- 200 = Escape
            CloseNUI()
            TriggerServerEvent("gsrp:adminlogs:formCancelled")
        end
    end
end)

print("^2[GSRP AdminLogs] ^7UI bridge loaded.")
