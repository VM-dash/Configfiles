-- ~/.config/hypr/hyprland.lua — managed by chezmoi.
--
-- Hyprland ≥0.55 is configured in Lua (hyprlang .conf is deprecated). This
-- session runs ALONGSIDE GNOME: GDM shows both, pick at login. Noctalia
-- (noctalia.dev) provides the shell layer — bar, launcher, notifications,
-- control center, OSD, wallpaper — and owns desktop theming (wallpaper-driven;
-- see ~/.config/noctalia/config.toml). The `theme` script deliberately does
-- not touch this session's colors; it keeps owning terminals and editors.

------------------
---- MONITORS ----
------------------

-- Sensible default for any output not matched below.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Desk layout, left to right: laptop · Dell 87Y9ZY3 · Dell 17T9ZY3.
-- The Dells are pinned by desc: their DP-N port names change between replugs
-- (DP-7/DP-8 one day, DP-5/DP-6 the next). All three are 1920x1080.
hl.monitor({ output = "eDP-1",                              mode = "preferred", position = "0x0",    scale = 1 })
hl.monitor({ output = "desc:Dell Inc. DELL P2422H 87Y9ZY3", mode = "preferred", position = "1920x0", scale = 1 })
hl.monitor({ output = "desc:Dell Inc. DELL P2422H 17T9ZY3", mode = "preferred", position = "3840x0", scale = 1 })

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "ghostty"
local fileManager = "nautilus"
local noctalia    = "noctalia msg " -- IPC to the shell

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
    -- Polkit auth dialogs (GNOME's agent is shell-bound).
    hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Gaps/rounding/blur follow Noctalia's recommended Hyprland settings.
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        layout      = "dwindle",
    },
    decoration = {
        rounding       = 20,
        rounding_power = 2,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1a1a1a,
        },
        blur = {
            enabled  = true,
            size     = 3,
            passes   = 2,
            vibrancy = 0.1696,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        disable_hyprland_logo   = true, -- Noctalia draws the wallpaper
        force_default_wallpaper = 0,
    },
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = true, -- matches the GNOME session
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Noctalia surfaces: blur them, and let Noctalia animate itself.
hl.layer_rule({
    name  = "noctalia",
    match = {
        namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$",
    },
    no_anim      = true,
    ignore_alpha = 0.5,
    blur         = true,
    blur_popups  = true,
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"
local home    = os.getenv("HOME")

-- Every bind goes through this helper so the cheatsheet stays in lockstep
-- with reality: it registers the bind AND records "keys — description".
-- `hypr-cheatsheet` (Super + /) shows the recorded list in the launcher —
-- `hyprctl binds` is useless for this, Lua binds all report as "__lua".
local cheatsheet = {}
local function bind(keys, action, desc, opts)
    hl.bind(keys, action, opts)
    table.insert(cheatsheet, string.format("%-24s %s", keys, desc))
end
local function cheat(keys, desc) -- entry only, no bind (loops, switches)
    table.insert(cheatsheet, string.format("%-24s %s", keys, desc))
end

-- Apps
bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal),                       "Terminal (ghostty)")
bind(mainMod .. " + E",      hl.dsp.exec_cmd(fileManager),                    "File manager")
bind(mainMod .. " + Q",      hl.dsp.window.close(),                           "Close window")
bind(mainMod .. " + F",      hl.dsp.window.fullscreen({ action = "toggle" }), "Fullscreen")
bind(mainMod .. " + V",      hl.dsp.window.float({ action = "toggle" }),      "Float window")

-- Noctalia shell
bind(mainMod .. " + Space", hl.dsp.exec_cmd(noctalia .. "panel-toggle launcher"),       "App launcher")
bind(mainMod .. " + S",     hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center"), "Control center")
bind(mainMod .. " + comma", hl.dsp.exec_cmd(noctalia .. "settings-toggle"),             "Noctalia settings")
bind("ALT + Tab",           hl.dsp.exec_cmd(noctalia .. "window-switcher"),             "Window switcher")

-- Parity with the GNOME session
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region"), "Screenshot (region)")
bind(mainMod .. " + L",         hl.dsp.exec_cmd("hyprlock"),           "Lock screen")
bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("theme next --quiet"), "Cycle terminal/editor theme")

-- This cheatsheet
bind(mainMod .. " + slash", hl.dsp.exec_cmd(home .. "/.local/bin/hypr-cheatsheet"), "Keybinding cheatsheet")

-- Focus with mainMod + arrows
bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }),  "Focus left")
bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), "Focus right")
bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }),    "Focus up")
bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }),  "Focus down")

-- Workspaces: mainMod + [0-9] switches, + SHIFT moves the window
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
cheat(mainMod .. " + 1..9,0",         "Go to workspace 1-10")
cheat(mainMod .. " + SHIFT + 1..9,0", "Move window to workspace 1-10")

-- mainMod + scroll cycles workspaces; mainMod + LMB/RMB drags/resizes
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next workspace (scroll)")
bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), "Prev workspace (scroll)")
bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   "Drag window (LMB)",   { mouse = true })
bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), "Resize window (RMB)", { mouse = true })

-- Media keys through Noctalia (it draws the OSD)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(noctalia .. "volume-up"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(noctalia .. "volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(noctalia .. "volume-mute"), { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

------------------------
---- LID / CLAMSHELL ----
------------------------

-- GNOME handles the lid itself; Hyprland must be told. kd-clamshell disables
-- eDP-1 on close only when an external monitor is active (otherwise logind's
-- default lid-close suspend takes over) and re-enables it on open.
hl.bind("switch:on:Lid Switch",  hl.dsp.exec_cmd(home .. "/.local/bin/kd-clamshell close"), { locked = true })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd(home .. "/.local/bin/kd-clamshell open"),  { locked = true })
cheat("(lid close/open)", "External screen: laptop panel off/on")

-- Publish the cheatsheet. pcall: binds must survive even if io is ever
-- unavailable in the config environment.
pcall(function()
    local f = assert(io.open(home .. "/.cache/hypr-cheatsheet.txt", "w"))
    f:write(table.concat(cheatsheet, "\n"), "\n")
    f:close()
end)

----------------------
---- WINDOW RULES ----
----------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class = "^$", title = "^$",
        xwayland = true, float = true, fullscreen = false, pin = false,
    },
    no_focus = true,
})
