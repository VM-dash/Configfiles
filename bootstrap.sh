#!/usr/bin/env bash
#
# Configfiles bootstrap — turns a bare Fedora Workstation (or Arch) install into
# a fully provisioned environment.
#
#   curl -fsSL https://raw.githubusercontent.com/VM-dash/Configfiles/main/bootstrap.sh | bash
#
# This script deliberately does almost nothing: it installs chezmoi and hands
# off. All real provisioning lives in home/.chezmoiscripts/ so that a plain
# `chezmoi apply` reprovisions any machine without re-running this file.

set -euo pipefail

REPO="${CONFIGFILES_REPO:-VM-dash/Configfiles}"
BIN_DIR="$HOME/.local/bin"

# ---------------------------------------------------------------- output ----
if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
	C_RESET=$'\033[0m'; C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'
	C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BOLD=$'\033[1m'
else
	C_RESET=''; C_BLUE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_BOLD=''
fi

info() { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%sfail%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }

# ------------------------------------------------------------ preflight -----
[ "$(id -u)" -ne 0 ] || die "Do not run this as root. Run it as your normal user; it will call sudo when needed."

command -v sudo >/dev/null 2>&1 || die "sudo is required but not installed."

if [ -r /etc/os-release ]; then
	# shellcheck disable=SC1091
	. /etc/os-release
	DISTRO_ID="${ID:-unknown}"
	DISTRO_LIKE="${ID_LIKE:-}"
else
	DISTRO_ID="unknown"; DISTRO_LIKE=""
fi

printf '\n%s  Configfiles bootstrap%s\n' "$C_BOLD" "$C_RESET"
printf '  repo   : %s\n' "$REPO"
printf '  distro : %s %s\n' "$DISTRO_ID" "${VERSION_ID:-}"
printf '  user   : %s\n\n' "$(id -un)"

# Keep sudo warm so the long provisioning run does not stall on a password
# prompt halfway through an unattended install.
info "Requesting sudo (kept alive for the duration of this run)"
sudo -v || die "sudo authentication failed."
while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# ----------------------------------------------- minimal prerequisites ------
# Only what chezmoi itself needs. Everything else is installed by the chezmoi
# scripts, where it can be data-driven and re-run on change.
PREREQS="git curl unzip"

install_prereqs() {
	local missing=""
	for pkg in $PREREQS; do
		command -v "$pkg" >/dev/null 2>&1 || missing="$missing $pkg"
	done
	# `git` is the binary name for the git package on every distro we target,
	# so a command check is a valid proxy here.
	if [ -z "${missing# }" ]; then
		ok "prerequisites already present ($PREREQS)"
		return
	fi

	info "Installing prerequisites:${missing}"
	case "$DISTRO_ID:$DISTRO_LIKE" in
		fedora*|*:*fedora*|rhel*|centos*)
			sudo dnf install -y $missing ;;
		arch*|*:*arch*|cachyos*|endeavouros*)
			sudo pacman -Sy --needed --noconfirm $missing ;;
		debian*|ubuntu*|*:*debian*)
			sudo apt-get update -qq && sudo apt-get install -y $missing ;;
		*)
			die "Unsupported distro '$DISTRO_ID'. Install these manually and re-run:$missing" ;;
	esac
	ok "prerequisites installed"
}
install_prereqs

# ------------------------------------------------------------- chezmoi ------
mkdir -p "$BIN_DIR"
case ":$PATH:" in
	*":$BIN_DIR:"*) ;;
	*) PATH="$BIN_DIR:$PATH"; export PATH ;;
esac

if command -v chezmoi >/dev/null 2>&1; then
	ok "chezmoi already installed ($(chezmoi --version | head -n1))"
else
	info "Installing chezmoi to $BIN_DIR"
	# /lb == install to ~/.local/bin
	sh -c "$(curl -fsLS https://get.chezmoi.io/lb)" || die "chezmoi install failed."
	ok "chezmoi installed"
fi

# --------------------------------------------------------------- handoff ----
# NOTE: the repo argument must be "user/repo". A bare username would make
# chezmoi guess "VM-dash/dotfiles", which does not exist.
info "Running chezmoi init --apply $REPO"
printf '\n'

if [ -d "$(chezmoi source-path 2>/dev/null || echo /nonexistent)" ]; then
	warn "An existing chezmoi source directory was found — applying instead of re-initialising."
	exec chezmoi apply --verbose
else
	exec chezmoi init --apply --verbose "$REPO"
fi
