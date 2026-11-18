# pacman-conf

## Purpose

Apply the pacman options used on the reference host and enable the `multilib`
repository, which Steam and the `lib32-*` drivers need.

## Source of truth

`/etc/pacman.conf` on the reference host, `[options]` section:

- `Color`
- `ILoveCandy`
- `VerbosePkgLists`
- `ParallelDownloads = 5`

and an enabled `[multilib]` section with `Include = /etc/pacman.d/mirrorlist`.
Everything else in the file (`[endeavouros]`, `HoldPkg`, `DownloadUser`, other
repositories) is left exactly as the distribution ships it.

## Files and packages touched

- `/etc/pacman.conf` (via sudo, backed up as `pacman.conf.bak.<timestamp>`).
- When `multilib` was not enabled before: `pacman -Syu --noconfirm` to fetch the
  new database. A full upgrade is used instead of `-Sy` alone to avoid a
  partial upgrade when the next modules install packages.

## How the file is edited

The module renders the desired file with awk and installs it only if it
differs:

- In `[options]`, each wanted key is matched commented or not and with any
  value (`#Color`, `ParallelDownloads = 3`) and replaced in place. Missing keys
  are added at the end of the `[options]` section.
- A commented `#[multilib]` header and its following `#Include` line are
  uncommented. `[multilib-testing]` is never touched.

## Hardware detection

None.

## Ordering

The file is `05-pacman-conf.sh`, so it runs before `10-drivers.sh` and the
`lib32-*` drivers can be installed in the same run.

## Idempotency check

The rendered file is compared byte for byte with the current one
(`install_file`). A second render of the result is identical.

## Revert

Restore `/etc/pacman.conf.bak.<timestamp>`, or comment the options and the
`[multilib]` section by hand. Disabling multilib while `lib32-*` packages are
installed leaves them without updates; remove them first.

## Verification

- `./install.sh --only pacman-conf --dry-run` reports nothing to change on the
  reference host.
- `pacman-conf --repo-list` lists `multilib`; `pacman -Ss` output is colored.
