#!/usr/bin/env bash
# Cloud bootstrap: install the plugin catalog this repo enables.
#
# Two callers run this script:
#   1. The account environment's setup script, after clone and BEFORE the
#      session process launches (with CLAUDE_CODE_REMOTE=true). Claude Code
#      builds its plugin registry at process start and never re-reads it, so
#      this pre-launch call is the only path that gets plugins loaded at turn
#      one of a cloud session.
#   2. The SessionStart hook (startup|resume) in .claude/settings.json, as
#      per-session drift repair — the environment cache can be ~7 days stale.
#      Plugins the hook installs go live at the next resume, not in the
#      session that ran it.
#
# Declaring a marketplace is gated on workspace trust and cloud sessions arrive
# untrusted, so the declaration alone can load nothing there. Hooks run untrusted.
# Idempotent and best effort: a failed plugin costs its skills, not the session.
#
# Kept to Bash 3.2 features (no mapfile, no associative arrays) so it also runs
# under the stock /bin/bash on macOS, where a bash-4-only builtin would abort the
# whole hook under `set -e` and leave a local session with no plugins at all.
set -euo pipefail

repo_root="${CLAUDE_PROJECT_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
cd -- "$repo_root"

command -v claude >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

settings=".claude/settings.json"
[ -f "$settings" ] || exit 0

# Every marketplace and plugin below is read live from the declaration, never
# duplicated here: a second copy of the marketplace name or source repo would be
# free to drift from settings.json the moment either one is renamed or repointed.
marketplaces=$(jq -r '.extraKnownMarketplaces // {} | keys[]' "$settings" 2>/dev/null || true)
if [ -z "$marketplaces" ]; then
	echo "cloud-bootstrap: no marketplace declared in $settings" >&2
	exit 0
fi

known=$(claude plugin marketplace list --json 2>/dev/null || echo '[]')
while IFS=$'\t' read -r name repo; do
	if [ -z "$name" ] || [ -z "$repo" ]; then continue; fi
	if printf '%s' "$known" | jq -e --arg n "$name" 'any(.[]; .name == $n)' >/dev/null 2>&1; then
		continue
	fi
	claude plugin marketplace add "$repo" --scope user >/dev/null 2>&1 ||
		echo "cloud-bootstrap: could not add the $name marketplace" >&2
done < <(
	jq -r '.extraKnownMarketplaces // {} | to_entries[]
           | select(.value.source.repo != null)
           | "\(.key)\t\(.value.source.repo)"' "$settings" 2>/dev/null
)

# Enabled plugins whose "@<marketplace>" suffix names a marketplace this repo
# declares. Plugins from anywhere else are somebody else's to install.
wanted=()
while IFS= read -r id; do
	[ -n "$id" ] && wanted+=("$id")
done < <(
	jq -r '(.extraKnownMarketplaces // {} | keys) as $mk
           | .enabledPlugins // {} | to_entries[]
           | select(.value == true and ((.key | split("@") | last) as $m | $mk | index($m)))
           | .key' "$settings" 2>/dev/null
)

have=()
while IFS= read -r id; do
	[ -n "$id" ] && have+=("$id")
done < <(claude plugin list --json 2>/dev/null | jq -r '.[].id' 2>/dev/null)

installed=0
for id in ${wanted[@]+"${wanted[@]}"}; do
	case " ${have[*]+${have[*]}} " in
	*" $id "*) continue ;;
	esac
	if claude plugin install "$id" --scope user -y >/dev/null 2>&1; then
		installed=$((installed + 1))
	else
		echo "cloud-bootstrap: install failed: $id" >&2
	fi
done
echo "cloud-bootstrap: ${#wanted[@]} enabled, $installed newly installed"
