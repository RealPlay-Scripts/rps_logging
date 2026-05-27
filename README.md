# Rps Admin Logger v2.0
**Advanced Admin Logging System — Discord Webhooks + Website API + In-Game NUI**

---

## Features

- 🎮 **In-game NUI report form** — appears automatically when any admin uses a tracked command
- 🛠️ **Developer bypass button** — devs skip the form and auto-file "Developer Use"
- 📡 **Discord webhook logging** — rich embeds with admin/target identifiers, category colour-coding
- 🌐 **Website API integration** — creates reports on your Golden Shores RP website under the admin's account
- 🔄 **Live heartbeat** — posts player counts to `/api/server/heartbeat` on your site
- 📊 **Kill/death stats** — forwards kill events to `/api/server/stats`
- 🔌 **Disconnect logging** — forwards drop events to `/api/server/disconnect`
- 📤 **Export API** — other resources can call `exports["rps_adminlogs"]:LogAdminAction(...)` to use this system

---

## Installation

1. Drop the `rps_adminlogs` folder into your **resources** directory.
2. Add `ensure rps_adminlogs` to your `server.cfg`.
3. Edit **`shared/config.lua`**:
   - Set `Config.API.Key` to your bot API key from the website.
   - Set `Config.API.BaseURL` to `https://web.goldenshoresrp.com`.
   - Set your Discord webhook URLs for `AdminLog`, `DevLog`, and `AlertLog`.
   - Add/remove commands from `Config.TrackedCommands` as needed.
   - Add your ace permission groups to `Config.AdminAces` and `Config.DevAces`.

---

## API Authentication

The script sends **both** authentication methods on every request:

| Method | Value |
|--------|-------|
| `X-API-Key` header | Your bot API key |
| `?api_key=` query param | *Not used by default — add to POST URL in `api.lua` if required* |

---

## How It Works

```
Admin types /kick 5
        ↓
Client detects command (chat hook)
        ↓
Server: builds admin + target snapshot
        ↓
Server: sends showForm event to admin's client
        ↓
Admin sees NUI form in-game
        ↓
Admin selects reason or clicks "Developer Use"
        ↓
Server receives formSubmitted event
        ↓
┌───────────────────┬───────────────────┬───────────────────┐
│  Discord Webhook  │  POST /api/webhooks│  POST /api/webhooks│
│  (rich embed)     │  /trigger          │  /trigger          │
│                   │  event: admin_report│  event: admin_action│
│                   │  _created          │                    │
└───────────────────┴───────────────────┴───────────────────┘
```

---

## Permission Setup (server.cfg)

```cfg
# Admin aces
add_ace group.admin   rps.admin  allow
add_ace group.moderator rps.admin allow
add_principal identifier.discord:YOUR_DISCORD_ID group.developer

# Ensure resource last so aces are loaded
ensure rps_adminlogs
```

---

## Tracked Commands

Edit `Config.TrackedCommands` in `shared/config.lua` to add, remove, or modify commands:

```lua
Config.TrackedCommands = {
    ["mute"] = { label = "Mute Player", category = "moderation", requiresTarget = true },
    -- ...
}
```

**Categories** (affect Discord embed colour):
- `moderation` — Red
- `teleport` — Blue
- `spectate` — Purple
- `spawn` — Green
- `other` — Yellow

---

## Using from Other Resources

```lua
-- Log an admin action from another resource
exports["rps_adminlogs"]:LogAdminAction(
    adminServerId,   -- number
    targetServerId,  -- number or nil
    "customcmd",     -- command name string
    "Reason here",   -- reason string
    "moderation"     -- category string
)
```

---

## File Structure

```
rps_adminlogs/
├── fxmanifest.lua
├── shared/
│   └── config.lua          ← Edit this
├── server/
│   ├── main.lua            ← Core pipeline
│   ├── api.lua             ← Website API calls
│   ├── discord.lua         ← Webhook formatting
│   └── hooks.lua           ← Command interception
├── client/
│   ├── main.lua            ← Command detection
│   └── ui.lua              ← NUI bridge
└── ui/
    └── html/
        └── index.html      ← In-game form
```

---

## Notes

- The script is **framework-agnostic** (no ESX/QBCore dependency).
- If you use a framework that already defines commands like `/kick`, remove the `RegisterCommand` blocks in `server/hooks.lua` and fire `rps:adminlogs:commandDetected` from your framework's command handlers instead.
- Screenshots are not natively supported by FiveM's NUI system; consider a third-party screenshot resource and call `LogAdminAction` from its callback.

---

*Golden Shores RP — Admin Logging System v2.0*
