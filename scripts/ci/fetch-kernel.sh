#!/usr/bin/env bash
# Reuse an already successful mainline.yml checkpoint (never dispatch a build).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[ "${GITHUB_ACTIONS:-}" = true ] || { echo 'ERROR: Local builds reuse out/kernel/checkpoint; no CI download needed.' >&2; exit 1; }
[ -n "${GITHUB_REPOSITORY:-}" ] || { echo 'ERROR: GITHUB_REPOSITORY missing.' >&2; exit 1; }
command -v gh >/dev/null || { echo 'ERROR: GitHub CLI missing.' >&2; exit 1; }
[ -n "${GH_TOKEN:-}" ] || { echo 'ERROR: GH_TOKEN missing.' >&2; exit 1; }
requested="${KERNEL_RUN_ID:-}"
if [ -n "$requested" ] && ! [[ "$requested" =~ ^[0-9]+$ ]]; then
  echo 'ERROR: kernel_run_id must be a numeric GitHub Actions run ID.' >&2; exit 1
fi
is_mainline_run() {
  local run="$1"
  gh api "repos/$GITHUB_REPOSITORY/actions/runs/$run" \
    --jq 'select(.conclusion == "success" and .head_branch == "main" and (.path | startswith(".github/workflows/mainline.yml"))) | .id' | grep -Fxq "$run"
}
artifact_for_run() {
  gh api "repos/$GITHUB_REPOSITORY/actions/runs/$1/artifacts?per_page=100" \
    --jq '[.artifacts[] | select(.expired == false and (.name | startswith("channel-mainline-kernel-"))) | .name] | first // empty'
}
selected_run=''
selected_artifact=''
if [ -n "$requested" ]; then
  is_mainline_run "$requested" || { echo "ERROR: $requested must be a successful mainline.yml run on main." >&2; exit 1; }
  selected_artifact="$(artifact_for_run "$requested")"
  [ -n "$selected_artifact" ] || { echo "ERROR: Kernel artifact for run $requested is missing or expired." >&2; exit 1; }
  selected_run="$requested"
else
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    is_mainline_run "$candidate" || continue
    artifact="$(artifact_for_run "$candidate")"
    if [ -n "$artifact" ]; then
      selected_run="$candidate"
      selected_artifact="$artifact"
      break
    fi
  done < <(gh run list --repo "$GITHUB_REPOSITORY" --workflow mainline.yml \
      --branch main --status success --limit 50 --json databaseId --jq '.[].databaseId')
  [ -n "$selected_run" ] || { echo 'ERROR: No usable mainline kernel checkpoint. Run the dedicated mainline workflow once.' >&2; exit 1; }
fi
checkpoint="$ROOT/out/kernel/checkpoint"
rm -rf "$checkpoint"
mkdir -p "$checkpoint"
echo "Reusing kernel checkpoint $selected_artifact (run $selected_run)"
gh run download "$selected_run" --repo "$GITHUB_REPOSITORY" --name "$selected_artifact" --dir "$checkpoint"
KERNEL_CHECKPOINT_DIR="$checkpoint" bash "$ROOT/scripts/kernel/validate.sh" --basic
printf 'Kernel run: %s\nArtifact: %s\n' "$selected_run" "$selected_artifact"
