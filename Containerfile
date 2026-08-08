# GitHub Actions normally replaces this moving tag with the exact digest that
# it inspected before the build. Local builds may keep the default.
ARG BLUEFIN_IMAGE=ghcr.io/ublue-os/bluefin-nvidia-open:stable

# Make build scripts and system files available without leaving them as a
# separate repository directory in the finished image.
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files
COPY cosign.pub /cosign.pub

# Current plain Bluefin NVIDIA Open workstation image.
FROM ${BLUEFIN_IMAGE}

# Bluefin/Fedora bootable images may make /opt a symlink into mutable /var.
# Brave and the Pantum vendor driver contain application files under /opt, so
# keep /opt inside the immutable image.
RUN if [ -L /opt ]; then rm /opt && mkdir -p /opt; fi

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
