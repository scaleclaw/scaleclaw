# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bluefin:stable

## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

# Ensure proper Scaleclaw naming by bringing in an edited 00-image-info.sh
ARG IMAGE_NAME="scaleclaw"
ARG IMAGE_VENDOR="scaleclaw"
ARG UBLUE_IMAGE_TAG="latest"
ARG BASE_IMAGE_NAME="bluefin"
ARG FEDORA_MAJOR_VERSION="44"
# We do not need the extra --mount=type arguments for this script
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    bash /ctx/00-image-info.sh

# SCALECLAW BRANDING; run after build.sh to make sure branding is always on the top "layer"
COPY /system_files/bluefin/usr /usr
COPY /system_files/bluefin/etc /etc

# Enforce/override zz0-bluefin-modifications.gschema and 04-bluefin-logomenu-extension
RUN glib-compile-schemas /usr/share/glib-2.0/schemas
RUN dconf update

#re-generate initramfs to fix logos not being replaced on startup
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    bash /ctx/19-initramfs.sh

# attempt to brand installer; taken from https://github.com/projectbluefin/iso
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/configure_iso_anaconda.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
