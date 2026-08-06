#!/usr/bin/bash

set -ouex pipefail

# Copy repository-controlled system files into the image.
cp -avf /ctx/system_files/. /

# Import repository keys before non-interactive package installation.
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
rpm --import https://packages.gundulabs.com/keys/gundulabs-repo.asc

# COPR support is required for the libjpeg8 compatibility package used by the
# existing Pantum vendor binaries. curl, jq, and unzip are used to install the
# newest GNOME-compatible extension releases from extensions.gnome.org.
dnf5 install -y \
    dnf5-plugins \
    curl \
    jq \
    unzip

dnf5 -y copr enable aflyhorse/libjpeg

# Native applications, authentication, printing, scanning, and Waydroid.
dnf5 install -y \
    brave-browser \
    gaze \
    gaze-gui \
    gaze-gnome-extension \
    cups \
    cups-client \
    cups-filters \
    system-config-printer \
    sane-backends \
    sane-backends-drivers-scanners \
    simple-scan \
    gscan2pdf \
    djvulibre \
    unpaper \
    seahorse \
    waydroid \
    libjpeg8 \
    libjpeg-turbo

# Native KVM/QEMU/libvirt/virt-manager virtualization stack.
dnf5 group install -y virtualization

# Download the newest extensions.gnome.org releases that explicitly support
# the GNOME Shell major version included in this Bluefin image.
gnome_major="$(rpm -q --qf '%{VERSION}\n' gnome-shell | cut -d. -f1)"

if [[ -z "$gnome_major" ]]; then
    echo "Unable to determine the GNOME Shell major version."
    exit 1
fi

/ctx/install-gnome-extension.sh \
    "tilingshell@ferrarodomenico.com" \
    "$gnome_major"

/ctx/install-gnome-extension.sh \
    "window-state-manager@kishorv06.github.io" \
    "$gnome_major"

# Install the newest stable Gruvbox Plus release system-wide. GitHub publishes
# a SHA-256 digest for the release asset, so verify it before copying files.
gruvbox_release="$(mktemp)"
gruvbox_archive="$(mktemp --suffix=.zip)"
gruvbox_extract="$(mktemp -d)"

curl -fsSL --retry 5 \
    https://api.github.com/repos/SylEleuth/gruvbox-plus-icon-pack/releases/latest \
    -o "$gruvbox_release"

gruvbox_asset_name="$(jq -r '.assets[] | select(.name | test("^gruvbox-plus-icon-pack-[0-9.]+\\.zip$")) | .name' "$gruvbox_release" | head -n1)"
gruvbox_asset_url="$(jq -r '.assets[] | select(.name == $name) | .browser_download_url' --arg name "$gruvbox_asset_name" "$gruvbox_release")"
gruvbox_asset_digest="$(jq -r '.assets[] | select(.name == $name) | .digest // empty' --arg name "$gruvbox_asset_name" "$gruvbox_release")"

if [[ -z "$gruvbox_asset_name" || -z "$gruvbox_asset_url" || "$gruvbox_asset_url" == null ]]; then
    echo "Unable to find the Gruvbox Plus release archive."
    exit 1
fi

if [[ ! "$gruvbox_asset_digest" =~ ^sha256:([0-9a-fA-F]{64})$ ]]; then
    echo "The Gruvbox Plus release asset has no usable SHA-256 digest."
    exit 1
fi

gruvbox_expected_hash="${BASH_REMATCH[1]}"

curl -fsSL --retry 5 "$gruvbox_asset_url" -o "$gruvbox_archive"
echo "${gruvbox_expected_hash}  $gruvbox_archive" | sha256sum -c -
unzip -q "$gruvbox_archive" -d "$gruvbox_extract"

gruvbox_dark="$(find "$gruvbox_extract" -type d -name Gruvbox-Plus-Dark -print -quit)"
gruvbox_light="$(find "$gruvbox_extract" -type d -name Gruvbox-Plus-Light -print -quit)"

if [[ -z "$gruvbox_dark" || -z "$gruvbox_light" ]]; then
    echo "The Gruvbox Plus archive does not contain both expected themes."
    exit 1
fi

rm -rf /usr/share/icons/Gruvbox-Plus-Dark /usr/share/icons/Gruvbox-Plus-Light
cp -a "$gruvbox_dark" /usr/share/icons/Gruvbox-Plus-Dark
cp -a "$gruvbox_light" /usr/share/icons/Gruvbox-Plus-Light

test -f /usr/share/icons/Gruvbox-Plus-Dark/index.theme
test -f /usr/share/icons/Gruvbox-Plus-Light/index.theme

gtk-update-icon-cache -f -t /usr/share/icons/Gruvbox-Plus-Dark || true
gtk-update-icon-cache -f -t /usr/share/icons/Gruvbox-Plus-Light || true

rm -rf "$gruvbox_release" "$gruvbox_archive" "$gruvbox_extract"

# Do not leave the temporary compatibility COPR enabled in the final system.
dnf5 -y copr disable aflyhorse/libjpeg

# Enable normal system services. Do not select Gaze's global authselect profile.
systemctl enable gazed.service
systemctl enable cups.service

# Waydroid is intentionally not enabled as an always-running boot service.
# Its standard package and GNOME launcher remain available for occasional use.

# Ensure copied executable vendor filters remain executable.
find /usr/lib/cups/filter -maxdepth 1 -type f -name 'pt*' \
    -exec chmod 0755 {} + || true

find /usr/lib/cups/filter -maxdepth 1 -type f -name 'rastertoPantum*' \
    -exec chmod 0755 {} + || true

chmod 0755 /opt/pantum/bin/ptqpdf
chmod 0755 /usr/libexec/precision-bluefin-enable-extensions

# Remove package-manager caches from the final image layer.
dnf5 clean all
