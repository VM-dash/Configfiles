-- ~/.config/hypr/hyprland.lua — managed by chezmoi.
--
-- Hyprland ≥0.55 is configured in Lua (hyprlang .conf is deprecated). This
-- session runs ALONGSIDE GNOME: GDM shows both, pick at login. Noctalia
-- (noctalia.dev) provides the shell layer — bar, launcher, notifications,
-- control center, OSD, wallpaper — and owns desktop theming (wallpaper-driven;
-- see ~/.config/noctalia/config.toml). The `theme` script deliberately does
-- not touch this session's colors; it keeps owning terminals and editors.

-------------------------------
---- MONITORS & WORKSPACES ----
-------------------------------

-- Two desks, one config. Which external screens are connected decides the
-- arrangement AND where workspaces live:
--   office  two Dell P2422H on the dock: laptop left, Dells to the right;
--           ws 1-3 left Dell, 4-6 right Dell, 7 laptop
--   home    Dell U2415 over HDMI, standing ABOVE the laptop;
--           ws 1-3 laptop, 4-6 U2415
--   alone   everything on the laptop
-- Externals are matched by desc: — DP-N port names drift between replugs.
-- KD.apply_layout() runs at load and on every monitor (dis)connect; the
-- lid script calls it too (KD is global so `hyprctl eval` can reach it).

local laptop    = "eDP-1"
local dellLeft  = "desc:Dell Inc. DELL P2422H 87Y9ZY3"
local dellRight = "desc:Dell Inc. DELL P2422H 17T9ZY3"
local dellHome  = "desc:Dell Inc. DELL U2415 7MT0186C0C5U"

local function lidClosed()
    local f = io.open("/proc/acpi/button/lid/LID/state")
    if not f then return false end
    local state = f:read("*a") or ""
    f:close()
    return state:find("closed") ~= nil
end

local function present(sel)
    for _, m in ipairs(hl.get_monitors()) do
        if sel == m.name or sel == "desc:" .. m.description then return true end
    end
    return false
end

KD = KD or {}

function KD.apply_layout()
    local office = present(dellLeft) or present(dellRight)
    local home   = present(dellHome)
    -- The panel goes dark with the lid shut only while an external screen
    -- can take over; alone, logind's lid-close suspend is the right answer.
    local panelOff = lidClosed() and (office or home)

    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })
    if home then
        hl.monitor({ output = dellHome, mode = "preferred", position = "0x0",    scale = 1 })
        hl.monitor({ output = laptop,   mode = "preferred", position = "0x1200", scale = 1, disabled = panelOff })
    else
        hl.monitor({ output = laptop,    mode = "preferred", position = "0x0",    scale = 1, disabled = panelOff })
        hl.monitor({ output = dellLeft,  mode = "preferred", position = "1920x0", scale = 1 })
        hl.monitor({ output = dellRight, mode = "preferred", position = "3840x0", scale = 1 })
    end

    local low, high  -- monitors for ws 1-3 and 4-6
    if home then
        low, high = laptop, dellHome
    elseif office then
        low, high = dellLeft, dellRight
    else
        low, high = laptop, laptop
    end
    -- Every workspace tiles with the scrolling layout (a workspace otherwise
    -- keeps the layout it was created with); Super+T overrides per workspace.
    for i = 1, 3 do
        hl.workspace_rule({ workspace = tostring(i), monitor = low,  persistent = true, default = (i == 1), layout = "scrolling" })
    end
    for i = 4, 6 do
        hl.workspace_rule({ workspace = tostring(i), monitor = high, persistent = true, default = (i == 4), layout = "scrolling" })
    end
    -- ws 7: the laptop panel at the office (the Dells own 1-6 there).
    hl.workspace_rule({ workspace = "7", monitor = laptop, default = office, layout = "scrolling" })
    for i = 8, 10 do
        hl.workspace_rule({ workspace = tostring(i), layout = "scrolling" })
    end
    if office and not panelOff then
        pcall(function() hl.dispatch(hl.dsp.workspace.move({ workspace = 7, monitor = laptop })) end)
    end
end

KD.apply_layout()
hl.on("monitor.added",   function() KD.apply_layout() end)
hl.on("monitor.removed", function() KD.apply_layout() end)

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
    -- Bring up graphical-session.target (see hyprland-session.target): the
    -- portals, the polkit agent and every WantedBy=graphical-session.target
    -- user unit (icon sync, QuickAccent) hang off it.
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE"
        .. " && dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XCURSOR_THEME XCURSOR_SIZE HYPRCURSOR_THEME HYPRCURSOR_SIZE"
        .. " && systemctl --user start hyprland-session.target")
    hl.exec_cmd("noctalia")
    -- env only affects new clients; this switches the compositor's own
    -- cursor (and, via gsettings sync, running GTK apps) right away.
    hl.exec_cmd("hyprctl setcursor " .. cursorTheme .. " " .. cursorSize)
    -- hyprpm-managed plugins (ScrollOverview); built by 24-hypr-plugins.
    hl.exec_cmd("hyprpm reload -n")
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Same Rosé Pine cursor as the GNOME session (seeded into ~/.local/share/icons
-- by .chezmoiexternal.toml; XCursor format — Hyprland falls back to it when
-- there is no hyprcursor manifest). Hyprland's cursor:sync_gsettings_theme
-- then pushes theme + size into org.gnome.desktop.interface itself, which is
-- what GTK apps read — so this is the single source for both.
local cursorTheme = "BreezeX-RosePine-Linux"
local cursorSize  = 24
hl.env("XCURSOR_THEME", cursorTheme)
hl.env("HYPRCURSOR_THEME", cursorTheme)
hl.env("XCURSOR_SIZE", tostring(cursorSize))
hl.env("HYPRCURSOR_SIZE", tostring(cursorSize))

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Gaps/rounding/blur follow Noctalia's recommended Hyprland settings.
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        layout      = "scrolling", -- workspace rules pin it too; Super+T overrides per workspace
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
    scrolling = {
        fullscreen_on_one_column = true,
        column_width = 0.5,
    },
    master = {
        new_status = "master",
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

-- ScrollOverview (yayuuu/hyprland-scroll-overview): niri-style zoomed-out
-- view of every workspace on every monitor — Super+G. Loaded by hyprpm at
-- start; the plugin registers these keys when it loads, so a fresh session
-- without the build just ignores them.
hl.config({
    plugin = {
        scrolloverview = {
            gesture_distance = 300,
            scale            = 0.5,
            workspace_gap    = 100,
            layout           = "auto",   -- per-monitor orientation
            wallpaper        = 2,
            blur             = true,
            shadow = { enabled = true, range = 50 },
        },
    },
})

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
bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd(noctalia .. "panel-toggle clipboard"),  "Clipboard history")
bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd(terminal .. " -e hyprmoncfg"),           "Monitor layout editor (hyprmoncfg)")

