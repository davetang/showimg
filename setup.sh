#!/usr/bin/env bash
# setup.sh: install showimg into ~/bin and set up what it needs.
#
# Run it on the machine you SSH into. Nothing needs installing on the machine
# you SSH from: your terminal just has to be one that shows images (see
# README.md).
#
# Safe to re-run: it refreshes the installed script and skips anything that is
# already set up. Lines it adds to your config files are marked with a comment.
set -euo pipefail

# cd prints the directory when $CDPATH finds it, so discard its output
repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null && pwd)
bin_dir=$HOME/bin
marker='# added by showimg setup.sh'

ok()   { printf '  ok:    %s\n' "$*"; }
did()  { printf '  added: %s\n' "$*"; }
note() { printf '  note:  %s\n' "$*"; }
warn() { printf '  WARN:  %s\n' "$*"; }

# --- requirements -----------------------------------------------------------
echo "Requirements"
missing=
for cmd in base64 tr fold od head wc stty mktemp awk; do
  command -v "$cmd" > /dev/null || missing="$missing $cmd"
done
if [[ -n $missing ]]; then
  echo "  missing required commands:$missing (all in coreutils, apart from awk)" >&2
  exit 1
fi
ok "base64, tr, fold, od, head, wc, stty, mktemp, awk"

# --- install ----------------------------------------------------------------
echo "Install"
mkdir -p "$bin_dir"
install -m 0755 "$repo_dir/showimg" "$bin_dir/showimg"
ok "copied showimg to $bin_dir/showimg"

# --- PATH -------------------------------------------------------------------
echo "PATH"
case ":$PATH:" in
  *":$bin_dir:"*)
    ok "$bin_dir is on PATH"
    found=$(command -v showimg || true)
    if [[ $found != "$bin_dir/showimg" ]]; then
      warn "'showimg' runs $found, which comes before $bin_dir on PATH"
    fi
    ;;
  *)
    # pick files that non-interactive shells read too, so that commands like
    # `ssh -t host 'showimg plot.png'` find showimg
    case $(basename "${SHELL:-}") in
      bash) rc=$HOME/.bashrc ;;
      zsh)  rc=$HOME/.zshenv ;;   # read by every zsh; .zshrc is interactive only
      *)    rc= ;;
    esac
    line='export PATH="$HOME/bin:$PATH"'
    if [[ -z $rc ]]; then
      warn "add $bin_dir to PATH in your shell's startup file"
    elif grep -qsF "$line" "$rc"; then
      ok "$rc already adds ~/bin to PATH (open a new shell to pick it up)"
    else
      # add it at the top: many ~/.bashrc files, such as Debian's and
      # Ubuntu's, return early in non-interactive shells. The x stops $(...)
      # from removing the file's trailing newlines
      content=$(cat "$rc" 2> /dev/null; printf x)
      printf '%s\n%s\n\n%s' "$marker" "$line" "${content%x}" > "$rc"
      did "~/bin to PATH at the top of $rc (open a new shell, or run: source $rc)"
    fi
    ;;
esac

# --- tmux -------------------------------------------------------------------
echo "tmux"
if ! command -v tmux > /dev/null; then
  ok "not installed, nothing to do"
