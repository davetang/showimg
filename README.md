# showimg

Show images in your terminal, including over SSH and inside tmux or GNU
screen.

```sh
# on a remote server
showimg plot.png
# the plot appears in your terminal, below the command
```

Over SSH, `showimg` sends the image to your local terminal as an **escape
sequence**: the kitty graphics protocol, iTerm2's inline images or sixel,
whichever your terminal understands. It travels over the SSH connection you
already have, so you don't need `scp`, X11 forwarding, or anything installed on
your own machine. PNG needs nothing but coreutils and awk. PDF, SVG, JPEG and
other formats are converted with tools such as `pdftoppm` and ImageMagick when
they're installed.

- [Install](#install)
- [Usage](#usage)
- [Your terminal](#your-terminal)
- [tmux, GNU screen and mosh](#tmux-gnu-screen-and-mosh)
- [R and Python](#r-and-python)
- [Limitations](#limitations)
- [Troubleshooting](#troubleshooting)
- [How it works](#how-it-works)
- [Alternatives](#alternatives)
- [Uninstall](#uninstall)

---

## Install

On the machine you SSH **into**:

```sh
git clone <repo-url> showimg
cd showimg
./setup.sh
```

`setup.sh`:

| Step | What it does |
| --- | --- |
| Requirements | Checks for `base64`, `tr`, `fold`, `od`, `head`, `wc`, `stty`, `mktemp` (all in coreutils) and `awk` |
| Install | Copies `showimg` to `~/bin` |
| PATH | If `~/bin` isn't on `PATH`, adds it at the top of `~/.bashrc` (before any early return for non-interactive shells), or to `~/.zshenv` for zsh |
| tmux | Adds `set -gq allow-passthrough on` to `~/.tmux.conf` (or `~/.config/tmux/tmux.conf` if that's the only one you have) and applies it to a running tmux server. If you've already set it to `off`, it warns instead of changing it. It also warns about tmux older than 3.3, and if run inside tmux, it reports what tmux knows about your terminal |
| screen, mosh | Reports on them. screen needs no configuration. mosh can't carry images |
| Converters | Reports which optional converters are installed, and what each one adds (see [Formats](#formats)) |

It's safe to re-run, for example after `git pull`. Every line it adds to a
config file is preceded by a `# added by showimg setup.sh` comment.

The one thing `setup.sh` can't do is change your **local** terminal. Warp,
kitty, Ghostty, iTerm2 and WezTerm show images as they are. VS Code needs
images switched on, and some terminals can't show them at all (see [Your
terminal](#your-terminal)).

Then, in a new shell:

```sh
showimg example.png
```

`example.png` is in the repository: a plot of two waves.

---

## Usage

```
Usage: showimg [-c COLS] [-r ROWS] [-p PROTOCOL] [-v] [FILE...]

Show images in your terminal. Over SSH the image is sent to your local
terminal as an escape sequence. With no FILE, or when FILE is -, read an
image from standard input.

  -c COLS      at most COLS columns wide (default: the terminal's width)
  -r ROWS      at most ROWS rows tall (default: the terminal's height less 2)
  -p PROTOCOL  kitty, iterm, sixel or text (default: $SHOWIMG_PROTOCOL, or
               the one your terminal supports; kitty if it can't be asked,
               as inside GNU screen)
  -v           print the protocol and size used
  -h           show this help
```

Examples:

```sh
showimg plot.png
showimg -r 20 heatmap.pdf           # 20 rows tall: smaller
showimg figures/*.png               # one after another, each under its name
curl -s https://example.com/logo.png | showimg
showimg -v plot.png                 # prints e.g. "showimg: plot.png: kitty (via tmux), 34 rows ..."
showimg -p text plot.png            # coloured characters, for any terminal (needs chafa)
```

### Size

An image fills the width of the terminal, unless that would make it taller than
the terminal less two rows (one for the command above it, one for the prompt
below). `-c` and `-r` set smaller limits. Small images are scaled up to fit: a
plot saved at a higher resolution (`res = 150` in R, `dpi=150` in matplotlib)
looks sharper.

`showimg` sets the image's height in rows and lets the terminal work out the
width, so it always keeps its shape. To pick the number of rows, it needs to
know the size of a character cell in pixels. It asks the terminal, or tmux. If
neither can say, as inside GNU screen, it assumes cells twice as tall as they're
wide (a little more, to be safe), so a wide image may come out a little
narrower than the window.

### Formats

| Format | What it needs |
| --- | --- |
| PNG | Nothing |
| JPEG, GIF | Nothing on iTerm2-protocol terminals (iTerm2 and WezTerm also play animated GIFs). Elsewhere, ImageMagick, which takes the first frame of a GIF |
| PDF | `pdftoppm` (poppler-utils) or ImageMagick. Shows the first page |
| SVG | `rsvg-convert` (librsvg) or ImageMagick |
| Others (WebP, TIFF, BMP, ...) | ImageMagick |

Sixel terminals also need `img2sixel` (libsixel) or ImageMagick. `img2sixel`
1.10 writes nothing at all for images of only a few colours, such as a plain
diagram, and `showimg` then uses ImageMagick if it's there. `showimg -p text`
needs `chafa`. All of these go on the machine where `showimg` runs, and
`setup.sh` reports which ones it found.

`showimg` recognises a file by its first bytes, not its name, so `plot` with no
extension works, and so does a PNG on standard input.

### How it picks a protocol

| Situation | Where it looks |
| --- | --- |
| `-p`, or `$SHOWIMG_PROTOCOL` set | Uses that |
| Inside tmux | The terminal's name, which tmux 3.3+ asks the terminal for (`#{client_termtype}`), then its `TERM` (`#{client_termname}`) |
| Inside GNU screen | `$LC_TERMINAL` and `$TERM_PROGRAM` |
| Otherwise | Asks the terminal its name, then `$LC_TERMINAL`, `$TERM_PROGRAM` and `$TERM` |

| Name | Protocol |
| --- | --- |
| Contains kitty, ghostty or warp | `kitty` |
| Contains iterm or wezterm, or starts with vscode or mintty | `iterm` |
| foot (or `foot-...`, `foot(...`), or starts with contour or mlterm | `sixel` |

Case doesn't matter. If no name matches, `showimg` uses `kitty` if the
terminal answered its kitty graphics query, or `sixel` if the terminal reports
sixel support.

If the terminal can't be asked at all, `showimg` tries `kitty`, the protocol of
kitty, Ghostty and Warp, and `-v` says why. That's the case inside GNU screen,
which answers such questions itself, and inside tmux older than 3.3, which
doesn't ask the terminal its name (Warp, for one, sets `TERM` to plain
`xterm-256color`).

Otherwise it stops, says why it can't tell (for example, `it didn't answer
showimg's questions`), and asks you to set `SHOWIMG_PROTOCOL`.

Set `SHOWIMG_PROTOCOL` in your shell's startup file on the remote machine if
`showimg` guesses wrong, or can't tell. It overrides detection everywhere;
[GNU screen](#gnu-screen) shows how to set it only inside screen.

```sh
export SHOWIMG_PROTOCOL=iterm
```

---

## Your terminal

The terminal on the machine you're sitting at must show images:

| Terminal | Protocol | What to do |
| --- | --- | --- |
| Warp | `kitty` | Nothing, on macOS and Linux. Warp for Windows doesn't show images |
| kitty | `kitty` | Nothing |
| Ghostty | `kitty` | Nothing |
| iTerm2 | `iterm` | Nothing |
| WezTerm | `iterm` | Nothing. Its kitty support is off by default, so `showimg` uses the iTerm2 protocol |
| VS Code | `iterm` | Settings → turn on `terminal.integrated.enableImages` |
| mintty (Git Bash, Cygwin) | `iterm` | Nothing |
| foot | `sixel` | Install `img2sixel` or ImageMagick where `showimg` runs |
| Windows Terminal 1.22+ | `sixel` | As for foot. If `showimg` can't tell, set `SHOWIMG_PROTOCOL=sixel` |
| Alacritty, Apple Terminal.app, GNOME Terminal and other VTE terminals | None | Use `showimg -p text` (needs `chafa`), or a terminal from this table for SSH sessions |

Inside GNU screen, and inside tmux older than 3.3, `showimg` can't ask the
terminal and tries `kitty`. With an `iterm` or `sixel` terminal, set
`SHOWIMG_PROTOCOL` there (see [GNU screen](#gnu-screen)).

This table comes from each terminal's documentation (and, for Warp, its source
code). Apart from kitty, only the bytes `showimg` sends were tested, not the
terminals themselves (see [Testing](#testing)).

To test the terminal on its own, run one of these on the remote machine
**outside** tmux and screen. Each draws a red rectangle:

```sh
# kitty protocol: one red pixel, stretched to 10 columns by 5 rows
printf '\e_Ga=T,f=24,s=1,v=1,c=10,r=5;/wAA\e\\\n'
# iTerm2 protocol: a 1x1 red PNG, 10 columns by 5 rows
printf '\e]1337;File=inline=1;width=10;height=5;preserveAspectRatio=0:%s\a\n' \
  iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC
# sixel: 60x12 pixels
printf '\ePq"1;1;60;12#0;2;100;0;0#0!60~-!60~\e\\\n'
```

---

## tmux, GNU screen and mosh

### tmux

`setup.sh` adds this to `~/.tmux.conf`, or to `~/.config/tmux/tmux.conf` if
that's the only one you have:

```sh
set -gq allow-passthrough on
```

tmux keeps its own copy of the screen, and drops escape sequences it doesn't
handle itself, images included. `showimg` wraps the image in tmux's
**passthrough** sequence (`ESC Ptmux; ... ESC \`), which tmux hands to your
terminal unchanged, but only if `allow-passthrough` is on. It arrived in tmux
3.3 and is off by default. Older versions pass these sequences on without
being asked (but see [tmux before 3.3](#tmux-before-33) below), and `-q`
stops them complaining about the option they don't know ("invalid option:
allow-passthrough" at every start).

| `allow-passthrough` | Images from the pane you're looking at | From other panes and windows |
| --- | --- | --- |
| `off` (default) | no | no |
| `on` | yes | no |
| `all` | yes | yes |

`showimg` checks the setting and stops with the fix if it's off. To check by
hand:

```sh
tmux display -p '#{allow-passthrough}'
```

**Caution:** passthrough lets any program in the pane you're looking at send
your terminal escape sequences that tmux would otherwise filter, for example
`cat` on a file crafted to set your clipboard. That's the same as running the
program without tmux.

tmux 3.3+ also asks your terminal its name, which is how `showimg` tells what
your terminal is from inside tmux:

```sh
tmux display -p '#{client_termtype}'    # e.g. "Warp(v0.2026.05.06.15.42.stable_02)"
```

The image isn't part of tmux's copy of the screen. tmux doesn't know it's
there, so when tmux redraws the window (you switch windows, resize, or scroll
in copy mode), the image may vanish, or stay where the text has moved on. Run
`showimg` again to bring it back, or `clear` to tidy up.

**Size limits.** After each passthrough, tmux writes some escape sequences of
its own, so each one has to carry a whole image sequence. kitty images go in
chunks of 4 KB, each a whole sequence. iTerm2 and sixel images go in one piece,
and tmux drops a sequence bigger than its input buffer, 1 MiB (settable with
`input-buffer-size` from tmux 3.6). `showimg` stops with a message for an image
that big: use `-r` to make a sixel image smaller.

#### tmux before 3.3

tmux before 3.3 throws output away when it piles up faster than it can send
it to your terminal, more than about 8 bytes for each character cell of the
window (15 KB at 80×24). It drops parts of large images, and with them the whole
image. `showimg` sends kitty images more slowly there, with a 10 ms pause after
each chunk, which in testing got a 930 KB image through tmux 3.1 every time. An
iTerm2 or sixel image goes in one piece and can't be slowed down, so `showimg`
stops with a message if one is over that limit. tmux 3.3 and later never throw
passthrough output away. Upgrade if you can; RHEL 9 still ships tmux 3.2a.

### GNU screen

screen itself needs no configuring. It doesn't pass these sequences on, but it
does pass DCS strings (`ESC P ... ESC \`) to the outer terminal unchanged. So
when `$STY` is set, `showimg` sends the image in pieces of up to 450 bytes, each
in its own DCS (screen drops ones much over 760 bytes). The kitty protocol and
sixel end each sequence with `ESC \`, which would end the DCS early, so
`showimg` ends one DCS after the `ESC` and starts the next with the `\`. In
testing, screen 4.8 passed images through intact, and kitty showed an image
through screen 5.0.2.

Inside screen, though, `showimg` can't ask your terminal its name, because
screen answers such questions itself. So it tries the kitty protocol, which
kitty, Ghostty and Warp use; `showimg -v` says `so trying kitty`. For a
terminal that uses another protocol (see [Your terminal](#your-terminal)), set
`SHOWIMG_PROTOCOL` in your shell's startup file on the remote machine,
`~/.zshrc` or `~/.bashrc`. Set it only inside screen, so that detection still
works outside it:

```sh
if [ -n "${STY:-}" ]; then
  export SHOWIMG_PROTOCOL=iterm    # iTerm2, WezTerm; sixel for foot, Windows Terminal
fi
```

If you reach screen from terminals that use different protocols, choose one
for each command instead: `showimg -p iterm plot.png`.

`showimg` also checks `LC_TERMINAL` and `TERM_PROGRAM` inside screen: iTerm2
sets `LC_TERMINAL`, and many servers accept `LC_*` variables over SSH. But a
screen window gets its environment from when the screen session started, so
after you reattach from another terminal, they still name the old one.

As with tmux, screen doesn't know the image is there, so a redraw can remove it
or leave it behind. screen also drops these sequences from windows you aren't
looking at.

### mosh

mosh redraws the screen itself and passes on only what it understands. Images
aren't among that, so they never arrive. In a mosh session, use `showimg -p
text`, which draws the image with coloured characters (needs `chafa`).

---

## R and Python

`showimg` writes to the terminal (`/dev/tty`), so it works when run from R or
Python in a terminal session, not from RStudio Server or Jupyter.

### R

Add to `~/.Rprofile`:

```r
# show a plot in the terminal: showplot(plot(cars)), or showplot(p) for a
# ggplot
showplot <- function(plot, width = 7, height = 5, res = 150) {
  f <- tempfile(fileext = ".png")
  on.exit(unlink(f))
  png(f, width = width, height = height, units = "in", res = res)
  tryCatch({
    drawn <- withVisible(plot)               # base graphics draw here
    if (drawn$visible) print(drawn$value)    # ggplot and lattice draw when printed
  }, finally = dev.off())
  invisible(system2("showimg", shQuote(f)))
}
```

Then:

```r
showplot(plot(cars))
showplot({
  hist(rnorm(1000))
  abline(v = 0, col = "red")
})

library(ggplot2)
p <- ggplot(mpg, aes(displ, hwy)) + geom_point()
showplot(p)
```

Pass the plotting code itself: `showplot` runs it with a PNG file open as the
graphics device. A plot that's already been drawn can't be copied over, since
without X11, R draws on a PDF device that keeps no record of the plot.

### Python

```python
import subprocess
import tempfile

import matplotlib
matplotlib.use("Agg")  # draw without a display
import matplotlib.pyplot as plt


def showplot(fig=None, dpi=150):
    """Show a matplotlib figure (default: the current one) in the terminal."""
    fig = fig or plt.gcf()
    with tempfile.NamedTemporaryFile(suffix=".png") as f:
        fig.savefig(f.name, dpi=dpi, bbox_inches="tight")
        subprocess.run(["showimg", f.name], check=False)


plt.plot([1, 2, 3], [2, 4, 3])
showplot()
```

---

## Limitations

- **Images don't stay.** They're drawn on top of the terminal's text, and
  nothing redraws them. Inside tmux or screen, a redraw can remove them or
  leave them behind (see [tmux](#tmux)).
- **tmux before 3.3** sends kitty images slowly, and can't take iTerm2 or sixel
  images over about 8 bytes per character cell (see [tmux before
  3.3](#tmux-before-33)). In any
  tmux, an iTerm2 or sixel image has to fit in 1 MiB.
- **mosh** can't carry images. Use `showimg -p text`.
- **No terminal.** `ssh host 'showimg plot.png'` without `-t`, cron jobs and
  similar have no terminal to draw on. `showimg` exits with an error.
- **Cell size.** Inside GNU screen, and in tmux when the terminal doesn't report
  its size in pixels, `showimg` guesses the size of a character cell (see
  [Size](#size)). A sixel image may then come out taller or shorter than the
  space made for it.
- **First page, first frame.** Only the first page of a PDF is shown, and only
  the first frame of an animated GIF, except on iTerm2-protocol terminals. For
  another page, convert it yourself: `pdftoppm -png -f 3 -l 3 -singlefile
  report.pdf page3 && showimg page3.png`.
- **tmux control mode** (iTerm2's `tmux -CC` integration, and Warp's older
  tmux-based SSH sessions) is neither supported nor tested: tmux sends those
  clients the screen in its own protocol, not as escape sequences.
- **Nested multiplexers** (tmux inside screen, or the reverse) aren't handled.
- **Large images.** Base64 makes the data a third larger, and it all goes
  through the terminal. A few MB is fine on a fast link, but slow over a slow
  one.

---

## Troubleshooting

Run `showimg -v` to see which protocol and size it picked, then test one layer
at a time: the terminal on its own (the `printf` tests under [Your
terminal](#your-terminal)), then inside tmux or screen.

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `showimg: can't tell which image protocol your terminal supports: ...` | Given after the colon: a terminal `showimg` doesn't know, one that didn't answer, or tmux that didn't learn its name | `export SHOWIMG_PROTOCOL=kitty` (or `iterm`, `sixel`); see [Your terminal](#your-terminal) |
| Blank space, or garbage such as `Ga=T,f=100,...`, inside screen or tmux older than 3.3 | `showimg` couldn't ask the terminal, tried `kitty` (`-v` says `so trying kitty`), and your terminal uses another protocol | Set `SHOWIMG_PROTOCOL` inside screen; see [GNU screen](#gnu-screen) |
| `showimg: tmux won't pass the image on: ...` | `allow-passthrough` is off | `tmux set -g allow-passthrough on`, or re-run `setup.sh` |
| `showimg: ...: too big for tmux ...` | An iTerm2 or sixel image over tmux's limit (see [tmux](#tmux)) | Smaller `-r` for sixel, a smaller image, or a newer tmux |
| Part of the image, or none, inside tmux older than 3.3 | tmux threw output away | Upgrade tmux to 3.3+; see [tmux before 3.3](#tmux-before-33) |
| Blank space where the image should be, outside tmux/screen | The terminal doesn't support that protocol, or has images off | Try the `printf` tests; set `-p` or `SHOWIMG_PROTOCOL`; VS Code: turn on images |
| Blank space inside tmux, image outside it | Image drawn in a pane you weren't looking at, or tmux redrew the window | Run it again in the pane you're looking at |
| Garbage characters such as `Ga=T,f=100,...` | The terminal doesn't understand the protocol `showimg` picked | Set `SHOWIMG_PROTOCOL` to one it does, or use `-p text` |
| Nothing over mosh | mosh can't carry images | `showimg -p text` |
| `showimg: ...: PDF needs pdftoppm ...` (or SVG, or ImageMagick) | A converter isn't installed | Install it, or save the plot as PNG |
| Image too wide and cut off at the right, or too narrow | Cell size was guessed (`-v` says "a guess") | `-c` / `-r` |
| A pause of 2 seconds, then `can't tell ...: it didn't answer showimg's questions` | The terminal didn't answer `showimg`'s questions at all | Set `SHOWIMG_PROTOCOL`, and try the `printf` tests |
| `showimg: no terminal to show the image in` | Not running in an interactive terminal | `ssh -t host showimg ...` |
| `showimg: command not found` | `~/bin` not on `PATH` yet | Open a new shell, or `source ~/.bashrc` (zsh: `~/.zshenv`) |

---

## How it works

### Images as escape sequences

Terminals act on **escape sequences** in program output: bytes starting with
`ESC` that mean "change colour", "move the cursor", "set the window title".
Three families of sequences carry images:

| Protocol | Sequence | Image data | Terminals |
| --- | --- | --- | --- |
| kitty graphics protocol | APC: `ESC _G <keys> ; <data> ESC \`, in chunks of up to 4096 bytes | Base64 PNG (or raw pixels) | kitty, Ghostty, Warp, Konsole (in part), WezTerm (off by default) |
| iTerm2 inline images | OSC 1337: `ESC ] 1337 ; File=<keys> : <data> BEL` | Base64 file: PNG, JPEG, GIF, ... | iTerm2, WezTerm, VS Code, mintty, Konsole |
| sixel | DCS: `ESC P q <data> ESC \` | Pixels as printable characters, six rows at a time | foot, Windows Terminal, xterm (`-ti vt340`), mlterm, WezTerm, iTerm2, Konsole |

```
ESC _G a=T,f=100,t=d,q=2,C=1,r=34,m=1 ; iVBORw0KGgo... ESC \
│   │  │   │     │   │   │   │    │     │             └─ end (ST)
│   │  │   │     │   │   │   │    │     └─ up to 4096 bytes of base64 PNG
│   │  │   │     │   │   │   │    └─ more chunks follow (m=0 on the last)
│   │  │   │     │   │   │   └─ 34 rows tall; the width follows from the shape
│   │  │   │     │   │   └─ leave the cursor where it is
│   │  │   │     │   └─ no replies (they'd turn up as typed input)
│   │  │   │     └─ the data is in the sequence itself
│   │  │   └─ PNG
│   │  └─ transmit and display
│   └─ G: graphics
└─ APC: Application Program Command
```

The data is **base64-encoded**, so that nothing in the image can end the
sequence early or be read as a terminal command.

The sequence is ordinary output, so it travels the same path as everything else
on screen:

```
remote machine                                          your machine
showimg ─► tmux / screen ─► sshd ══ SSH ══► ssh client ─► terminal ─► image
           (must pass it on)                             (must understand it)
```

### Asking the terminal

Outside tmux and screen, `showimg` writes four questions to the terminal and
reads the answers:

| Question | Answer, e.g. | Tells it |
| --- | --- | --- |
| `ESC _Gi=31,s=1,v=1,a=q,t=d,f=24;AAAA ESC \` (kitty query) | `ESC _Gi=31;OK ESC \` | The kitty protocol works |
| `ESC [>0q` (XTVERSION) | `ESC P>\|Warp(v0.2026...) ESC \` | The terminal's name and version |
| `ESC [14t` | `ESC [4;1200;1800t` | The text area in pixels: with `stty size`, the cell size |
| `ESC [c` (DA1) | `ESC [?62;4c` | 4 means sixel. Every terminal answers this, so it marks the end |

Terminals ignore questions they don't understand, and answer the rest in
order, so the DA1 reply means there's nothing more to wait for. Inside tmux,
`showimg` reads the same facts from tmux (`#{client_termtype}`,
`#{client_cell_width}`), which gets them from the terminal when you attach.
Inside screen, it can't ask at all: screen answers these questions itself.

### Placing the image

`showimg` first prints as many newlines as the image has rows and moves the
cursor back up, so the screen scrolls before the image is drawn, not while.
Then it saves the cursor position (`ESC 7`), sends the image, and restores the
cursor (`ESC 8`), so the cursor ends up where tmux and screen think it is.
Finally it moves the cursor down past the image, ready for the prompt.

### Why tmux and screen get in the way

tmux and screen are terminal emulators themselves. They read everything
programs print, keep their own copy of the screen, and redraw it on the real
terminal. A sequence they don't handle is dropped. Both have a way to pass a
sequence through untouched: tmux's passthrough (`ESC Ptmux; ... ESC \`, with
every `ESC` inside doubled), and screen's DCS strings. Each has its own catch:
tmux writes escape sequences of its own after each passthrough, so one can't
carry half an image sequence, while screen drops long DCS strings, so the image
has to be cut into small ones. See [tmux, GNU screen and
mosh](#tmux-gnu-screen-and-mosh).

---

## Alternatives

| Tool | Runs | Best for |
| --- | --- | --- |
| `showimg` | Remote machine: bash, coreutils and awk | Plots over SSH, through tmux and screen, without installing anything |
| [chafa](https://hpjansson.org/chafa/) | Remote machine | kitty, iTerm2 and sixel, many formats, and text output, if you can install it |
| `kitten icat` | Remote machine (kitty's `kitten` binary) | kitty, Ghostty; handles tmux with Unicode placeholders, which Warp doesn't support |
| [imgcat](https://iterm2.com/documentation-images.html) | Remote machine | iTerm2 and WezTerm |
| [timg](https://github.com/hzeller/timg), [viu](https://github.com/atanunq/viu) | Remote machine | Several protocols, video (timg) |
| `scp host:plot.png . && open plot.png` | Your machine | Full-size viewing, zooming, saving |
| VS Code Remote-SSH, Jupyter | Your machine and the remote | Interactive work with many plots |

---

## Uninstall

```sh
rm ~/bin/showimg
grep -n 'added by showimg setup.sh' ~/.bashrc ~/.zshenv ~/.tmux.conf \
  "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf" 2> /dev/null
```

Each marker comment is followed by the one line that was added. Delete both
with `vi`. Leaving `set -gq allow-passthrough on` lets other image tools work
in tmux too; see the caution under [tmux](#tmux) before deciding.

---

## Testing

`showimg` and `setup.sh` were tested on Linux with bash 5.2. A small Python
program stood in for the terminal. It ran each test in a pseudo-terminal,
recorded every byte that reached it, and answered `showimg`'s questions the way
the terminal it imitated would: for Warp, the XTVERSION reply
`Warp(v0.2026.05.06.15.42.stable_02)` and a 9×18-pixel cell. The image was then
rebuilt from the recording and compared with the original file, byte for byte.

| Path | kitty | iTerm2 | sixel |
| --- | --- | --- | --- |
| No multiplexer | Intact | Intact | Intact |
| tmux 3.7, `allow-passthrough on` | Intact, a 7.2 MB image too | Intact; a 1.2 MB one refused | Intact |
| tmux 3.1 | Intact, a 930 KB image too, with the pause after each chunk (without it, 1 run in 5) | Intact (32 KB encoded) | 141 KB refused; 14 KB (`-r 8`) intact |
| GNU screen 4.8 | Intact, a 7.2 MB image too | Intact | Intact |

Also tested:

- **Placement.** Inside tmux, the cursor ended on the row below the image every
  time.
- **Detection.** Warp was recognised from its XTVERSION reply outside tmux, and
  from `#{client_termtype}` inside tmux 3.7, which also gave the right cell size.
  WezTerm was recognised by XTVERSION, iTerm2 by `LC_TERMINAL`, kitty by `TERM`,
  and an unnamed terminal by its answer to the kitty query or the sixel attribute
  in its DA1 reply. Where the terminal can't be asked (inside screen 4.8, tmux
  3.1, tmux not on `PATH`), `showimg` tried kitty, `-v` gave the reason, and
  through screen and tmux 3.1 the image arrived intact; `SHOWIMG_PROTOCOL`
  still came first. Each case where it stops was checked to give the right
  reason: tmux 3.7 that didn't learn the terminal's name, an unknown terminal
  name inside and outside tmux, a terminal that answers nothing (after 2
  seconds), and one that answers only DA1.
- **Formats.** PNG (8-bit, 16-bit and palette), baseline and progressive JPEG,
  JPEG with a 51 KB EXIF block and padding bytes, animated GIF, PDF, SVG, WebP,
  BMP and TIFF, with each protocol. Sizes read from the file headers matched
  ImageMagick's. Without converters, each format that needs one gets a message
  naming it. Broken, empty, unreadable and missing files, directories, standard
  input, and odd names (with a space, starting with `-`) were all tested.
- **Ctrl-C** in the middle of a 7.2 MB image, outside tmux, inside tmux 3.7 and
  inside screen: text printed afterwards reached the terminal outside any escape
  sequence. Ctrl-C while `showimg` waited for the terminal's answers left echo
  on.
- **awk.** The awk parts were run with mawk 1.3.4, gawk 5.4 and BusyBox awk 1.35.
- **The examples in this README.** The R functions (R 4.5.3, ggplot2 4.0.3, no
  X11) and the Python one (matplotlib 3.11) drew the expected plots. The three
  `printf` tests produce red rectangles (decoded with ImageMagick 7.1 and
  libsixel's `sixel2png`).
- **`setup.sh`**, in a throwaway `HOME`: fresh install, and re-run without
  duplicate lines; bash, zsh and an unknown shell; a `tmux.conf` with
  `allow-passthrough off`, `all`, or only an XDG config; tmux 3.1, which
  started without complaint thanks to `-q`; a running tmux 3.7 server, where it
  applied the setting; run inside tmux, where it reported Warp; a missing `od`;
  another `showimg` earlier on `PATH`; converters present and absent; and a
  repository path with a space in it.

On a real terminal: kitty on Debian showed `example.png` correctly over SSH,
inside screen 5.0.2 with `SHOWIMG_PROTOCOL=kitty` (and with `-p kitty`), and
outside screen, where `showimg` recognised kitty by itself.

Not tested: other real terminals, Warp included; kitty in tmux; macOS (bash 3.2
and BSD tools); mosh; tmux control mode.

---

## References

- kitty graphics protocol: <https://sw.kovidgoyal.net/kitty/graphics-protocol/>
- iTerm2 inline images: <https://iterm2.com/documentation-images.html>
- xterm control sequences (sixel, XTVERSION, DA1, `CSI 14 t`):
  <https://invisible-island.net/xterm/ctlseqs/ctlseqs.html>
- `man tmux`: `allow-passthrough`, `client_termtype`, `client_cell_width`
- Warp's kitty image support: <https://www.warp.dev/blog/launch-log-2>, and its
  source (`crates/warp_terminal/src/model/kitty.rs`):
  <https://github.com/warpdotdev/warp>
- WezTerm image support: <https://wezterm.org/imgcat.html>
- Windows Terminal 1.22 (sixel):
  <https://devblogs.microsoft.com/commandline/windows-terminal-preview-1-22-release>
- libsixel (`img2sixel`): <https://github.com/libsixel/libsixel>
- chafa: <https://hpjansson.org/chafa/>