-- Tiling layouts: scrolling (niri-style columns) or master
bind(mainMod .. " + T",                 hl.dsp.exec_cmd(home .. "/.local/bin/hypr-layout"), "This workspace: toggle scrolling <-> master")
bind(mainMod .. " + bracketleft",       hl.dsp.layout("move -col"),          "Scrolling: scroll one column left")
bind(mainMod .. " + bracketright",      hl.dsp.layout("move +col"),          "Scrolling: scroll one column right")
bind(mainMod .. " + SHIFT + bracketleft",  hl.dsp.layout("swapcol l"),       "Scrolling: swap column left")
bind(mainMod .. " + SHIFT + bracketright", hl.dsp.layout("swapcol r"),       "Scrolling: swap column right")
bind(mainMod .. " + BackSpace",         hl.dsp.layout("consume_or_expel next"), "Scrolling: merge into / split out of column")
bind(mainMod .. " + equal",             hl.dsp.layout("colresize +conf"),    "Scrolling: wider column (presets)")
bind(mainMod .. " + minus",             hl.dsp.layout("colresize -conf"),    "Scrolling: narrower column (presets)")
bind(mainMod .. " + M",                 hl.dsp.layout("swapwithmaster"),     "Master: swap focused with master")

-- Parity with the GNOME session
bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region"), "Screenshot (region)")
-- For things that close on focus loss (menus, Noctalia panels): no picker,
-- a 3 s countdown, the whole active screen, straight into Gradia to crop.
bind(mainMod .. " + SHIFT + ALT + S", hl.dsp.exec_cmd(home .. "/.local/bin/kd-shot-delayed"), "Screenshot in 3 s → Gradia (keeps popups open)")
bind(mainMod .. " + L",         hl.dsp.exec_cmd(noctalia .. "session lock"), "Lock screen (Noctalia)")
bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("theme next --quiet"), "Cycle terminal/editor theme")

-- Overview of all workspaces (ScrollOverview plugin)
bind(mainMod .. " + G", function()
    if hl.plugin and hl.plugin.scrolloverview then
        hl.plugin.scrolloverview.overview("toggle all")
    else
        hl.exec_cmd("notify-send -a hyprland 'ScrollOverview not loaded' 'run: chezmoi apply (24-hypr-plugins)'")
    end
end, "Overview of all workspaces (ScrollOverview)")

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
cheat(mainMod .. " + 1..9,0",         "Go to workspace (office: 1-3/4-6 Dells, 7 laptop · home: 1-3 laptop, 4-6 U2415)")
cheat(mainMod .. " + SHIFT + 1..9,0", "Move window to workspace 1-10")

-- mainMod + scroll cycles workspaces; mainMod + LMB/RMB drags/resizes.
-- "m+1"/"m-1" stay on the focused monitor and wrap (1-3 here, 4-6 there);
-- "e+1"/"e-1" would walk onto the other screen's workspaces instead.
bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" }), "Next workspace on this screen (scroll)")
bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "m-1" }), "Prev workspace on this screen (scroll)")
-- Add SHIFT to walk every workspace instead, crossing to the other screen.
bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "e+1" }), "Next workspace, any screen (scroll)")
bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), "Prev workspace, any screen (scroll)")
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

-- Nautilus is a quick-look tool here, not a tiled workspace citizen.
hl.window_rule({
    name  = "nautilus-floating",
    match = { class = "^org\\.gnome\\.Nautilus$" },
    float  = true,
    size   = "60% 70%",
    center = true,
})

-- Space-bar file preview (sushi): a quick-look overlay, never a tile.
hl.window_rule({
    name  = "nautilus-preview-floating",
    match = { class = "^org\\.gnome\\.NautilusPreviewer$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class = "^$", title = "^$",
        xwayland = true, float = true, fullscreen = false, pin = false,
    },
    no_focus = true,
})

----------------------------
---- hyprmoncfg LAYOUTS ----
----------------------------

-- Layouts saved from the hyprmoncfg TUI (Super+Shift+M) are applied from a
-- file it owns, ~/.config/hypr/hyprmoncfg-monitors.lua. It must load LAST so
-- the saved layout wins over the MONITORS defaults above. This is the exact
-- guarded line hyprmoncfg would otherwise append itself (`hyprmoncfg doctor`
-- checks it) — keeping it here stops the tool from editing this file.
do local path = os.getenv("HOME") .. "/.config/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end
