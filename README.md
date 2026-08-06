# Family Bazzite

[![Build signed family Bazzite image](https://github.com/iegorch86/family-bazzite/actions/workflows/build.yml/badge.svg)](https://github.com/iegorch86/family-bazzite/actions/workflows/build.yml)

A personal, signed Bazzite GNOME image for the family desktop.

This is not a general-purpose distribution or an official Bazzite/Universal Blue image. It is a small set of reproducible customizations layered on top of the current stable Bazzite GNOME image.

## Image

```text
ghcr.io/iegorch86/family-bazzite:stable
```

The image targets a normal AMD/Intel Bazzite GNOME desktop. It is not an NVIDIA-specific image.

## Included customizations

### Desktop applications

- Brave Browser installed as a native RPM
- Seahorse password and key manager
- Simple Scan
- system-config-printer

### Gaze face authentication

The image installs:

- `gaze`
- `gaze-gui`
- `gaze-gnome-extension`

The `gazed.service` system service is enabled.

The build deliberately does **not** run:

```text
authselect select gaze
```

This avoids replacing the system-wide authentication profile. Gaze is intended for the graphical login and lock-screen workflow rather than changing every PAM authentication path.

### Pantum printer and scanner support

The repository includes the vendor driver payload needed for the Pantum M6550NW and related Pantum models:

- CUPS filters and PPD files
- SANE scanner backends and configuration
- Pantum support files under `/opt/pantum`
- `libjpeg8` compatibility support required by the existing vendor binaries

CUPS is enabled in the image. Scanner support is provided through SANE and Simple Scan.

The `vendor-backup/` directory is retained only as a reference copy. It is not copied into the finished image.

### Native virtualization

The Fedora `virtualization` package group is installed directly into the image. This provides the native virtualization stack, including:

- KVM/QEMU
- libvirt modular daemons
- virt-manager
- virt-install
- virt-viewer
- SPICE and related QEMU components

This is the native Fedora virtualization stack, not a Flatpak installation.

## Switching to the image

From an existing Bazzite or compatible bootc system:

```bash
sudo bootc switch ghcr.io/iegorch86/family-bazzite:stable
sudo systemctl reboot
```

After rebooting, confirm the active deployment:

```bash
bootc status
```

Test the image on non-critical hardware before switching the primary family desktop.

## Published tags

Each successful build publishes several tags:

| Tag | Purpose |
| --- | --- |
| `stable` | Current recommended image |
| `upstream-<release>` | Marker for the matching Bazzite stable release |
| `stable-YYYYMMDD` | Build date |
| `stable-<git-sha>` | Source revision |
| `stable-YYYYMMDD-<git-sha>` | Date and source revision |

Example:

```text
upstream-44.20260802
stable-20260804-d4c5249
```

## Automated builds

The GitHub Actions workflow:

1. Inspects the current `ghcr.io/ublue-os/bazzite-gnome:stable` image.
2. Resolves its exact digest and version.
3. Confirms that the stable Bazzite GitHub release and image version agree.
4. Pins the build to that exact upstream digest.
5. Builds and runs `bootc container lint`.
6. Rechunks the image for more resumable updates.
7. Publishes all image tags to GHCR.
8. Signs the published digest with Cosign.

A scheduled check runs daily at 12:15 UTC. It skips rebuilding when the corresponding `upstream-<release>` marker already exists.

Pushes to `main`, pull requests, and manually dispatched runs use the current stable Bazzite digest. Markdown-only changes are excluded from automatic image builds.

## Signature verification

The public signing key is stored in [`cosign.pub`](./cosign.pub).

With Cosign installed, verify the published image with:

```bash
cosign verify \
  --key cosign.pub \
  ghcr.io/iegorch86/family-bazzite:stable
```

The private `cosign.key` must never be committed. GitHub Actions receives it through the repository secret named `SIGNING_SECRET`.

## Local build

Run the Justfile syntax checks:

```bash
just check
```

Build the image locally with rootful Podman:

```bash
sudo podman build \
  --pull=newer \
  --tag family-bazzite:test \
  --file Containerfile \
  .
```

Confirm that the main native virtualization packages are present:

```bash
sudo podman run --rm \
  --entrypoint /usr/bin/bash \
  family-bazzite:test \
  -c 'rpm -q qemu-kvm libvirt-daemon-kvm virt-manager virt-install virt-viewer'
```

## Repository layout

| Path | Purpose |
| --- | --- |
| [`Containerfile`](./Containerfile) | Selects the Bazzite base and runs the image build |
| [`build_files/build.sh`](./build_files/build.sh) | Installs packages, services, and dependencies |
| [`system_files/`](./system_files) | Files copied into the immutable image |
| [`vendor-backup/`](./vendor-backup) | Reference backup of the original Pantum configuration |
| [`image-template.env`](./image-template.env) | Image name, description, registry owner, and default tag |
| [`.github/workflows/build.yml`](./.github/workflows/build.yml) | Stable-release detection, build, publish, and signing workflow |
| [`cosign.pub`](./cosign.pub) | Public image-signing key |

## Implementation notes

Bazzite and Fedora bootable images may normally make `/opt` a symlink into mutable `/var`. Brave and the Pantum vendor payload store application files under `/opt`, so the Containerfile creates a real immutable `/opt` directory before applying the customizations.

The temporary COPR used for `libjpeg8` is disabled again after package installation.

## Upstream projects

This image is built from and depends on:

- [Bazzite](https://github.com/ublue-os/bazzite)
- [Universal Blue image-template](https://github.com/ublue-os/image-template)
- [bootc](https://github.com/bootc-dev/bootc)

Pantum driver files remain subject to the vendor's applicable terms. This repository is maintained for personal use and comes without warranty or official support from Bazzite, Universal Blue, Fedora, Pantum, or the other upstream projects.
