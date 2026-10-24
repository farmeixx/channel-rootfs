#!/usr/bin/env bash
# Shared build-log presentation: phase banners, step subtitles, artifact
# lists and result banners. Presentation only: these helpers print text and
# never change build logic, generated files or exit codes. Bars adapt to the
# text width so the '=' frame always covers the whole banner line.

#------------------------------------------------------------------#

# Letter-space words: "BUILD ROOTFS" -> " B U I L D   R O O T F S".
ui_spaced_text() {
  printf '%s' " $(printf '%s' "$*" | sed -E 's/(.)/\1 /g;s/ $//')"
}

# Letter-space words for banner readability and print one line.
ui_spaced() {
  printf '%s\n' "$(ui_spaced_text "$@")"
}

# Bar of '=' that completes the text: spaced-text width plus one margin
# column on each side, so the frame never ends before the banner text.
ui_bar_for() {
  local s
  s="$(ui_spaced_text "$@")"
  printf '%s\n' "$(printf '%*s' $(( ${#s} + 2 )) '' | tr ' ' '=')"
}

# Phase banner, e.g.: ui_banner "BUILDING" "ROOTFS" "UBUNTU".
ui_banner() {
  ui_bar_for "$@"
  ui_spaced "$@"
  ui_bar_for "$@"
}

# One-line step subtitle beneath a phase banner.
ui_step() {
  printf '%s\n' "$*"
}

# Success summary line, e.g.: ui_saved "boot.img" "out/kernel/images/boot.img".
ui_saved() {
  printf '%s\n' "$1 saved in $2"
}

# Final success banner; callers list ui_saved lines below it.
ui_success() {
  ui_bar_for "BUILD SUCCESSFUL"
  ui_spaced "BUILD SUCCESSFUL"
  ui_bar_for "BUILD SUCCESSFUL"
}

# Final failure banner. Printed to stderr so failures stand out.
ui_failed() {
  ui_bar_for "BUILD FAILED" >&2
  ui_spaced "BUILD FAILED" >&2
  ui_bar_for "BUILD FAILED" >&2
}
