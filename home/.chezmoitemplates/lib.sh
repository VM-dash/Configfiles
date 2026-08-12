#!/usr/bin/env bash
# Shared preamble for every .chezmoiscripts/ script.
#
# Each script pulls this in with a Go-template `template` action naming
# "lib.sh" and passing the dot. Do NOT write that action literally in this
# file: chezmoi would execute it while rendering lib.sh itself and recurse
# until it hits the maximum template depth.
set -euo pipefail

# ------------------------------------------------------------------ output --
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
	_C_RESET=$'\033[0m'; _C_BLUE=$'\033[34m'; _C_GREEN=$'\033[32m'
	_C_YELLOW=$'\033[33m'; _C_RED=$'\033[31m'; _C_DIM=$'\033[2m'
else
	_C_RESET=''; _C_BLUE=''; _C_GREEN=''; _C_YELLOW=''; _C_RED=''; _C_DIM=''
fi

step() { printf '\n%s==>%s %s\n' "$_C_BLUE"   "$_C_RESET" "$*"; }
info() { printf '%s  · %s%s\n'   "$_C_DIM"    "$*" "$_C_RESET"; }
ok()   { printf '%s  ok%s %s\n'  "$_C_GREEN"  "$_C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n'  "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
die()  { printf '%sfail%s %s\n'  "$_C_RED"    "$_C_RESET" "$*" >&2; exit 1; }

# Run something that is allowed to fail without aborting the whole apply.
# Every optional/third-party step goes through this.
try() { "$@" || warn "optional step failed (continuing): $*"; }

has() { command -v "$1" >/dev/null 2>&1; }

# A tool counts as available if it is on PATH or resolvable as a mise shim,
# since most of the dev toolchain is installed by mise rather than the distro.
have_tool() { has "$1" || mise which "$1" >/dev/null 2>&1; }

# ...and run it whichever way it exists.
run_tool() {
	local t="$1"; shift
	if has "$t"; then "$t" "$@"; else mise exec -- "$t" "$@"; fi
}

# Resolve the newest release asset matching a regex. Used for the upstreams
# that publish GitHub releases instead of a package repo.
gh_latest_asset() {
	has jq || { warn "jq missing — cannot resolve the $1 release"; return 1; }
	curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
		| jq -r --arg p "$2" \
			'[.assets[] | select(.name | test($p))][0].browser_download_url // empty'
}

aur_helper() {
	for h in paru yay; do
		if has "$h"; then printf '%s' "$h"; return 0; fi
	done
	return 1
}

# ------------------------------------------------------------ environment ---
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CONFIG_HOME XDG_DATA_HOME

# ------------------------------------------------------------------ distro --
if [ -r /etc/os-release ]; then
	# shellcheck disable=SC1091
	. /etc/os-release
	DISTRO_ID="${ID:-unknown}"
	DISTRO_LIKE="${ID_LIKE:-}"
else
	DISTRO_ID="unknown"; DISTRO_LIKE=""
fi

case "$DISTRO_ID $DISTRO_LIKE" in
	*fedora*|*rhel*|*centos*) DISTRO_FAMILY="fedora" ;;
	*arch*)                   DISTRO_FAMILY="arch" ;;
	*debian*|*ubuntu*)        DISTRO_FAMILY="debian" ;;
	*)                        DISTRO_FAMILY="unknown" ;;
esac

is_fedora() { [ "$DISTRO_FAMILY" = "fedora" ]; }
is_arch()   { [ "$DISTRO_FAMILY" = "arch" ]; }

# ----------------------------------------------------------------- desktop --
# The desktop is DECLARED at init (see .chezmoi.toml.tmpl), not sniffed here.
# Runtime sniffing is unreliable in exactly the case this repo exists for: the
# first `chezmoi init --apply` may run from a TTY or over SSH, where
# XDG_CURRENT_DESKTOP is empty and gnome-shell is not installed yet — this very
# run is what installs it. Detection only supplies the prompt's default.
TARGET_DESKTOP="{{ .desktop }}"

is_gnome()    { [ "$TARGET_DESKTOP" = "gnome" ]; }
is_hyprland() { [ "$TARGET_DESKTOP" = "hyprland" ]; }

# True inside a container / chroot / CI, where systemd, Flatpak and GNOME
# steps cannot meaningfully run. Those steps self-skip instead of failing.
is_container() {
	[ -f /.dockerenv ] || [ -f /run/.containerenv ] && return 0
	grep -qaE '(docker|containerd|podman|lxc)' /proc/1/cgroup 2>/dev/null && return 0
	[ "${container:-}" != "" ] && return 0
	return 1
}

has_systemd() { [ -d /run/systemd/system ]; }

# ---------------------------------------------------------------- privilege --
# Non-interactive sudo. bootstrap.sh primes the credential cache; if this is a
# bare `chezmoi apply` the user is prompted once by the first caller.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
	if has sudo; then SUDO="sudo"; else
		warn "sudo not available — privileged steps will be skipped"
	fi
fi

# Can we run privileged commands at all?
can_root() { [ "$(id -u)" -eq 0 ] || [ -n "$SUDO" ]; }
