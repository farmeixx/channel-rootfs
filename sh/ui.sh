#!/usr/bin/env bash
# Shared build-log presentation: phase banners, step subtitles, artifact
# lists and result banners. Presentation only: these helpers print text and
# never change build logic, generated files or exit codes. Bar widths stay
# fixed so phases and results separate visually from raw tool output.

#------------------------------------------------------------------#

UI_BAR='================================='
UI_END_BAR='======================='
UI_FAIL_BAR='================'

# Letter-space words for banner readability: "BUILD ROOTFS" prints as
# "B U I L D   R O O T F S" with wider gaps between words.
ui_spaced() {
  printf '%s\n' " $(printf '%s' "$*" | sed -E 's/(.)/\1 /g;s/ $//')"
}

# Phase banner, e.g.: ui_banner "BUILDING" "ROOTFS" "UBUNTU".
ui_banner() {
  printf '%s\n' "$UI_BAR"
  ui_spaced "$@"
  printf '%s\n' "$UI_BAR"
}

# One-line step subtitle beneath a phase banner.
ui_step() {
  printf '%s\n' "$*"
}

# Success summary line, e.g.: ui_saved "boot.img" "out/kernel/images/boot.img".
ui_saved() {
  printf '%s\n' "  $1 saved in $2"
}

# Final success banner; callers list ui_saved lines below it.
ui_success() {
  printf '%s\n' "$UI_END_BAR"
  ui_spaced "BUILD SUCCESSFUL"
  printf '%s\n' "$UI_END_BAR"
}

# Final failure banner. Printed to stderr so failures stand out.
ui_failed() {
  printf '%s\n' "$UI_FAIL_BAR" >&2
  ui_spaced "BUILD FAILED" >&2
  printf '%s\n' "$UI_FAIL_BAR" >&2
}
