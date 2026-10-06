#!/bin/sh
# Install the Herdr plugins that herdr/.config/herdr/config.toml expects.
#
# Herdr keeps its plugin registry outside this repository, so stowing the
# config alone leaves the sidebar blocks, the tab-bar command and the ports
# keybinding pointing at plugins that are not there. Run this once per machine
# after `stow herdr`.
#
# Prerequisites are reported, not installed: use whatever package manager the
# machine has (brew, apt, mise, ...).
#
#   sh herdr/install-plugins.sh          install what is missing
#   sh herdr/install-plugins.sh --check  only report prerequisites and exit
set -eu
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# plugin id, GitHub repo, what it needs on PATH
PLUGINS='
numbered.ports      Numbered-com/herdr-ports   jq
herdr.auto-title    kryptamine/herdr-auto-title go
hhdebb.herdr-radar  hhdebb/herdr-radar         node
'
NODE_MIN=18

missing=''
need() {
  # $1 = binary, $2 = why
  if command -v "$1" >/dev/null 2>&1; then
    printf '  ok       %-6s %s\n' "$1" "$(command -v "$1")"
  else
    printf '  MISSING  %-6s %s\n' "$1" "$2"
    missing="$missing $1"
  fi
}

echo "prerequisites:"
need herdr "Herdr itself (https://herdr.dev), 0.9.0 or newer"
need git   "used by 'herdr plugin install'"
need jq    "numbered.ports reads Herdr's JSON with it"
need go    "herdr.auto-title is built from source with 'go build'"
need node  "hhdebb.herdr-radar runs on Node $NODE_MIN or newer"

if command -v node >/dev/null 2>&1; then
  major=$(node -p 'process.versions.node.split(".")[0]')
  if [ "$major" -lt "$NODE_MIN" ]; then
    printf '  MISSING  node   is v%s; hhdebb.herdr-radar needs %s or newer\n' "$(node -v)" "$NODE_MIN"
    missing="$missing node>=$NODE_MIN"
  fi
fi

if [ -n "$missing" ]; then
  echo
  echo "install these first, then rerun:$missing"
  exit 1
fi

[ "${1:-}" = "--check" ] && exit 0

if ! herdr status >/dev/null 2>&1; then
  echo
  echo "Herdr's server is not running; start 'herdr' in another window first."
  echo "Plugin installs talk to the server, and herdr-radar's daemon attaches to it."
  exit 1
fi

# `herdr plugin list` prints one "- <id> (<name>) ..." line per plugin.
installed=$(herdr plugin list 2>/dev/null | sed -n 's/^- \([^ ]*\) .*/\1/p')

echo
echo "plugins:"
echo "$PLUGINS" | while read -r id repo _; do
  [ -z "$id" ] && continue
  case "
$installed
" in
    *"
$id
"*) printf '  ok       %s\n' "$id" ;;
    *)
      printf '  install  %s (%s)\n' "$id" "$repo"
      herdr plugin install "$repo"
      ;;
  esac
done

echo
# These commands run in Herdr's server environment, which may lack the PATH
# set by the user's shell. Herdr reloads manifests when actions are invoked.
registry="${XDG_CONFIG_HOME:-$HOME/.config}/herdr/plugins.json"
node "$script_dir/configure-plugin-runtime.cjs" "$registry"

# The radar daemon normally starts with Herdr's server; after a fresh install
# it has to be started by hand once. Idempotent: a running daemon is left alone.
herdr plugin action invoke hhdebb.herdr-radar.state-start >/dev/null
# Ports normally starts only on pane.created, so start it for existing panes.
herdr plugin action invoke numbered.ports.ensure-watch >/dev/null
herdr server reload-config >/dev/null
echo "done. New Ghostty windows pick up the icon font; if the agent logos still"
echo "render as boxes, quit and reopen Ghostty."
