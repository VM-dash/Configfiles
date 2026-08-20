# Configfiles

Dotfiles and full machine provisioning for **Fedora Workstation 44 + GNOME**,
built to move to **Arch / HyDE / Hyprland** later without rewriting anything.

One command on a fresh install:

```sh
curl -fsSL https://raw.githubusercontent.com/VM-dash/Configfiles/main/bootstrap.sh | bash
```

That installs [chezmoi](https://chezmoi.io) and hands off. Everything else —
repos, packages, dev toolchain, dotfiles, themes — is driven by chezmoi, so
re-provisioning any machine later is just `chezmoi apply`.

---

## What you get

| | |
|---|---|
| **Shell** | zsh (login shell) + Starship, XDG layout via `ZDOTDIR` |
| **Terminal** | Ghostty |
| **Editor** | Neovim + LazyVim · VS Code · Zed · druk |
| **Multiplexer** | tmux + TPM, tmux-yank, tmux-fingers · herdr |
| **Dev toolchain** | mise: .NET 9, Node 22, neovim, tmux, herdr, rclone, starship, lazygit, fzf, ripgrep, fd, bat, eza, zoxide, opencode, druk |
| **Containers** | Docker CE (rootless group configured) |
| **Browsers** | Brave (native, policy-managed) · Zen |
| **Apps** | DBeaver · Bruno · Obsidian · Inkscape · LibreOffice |
| **AI** | Claude Code CLI (official RPM repo) + Claude Desktop (best-effort) |
| **GNOME** | Copyous clipboard manager, curated `gsettings` |
| **Themes** | All 4 Catppuccin flavours + all 3 Rose Pine variants, switched live |

---

## The `theme` command

The point of this repo. One command re-themes the entire environment at once
and reloads everything that can reload without a restart.

```sh
theme                      # interactive picker (fzf)
theme catppuccin-mocha     # switch directly
theme list                 # show all 7 themes
theme next                 # cycle
theme toggle               # flip dark <-> light, same family
theme reload               # re-apply after editing a template
```

| Theme | |
|---|---|
| `catppuccin-mocha` | dark |
| `catppuccin-macchiato` | dark |
| `catppuccin-frappe` | dark |
| `catppuccin-latte` | light |
| `rose-pine` | dark |
| `rose-pine-moon` | dark |
| `rose-pine-dawn` | light |

It drives Ghostty, tmux, Neovim, druk, VS Code, Zed, Starship, bat, fzf, delta
and (later) Hyprland. Ghostty reloads over SIGUSR2, tmux re-sources its config,
and every running Neovim is poked over its RPC socket — so open windows change
colour without being restarted. druk has no RPC: it picks up the new theme on
the next launch. VS Code follows the GNOME light/dark preference
(`autoDetectColorScheme`): `theme` writes the chosen theme into the preferred
dark or light slot and flips GNOME to that polarity, which is what makes the
switch land live. VS Code *icons* deliberately do not follow the theme family
— `kd-vscode-icon-sync.service` keeps them on catppuccin mocha/latte tracking
GNOME dark/light only. Already-open shells need `exec zsh` to pick up the new
`BAT_THEME` / `FZF_DEFAULT_OPTS`.

Also bound to `<leader>ut` in Neovim and `SUPER+SHIFT+T` in the Hyprland stub.

### Adding a theme

1. Add a block to `home/.chezmoidata/themes.yaml` (copy an existing one).
2. Add a matching `[palettes.<name>]` table to
   `home/dot_config/theme/starship.template.toml`.
3. Add the colorscheme plugin in `home/dot_config/nvim/lua/plugins/colorscheme.lua`.
4. Set `druk:` to a theme id from the catppuccin / rose-pine druk extensions
   (seeded into `~/.config/druk/extensions/` by `.chezmoiexternal.toml`).
5. Set `vscode:` / `zed:` to the workbench theme names
   (`Catppuccin.catppuccin-vsc`, `mvllow.rose-pine`).
6. `chezmoi apply && theme <name>`

---

## Repo layout

```
.chezmoiroot                     -> "home"  (keeps this README out of $HOME)
bootstrap.sh                     the curl target
home/                            chezmoi source directory
├── .chezmoi.toml.tmpl           first-run prompts (name, email, theme, gui, docker)
├── .chezmoiignore               templated GNOME <-> Hyprland split
├── .chezmoiexternal.toml        upstream clones + druk extension files
├── .chezmoidata/
│   ├── packages.yaml            EVERYTHING that gets installed
│   └── themes.yaml              the theme catalog
├── .chezmoitemplates/lib.sh     shared preamble for install scripts
├── .chezmoiscripts/             ordered install scripts
├── dot_zshenv                   sets ZDOTDIR
├── dot_config/                  -> ~/.config
└── dot_local/bin/executable_theme
```

### Everyday use

```sh
chezmoi apply          # re-provision / re-apply dotfiles
chezmoi update         # git pull + apply
chezmoi edit --apply ~/.zshrc
chezmoi diff           # what would change
chezmoi cd             # drop into the source repo
```

Adding a package is a one-line edit to `home/.chezmoidata/packages.yaml`.
The install scripts embed a sha256 of that file, so the next `chezmoi apply`
re-runs them automatically.

---

## Fonts

`JetBrainsMono Nerd Font` everywhere, defined **once** in
`home/.chezmoidata/fonts.yaml`. Change the family there and every application
follows on the next `chezmoi apply`.

Applications with a real font setting are configured directly:

| App | File |
|---|---|
| Ghostty | `dot_config/ghostty/config.tmpl` |
| VS Code | `dot_config/Code/User/settings.json.tmpl` (editor, terminal, debug console) |
| Zed | `dot_config/zed/settings.json.tmpl` (buffer, UI, terminal) |
| Neovim | `dot_config/nvim/lua/config/options.lua.tmpl` (`guifont`, GUI clients only) |
| GNOME | `monospace-font-name` via gsettings |

Everything else is covered by **`dot_config/fontconfig/fonts.conf.tmpl`**, which
aliases the generic `monospace` family to the Nerd Font. That is what gets the
font into DBeaver, Bruno and Obsidian without per-app configuration — they all
ask fontconfig for `monospace`. It also remaps apps that hardcode
`JetBrains Mono`, `Menlo` or `Consolas`, and appends the Nerd Font as a weak
fallback to every monospace request so glyphs resolve even when an app insists
on its own family.

Flatpaks are covered too: Flatpak bind-mounts the host's
`~/.local/share/fonts` and fontconfig into the sandbox read-only.

`run_onchange_after_55-fonts.sh` verifies after install that the family names in
`fonts.yaml` actually resolve in `fc-list`, and warns loudly if not — a silent
name mismatch is what produces tofu boxes instead of icons.

Obsidian additionally has a per-vault **Appearance → Monospace font** setting;
it defaults to `monospace`, so the fontconfig alias handles it.

---

## Design decisions worth knowing

**Flatpak-first, with four deliberate exceptions.** Self-contained GUI apps are
Flatpaks so the app set is identical on Fedora and Arch. **Ghostty** has no
Flatpak at all (and a sandboxed terminal cannot host a login shell), while
**VS Code** and **Zed** are installed natively so they can see mise's .NET SDK,
the host Docker socket and your shell. Their Flathub builds are also unverified
community repackages. **Brave** is native because the Flatpak sandbox cannot
read `/etc/brave/policies/managed` ([flatpak#4709](https://github.com/flatpak/flatpak/issues/4709)),
which is the only declarative way to force-install extensions and lock
settings; native also fixes native messaging for password-manager extensions
and lets Brave use gnome-keyring.

**mise owns the dev toolchain**, including neovim, tmux and druk. That is what
makes the eventual Arch/HyDE move cheap: identical tool versions, no distro lag.

**Local overrides never go in git.** Each config sources an untracked sibling:
`~/.config/zsh/local.zsh`, `~/.config/tmux/local.conf`,
`~/.config/ghostty/local.conf`, `~/.config/git/local`.

**Generated files are not tracked.** `theme` writes `~/.config/starship.toml`,
`ghostty/theme.conf`, `tmux/theme.conf`, `druk/config.json` and
`theme/current.sh`. They are in `.chezmoiignore` so chezmoi and the switcher
never fight. Edit `home/dot_config/theme/starship.template.toml` and
`home/dot_config/druk/config.template.json`, **not** the generated files.

---

## Brave profile migration

The `KD` profile lives in the `Default` folder on disk. Migration splits into
three buckets, because not everything can cross operating systems.

**Declarative, in this repo.** `home/.chezmoidata/brave.yaml` defines the
extension list and browser settings; `run_onchange_after_47-brave.sh` renders
them to `/etc/brave/policies/managed/configfiles.json`. Verify at
`brave://policy` after first launch. Note the trade-off: force-installed
extensions **cannot be removed from within the browser** — drop them from
`brave.yaml` and re-apply instead. Chromium has no "install once, then let the
user manage it" policy.

**Bookmarks, seeded once.** Copied into the profile only if it has no
`Bookmarks` file yet, so anything you add on Linux is never clobbered by a
later apply. Brave must not be running at the time or it will overwrite them.

**Impossible to carry.** `Login Data`, `Cookies`, `Web Data` and
`Local Storage` are encrypted with a key in `Local State` sealed by **Windows
DPAPI** and bound to that Windows account. On Linux Brave uses
gnome-keyring/kwallet instead, so these are cryptographically undecryptable —
not a missing feature. Copying them yields a corrupt profile. Use **Brave Sync**
(`brave://settings/braveSync`) for passwords, history and open tabs; keep the
24-word seed in a password manager, never in this repo.

To re-export from Windows:

```powershell
.\scripts\export-brave.ps1 -Encrypt
```

It prints the bookmark host list before you commit, so an internal URL cannot
slip into a public repo unnoticed.

---

## Known rough edges

These are upstream limitations, verified rather than assumed. Each one is
handled defensively so it can never fail a provision.

**Claude Desktop has no Fedora build.** Anthropic's official Linux Desktop beta
is Debian-only — their docs explicitly exclude Fedora/RHEL — and there is no
Flatpak. This repo installs the unofficial RPM from
[`aaddrick/claude-desktop-debian`](https://github.com/aaddrick/claude-desktop-debian),
which repackages Anthropic's own official build (as `claude-desktop-unofficial`,
so it will not collide when a real package ships). If that fails, the run
continues. The **CLI is official and unaffected** — it comes from Anthropic's
signed RPM repo.

**Ghostty is not packaged by Fedora.** It is in no Fedora release, and the
widely-cited `pgdev/ghostty` COPR no longer exists. This repo uses
`scottames/ghostty`, which does have Fedora 44 builds. On Arch it is plain
`extra/ghostty`.

**Rose Pine's Starship palette is hand-made.** Catppuccin publishes palette
snippets; Rose Pine publishes whole configs instead. The three `[palettes.rose_pine*]`
tables in `starship.template.toml` were extracted by hand from the official
colour spec and aliased onto Catppuccin's key names so one set of module styles
serves every theme. Do not expect them to match a file in `rose-pine/starship`.

**The two tmux ports disagree about TPM.** `catppuccin/tmux` recommends *against*
TPM (plugin name conflicts); `rose-pine/tmux` expects it. Both are cloned to
fixed paths by `.chezmoiexternal.toml` and only the active one is sourced from
the generated `theme.conf`. TPM still manages yank and fingers.

**GNOME extensions need a logout.** Fedora 44 is Wayland-only, so the shell
cannot be restarted in place. Same for the zsh login shell and the docker group.

---

## After the first run

Log out and back in, then:

```sh
echo $SHELL                 # /usr/bin/zsh
mise ls                     # the full toolchain
dotnet --list-sdks          # 9.x
docker run hello-world      # no sudo
theme                       # pick a theme, watch everything change
```

Neovim: `nvim`, then `:checkhealth`. LazyVim language extras (C#, Docker, JSON,
TypeScript…) are opt-in — run `:LazyExtras` and enable what you want; the
selection is saved to `~/.config/nvim/lazyvim.json`.

### KD-Obsidian → OneDrive

The vault at `~/Documents/kardham/doc/KD-Obsidian` bisyncs to Kardham OneDrive
via rclone. Tokens live in `~/.config/rclone/obsidian.conf` (untracked).

```sh
rclone config --config ~/.config/rclone/obsidian.conf
kd-obsidian-sync --resync
systemctl --user enable --now kd-obsidian-sync.timer
```

On Windows, open `OneDrive - KARDHAM/KD-Obsidian` as the vault. Plugins
(Hearth, Iconize, settings) sync; `workspace.json` / cache / `.trash` do not.

---

## Testing changes without a Fedora machine

```sh
chezmoi execute-template < home/.chezmoi.toml.tmpl   # render the prompt file
chezmoi apply --dry-run --verbose                    # what would happen
bash -n home/.chezmoiscripts/*.sh.tmpl               # syntax only (after render)
```

Full end-to-end, in a throwaway container:

```sh
podman run -it --rm fedora:44 bash
# create a non-root sudo user, then run the curl one-liner
```

Flatpak, GNOME and systemd steps detect the container and skip themselves.
