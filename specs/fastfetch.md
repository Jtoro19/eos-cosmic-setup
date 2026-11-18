# fastfetch

## Purpose

Show fastfetch with a random image as the logo every time a kitty terminal
opens, and build the pool of images it picks from.

## Source of truth

Captured from the reference machine: the fastfetch snippet in `~/.bashrc` and
the 500 images in `~/.config/fastfetch/images`. The procedure comes from
`reference/kitty_cosmic_fastfetch_guide.md` (sections 4 to 6). No fastfetch
`config.jsonc` exists on the reference machine, so none is shipped. No payload
files live in `files/`: the images are fetched from the upstream repos.

## Files and packages touched

- Packages (official): `fastfetch`, `imagemagick`, `git`, `git-lfs`.
- `~/.config/fastfetch/images/`: image pool, files named `<prefix>-<basename>`.
- `~/.config/fastfetch/bad/`: images that failed `magick identify` (never deleted).
- `~/.bashrc`: managed block `fastfetch`. The block only acts when
  `$TERM == xterm-kitty`, so the module depends on `kitty`. The legacy
  unmanaged copy of the snippet (the same 10 lines without the
  "(kitty only)" suffix) is removed first, and the managed block is appended at
  the end of the file (not at the legacy position).
- No services or units.

### Image sources

All repos are cloned shallow (`--depth 1`) into a `mktemp -d` directory under
`${TMPDIR:-/tmp}`, removed on exit.

| Prefix | Repo | Notes |
|--------|------|-------|
| `ronin` | Ronin-CK/fastfetchPNG-images | branch `master`, root |
| `thunder` | Thunder-Blaze/FastfetchPngs | root |
| `menhoudj` | menhoudj/my-fastfetch-config | `logos/` |
| `themes` | CheikhNaro/ffthemes | root |
| `mahe` | Maheswara660/fastfetch | `images/`, Git LFS (`git lfs pull`) |
| `sofija` | sofijacom/dotfiles-fastfetch | `png/` |

`Chintanpatel24/awesome-fastfetch` (prefix `awesome`, 35 images on the
reference host) was removed from GitHub in November 2026, so it is no longer a
source. Existing `awesome-*` files are kept. Clones run with
`GIT_TERMINAL_PROMPT=0`: a repo that disappears or turns private fails at once
with a warning instead of asking for GitHub credentials.

Files matching `*.png`, `*.jpg`, `*.jpeg`, `*.webp` (case-insensitive) are
copied with `cp --update=none`, excluding `*/.git/*` and `loli*`. Newly copied
files are resized with `magick mogrify -resize '600x600>'` and validated with
`magick identify`; invalid ones go to `~/.config/fastfetch/bad/`.

### Third-party content note

The images come from external repositories that this project does not control.
They mix anime art with logos, game characters and other content, and may
change over time. Files named `loli*` are deliberately excluded. Review the
folder and delete what you do not want.

### Opt-out

`FASTFETCH_SKIP_IMAGES=1 ./install.sh --only fastfetch` skips the image pool
entirely (packages and the bashrc block are still applied). Without images the
block falls back to the plain distro-logo fastfetch.

## Hardware detection

none

## Idempotency check

A source is considered done when at least one file `<prefix>-*` exists in the
images or `bad` directory; it is then skipped with no clone and no network
access. The legacy block is removed only when it is found verbatim outside
managed blocks, and the managed block is only written when missing or changed.
A clone failure for one repo logs a warning and the module continues (the
install does not fail because of third-party repos); that prefix is retried on
the next run. A second run reports "Nothing to change". In `--dry-run`, each
missing prefix prints `would fetch <prefix> from <url>` and counts one change.

## Revert

- Remove the `# >>> eos-cosmic-setup:fastfetch >>>` ... `<<<` block from
  `~/.bashrc` (or restore `~/.bashrc.bak.<timestamp>`, which still holds the
  legacy snippet).
- Optionally delete the pool: `rm -rf ~/.config/fastfetch/images
  ~/.config/fastfetch/bad`.
- `sudo pacman -Rns fastfetch` to remove the package (imagemagick, git and
  git-lfs may be used by other tools; remove only if unneeded).

## Verification

- `./install.sh --only fastfetch --dry-run` reports "Nothing to change" after a
  real run.
- `rg -c fastfetch ~/.bashrc` shows the single managed block, no legacy copy.
- `fd . ~/.config/fastfetch/images | wc -l` is about 500 (varies with upstream).
- In a new kitty window fastfetch shows a random image.
- `shellcheck -x install.sh lib/common.sh modules/*.sh files/kitty/kitty-cosmic-colors.sh`
