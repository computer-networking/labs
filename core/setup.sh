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

function container::create_container () {
    declare container_name="${1?Missing 1st argument container name}"
    declare container_path="${CONTAINERS_PATH:?}/${container_name}"

    # 1- Protect the main parent namespace from receiving unwanted mount events
    mount --make-rprivate /

    # 2- Creaate the network namespace to be managed by IP(8)
    ip netns add "$container_name"

    # 2- Create the new namespaces
    ip netns exec "$container_name" bash -l -c '''
        unshare --mount --uts --ipc --pid --fork bash -l -c """

        # 3- Change the process root directory
        cd ${container_path}/merged
        mkdir oldroot
        pivot_root . oldroot
        cd /
        export PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/sbin

        # 4- Unmount unused mounts
        umount -l /oldroot # --lazy
        umount -a

        # 5- Load regular mounts
        mount -t proc proc proc/
        mount -t sysfs sys sys/
        mount -o bind /dev dev/

        # 6- Replace the process bash image with a process inside the container
        exec chroot / sh
        """
    '''
}

function container::remove_container () {
    declare container_name="${1?Missing 1st argument container name}"
    declare container_path="${CONTAINERS_PATH:?}/${container_name}"

    # 1- TODO: Check how to track and finish processes inside it.

    # 2- Remove the network namespace
    ip netns del "$container_name"
}
