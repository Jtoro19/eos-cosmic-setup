#!/usr/bin/env bash
# modules/18-packages-media.sh: Media and creative apps (GIMP, Krita, Spotify, Vesktop).

# shellcheck disable=SC2034  # metadata is read by install.sh
MODULE_NAME="packages-media"
# shellcheck disable=SC2034
MODULE_DESC="Media and creative apps (GIMP, Krita, Spotify, Vesktop, OBS, Kdenlive)"
# shellcheck disable=SC2034
MODULE_OPTIN=1
# shellcheck disable=SC2034
MODULE_DEPS="packages flatpak"

module_apply() {
  install_package_list media
}