else
  if [[ -f $HOME/.tmux.conf || ! -f ${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf ]]; then
    conf=$HOME/.tmux.conf
  else
    conf=${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf
  fi

  # version checks are skipped for builds without a number, e.g. "tmux master"
  version=$(tmux -V | grep -Eo '[0-9]+\.[0-9]+' | head -n 1 || true)
  major=${version%%.*}
  minor=${version#*.}
  [[ -z $version ]] && major=99 minor=0
  has_option=false
  if (( major > 3 || (major == 3 && minor >= 3) )); then
    has_option=true
  fi

  # the last allow-passthrough line wins, so that's the one to check
  current=$(grep -sE '^[[:space:]]*set(-option)?[[:space:]].*allow-passthrough' "$conf" | tail -n 1 || true)
  passthrough_on=false
  if [[ -z $current ]]; then
    # -q: tmux before 3.3 has no such option (it always passes images on), and
    # would otherwise complain about the line at every start
    printf '\n%s: let programs such as showimg send images to your terminal\nset -gq allow-passthrough on\n' \
      "$marker" >> "$conf"
    did "'set -gq allow-passthrough on' to $conf"
    passthrough_on=true
  elif [[ $current =~ allow-passthrough[[:space:]]+(on|all)([[:space:]]|$) ]]; then
    ok "$conf already has allow-passthrough ${BASH_REMATCH[1]}"
    passthrough_on=true
  else
    warn "$conf has '$current'; showimg needs 'set -g allow-passthrough on'"
  fi

  if ! $has_option; then
    warn "tmux $version can drop large images; tmux 3.3+ doesn't (see README.md)"
    note "tmux $version passes images on without allow-passthrough, which takes effect from tmux 3.3"
  elif $passthrough_on && tmux list-sessions > /dev/null 2>&1; then
    tmux set -g allow-passthrough on
    ok "applied to the running tmux server"
  fi

  # tmux 3.3+ asks the terminal its name (XTVERSION), which is how showimg
  # tells inside tmux what your terminal is
  if [[ -n ${TMUX:-} ]]; then
    termtype=$(tmux display -p '#{client_termtype}' 2> /dev/null || true)
    termname=$(tmux display -p '#{client_termname}' 2> /dev/null || true)
    note "this terminal: ${termtype:-name unknown (tmux 3.3+ asks the terminal)}, TERM=$termname"
  fi
fi

# --- GNU screen -------------------------------------------------------------
echo "GNU screen"
if command -v screen > /dev/null; then
  ok "nothing to configure: showimg wraps the image for screen itself"
  note "inside screen, showimg can't ask your terminal what it supports: set SHOWIMG_PROTOCOL (see README.md)"
else
  ok "not installed, nothing to do"
fi

# --- mosh -------------------------------------------------------------------
if command -v mosh-server > /dev/null; then
  echo "mosh"
  note "$(mosh-server --version 2>&1 | head -n 1)"
  note "mosh can't carry images; in mosh sessions, use 'showimg -p text' (needs chafa)"
fi

# --- converters -------------------------------------------------------------
echo "Converters (optional: PNG needs none)"
found=
for cmd in pdftoppm rsvg-convert magick convert img2sixel chafa; do
  if command -v "$cmd" > /dev/null; then
    # convert is only ImageMagick's if it says so
    if [[ $cmd == convert ]]; then
      case $(convert -version 2> /dev/null) in
        *ImageMagick*) ;;
        *) continue ;;
      esac
    fi
    found="$found $cmd"
  fi
done
has() { [[ " $found " == *" $1 "* ]]; }
if has pdftoppm || has magick || has convert; then
  ok "PDF: first page, with $(if has pdftoppm; then echo pdftoppm; else echo ImageMagick; fi)"
else
  note "PDF: install poppler-utils (pdftoppm) or ImageMagick"
fi
if has rsvg-convert || has magick || has convert; then
  ok "SVG: with $(if has rsvg-convert; then echo rsvg-convert; else echo ImageMagick; fi)"
else
  note "SVG: install librsvg (rsvg-convert) or ImageMagick"
fi
if has magick || has convert; then
  ok "JPEG, GIF and other formats: with ImageMagick"
else
  note "JPEG, GIF and other formats: install ImageMagick (iTerm2-protocol terminals take JPEG and GIF without it)"
fi
if has img2sixel || has magick || has convert; then
  ok "sixel terminals: with $(if has img2sixel; then echo img2sixel; else echo ImageMagick; fi)"
else
  note "sixel terminals (foot, Windows Terminal): install libsixel (img2sixel) or ImageMagick"
fi
if has chafa; then
  ok "showimg -p text, for terminals without images: with chafa"
else
  note "showimg -p text, for terminals without images and mosh: install chafa"
fi

# quoted, in case the path has spaces in it
example=$(printf '%q' "$repo_dir/example.png")
cat <<EOF

Done. In a new shell, try:

  showimg $example

A plot of two waves should appear. If it doesn't, \`showimg -v\` prints what it
tried; see "Your terminal" and "Troubleshooting" in README.md.
EOF
