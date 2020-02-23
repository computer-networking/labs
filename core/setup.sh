#!/usr/bin/env bash

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

LIBRARY_PATH=/var/lib/container_labs
IMAGES_PATH="${LIBRARY_PATH}/images"
CONTAINERS_PATH="${LIBRARY_PATH}/container"
IMAGE_REPOSITORY_BASE="https://github.com/computer-networking/labs/raw/master/core/images"
ALPINE_IMAGE="alpine_3.10.0.tar"
DEFAULT_IMAGE="${ALPINE_IMAGE}"

###############################################################################
# Helpers
###############################################################################

function output::error () {
    declare error_description="${1:?Missing error description}"
    echo -e "\e[91mERROR: ${error_description}\e[0m"
}

function output::error_and_die () {
    declare error_description="${1:?Missing error description}"
    declare return_status="${2:-1}"
    output::error "$error_description"
    exit "$return_status"
}

function output::info () {
    declare error_description="${1:?Missing ingo description}"
    echo "INFO: ${error_description}"
}

function output::ok () {
    declare error_description="${1:?Missing ingo description}"
    echo -e "\e[32mOK: ${error_description}\e[0m"
}

###############################################################################
# Setup
###############################################################################

function setup::prepare_folders () {
    for path in "${LIBRARY_PATH}" "${IMAGES_PATH}" "${CONTAINERS_PATH}" ; do
        mkdir -p "$path"
        chmod -R 700 "$path"
        output::info "Generated $path"
    done
}

###############################################################################
# Image management
###############################################################################

function image::download () {
    declare archived_image="${1:-$DEFAULT_IMAGE}"
    declare image="${archived_image:0:-4}"
    declare image_path="${IMAGES_PATH}/${image}"

    mkdir -p "$image_path"
    curl -L "${IMAGE_REPOSITORY_BASE}/${archived_image}" | tar -C "${image_path}/" -xf-

    output::ok "Image $image downloaded into $image_path"
}

function image::remove () {
    declare archived_image="${1:-$DEFAULT_IMAGE}"
    declare image="${archived_image:0:-4}"
    declare image_path="${IMAGES_PATH:?}/${image}"

    if [[ "$image_path" = $IMAGES_PATH* ]] ; then
        echo "rm -rf ${image_path:?}"
    else
        output::error_and_die "Image to remove not stored in the expected path \"${image_path}\""
    fi
}

###############################################################################
# Container management
###############################################################################

function container::generate_storage () {
    declare archived_image="${1:-$DEFAULT_IMAGE}"
    declare image="${archived_image:0:-4}"
    declare image_path="${IMAGES_PATH:?}/${image}"
    declare container_name="${2:-$(uuidgen)}"
    declare container_path="${CONTAINERS_PATH:?}/${container_name}"

    # 1- Ignore if the mount already exists
    if grep -qs "${container_path}/merged" /proc/mounts ; then
        return 0;
    fi

    # 2- Create overlayFS mount directories
    mkdir -p $container_path/{diff,merged,work}

    # 3- Mount the image
    mount -t overlay overlay -o lowerdir="$image_path",upperdir="${container_path}/diff",workdir="${container_path}/work" "${container_path}/merged"
}

function container::remove_storage () {
    declare archived_image="${1:-$DEFAULT_IMAGE}"
    declare image="${archived_image:0:-4}"
    declare image_path="${IMAGES_PATH:?}/${image}"
    declare container_name="${2?Missing 2nd argument container name}"
    declare container_path="${CONTAINERS_PATH:?}/${container_name}"

    # 1- umount the storage
    if grep -qs "${container_path}/merged" /proc/mounts ; then
        umount "${container_path}/merged"
    fi

    # 2- Remove content
    if [[ "$container_path" = $CONTAINERS_PATH* ]] ; then
        rm -rf "${container_path:?}"
    else
        output::error_and_die "Container storage to remove not stored in the expected path \"${container_path}\""
    fi
}

###############################################################################

# Work in progress..
setup::prepare_folders
image::download
image::remove
