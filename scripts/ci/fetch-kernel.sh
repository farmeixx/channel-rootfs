#!/usr/bin/env bash
# GitHub-only helper: retrieve an explicitly compiled checkpoint.
# Never build a kernel, guess a substitute for an explicit run, or silently fall back.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
[ "${GITHUB_ACTIONS:-}" = true ] || { echo 'ERROR: CI kernel retrieval is for GitHub Actions. Local builds use out/kernel/checkpoint.' >&2; exit 1; }
[ -n "${GITHUB_REPOSITORY:-}" ] || { echo 'ERROR: GITHUB_REPOSITORY missing.' >&2; exit 1; }
command -v gh >/dev/null || { echo 'ERROR: GitHub CLI missing.' >&2; exit 1; }
[ -n "${GH_TOKEN:-}" ] || { echo 'ERROR: GH_TOKEN missing.' >&2; exit 1; }
requested="${KERNEL_RUN_ID:-}"
if [ -n "$requested" ] && ! [[ "$requested" =~ ^[0-9]+$ ]]; then
  echo 'ERROR: kernel_run_id must be a numeric GitHub Actions run ID.' >&2; exit 1
fi
artifact_for_run() {
  gh api "repos/$GITHUB_REPOSITORY/actions/runs/$1/artifacts?per_page=100" \
    --jq '[.artifacts[] | select(.expired == false and (.name | startswith("channel-mainline-kernel-"))) | .name] | first // empty'
}
selected_run=''
selected_artifact=''
if [ -n "$requested" ]; then
  conclusion="$(gh run view "$requested" --repo "$GITHUB_REPOSITORY" --json conclusion --jq .conclusion)"
  [ "$conclusion" = success ] || { echo "ERROR: Kernel run $requested did not succeed." >&2; exit 1; }
  selected_artifact="$(artifact_for_run "$requested")"
  [ -n "$selected_artifact" ] || { echo "ERROR: Kernel checkpoint for run $requested is missing/expired." >&2; exit 1; }
  selected_run="$requested"
else
  # These are successful mainline runs only; never select a rootfs workflow.
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    artifact="$(artifact_for_run "$candidate")"
    if [ -n "$artifact" ]; then
      selected_run="$candidate"
      selected_artifact="$artifact"
      break
    fi
  done < <(gh run list --repo "$GITHUB_REPOSITORY" --workflow mainline.yml \
      --branch main --status success --limit 50 --json databaseId --jq '.[].databaseId')
  [ -n "$selected_run" ] || { echo 'ERROR: No live successful kernel checkpoint exists. Run Build mainline kernel first.' >&2; exit 1; }
fi
checkpoint="$ROOT/out/kernel/checkpoint"
rm -rf "$checkpoint"
mkdir -p "$checkpoint"
echo "Downloading kernel checkpoint $selected_artifact (run $selected_run)"
gh run download "$selected_run" --repo "$GITHUB_REPOSITORY" \
  --name "$selected_artifact" --dir "$checkpoint"
KERNEL_CHECKPOINT_DIR="$checkpoint" bash "$ROOT/scripts/kernel/validate.sh" --basic
printf 'Kernel run: %s\nArtifact: %s\n' "$selected_run" "$selected_artifact"
