#!/bin/bash

# merges the application into rootfs within root.ubi
# Usage:
# # ./fwmerge.sh merge_dir rootfs.ubi rootfs_app.ubi 
# merge_dir is a directory that contetnt will be copied on rootfs

function err() {
    msg="${1}"
    echo "ERROR: $msg" >&2
}

function checksu () {
    if [[ $(id -u) != 0 ]]; then 
        echo "ERROR: root permission are required"
        return 1
    fi
    return 0
}

function load_module () {
    modulename=${1}
    arguments=${2}
    modprobe ${modulename} nandsim first_id_byte=0xec second_id_byte=0xd3 third_id_byte=0x51 fourth_id_byte=0x95 >&2
    if [[ $? != 0 ]]; then
        err "failed load \"${modulename}\" module"
        return 2 
    fi
    return 0
}


function device_exists () {
    local dev="${1}"
    if [[ ! -c "${dev}" ]]; then
        err "device ${dev} does not exists"
        return 3
    fi
    return 0
}

function flash_image () {
    local dev="${1}"
    local retcode=0
    image=$(mktemp image.XXX )
    if [[ $? == 0 ]]; then
        cat >"${image}"
        if [[ $? == 0 ]]; then
            ubiformat "${dev}" -O 2048 -y -e 0 -f "${image}" >&2 || retcode=$?
            if [[ $retcode != 0 ]]; then
                err "failed to flash ubi image \"${image}\" on device ${dev}"
            fi
        fi
        rm -f "${image}"
    fi
    return $retcode
}

function attach () {
    local dev="${1}"
    ubiattach -p "${dev}" -O 2048 >&2
    if [[ $? != 0 ]]; then
        err "failed to attach ubi device \"${dev}\""
        return 6
    fi
    return 0
}

function create_mnt_point () {
    local mnt_point="${1}"
    mkdir -p "${mnt_point}"
    if [[ $? != 0  ]]; then
        err "failed to create mount point directory \"${mnt_point}\""
        return 7
    fi
    return 0
}

function mount_ubi () {
    local dev="${1}"
    local mnt="${2}"
    mount -t ubifs "${dev}" "${mnt}"
    if [[ $? != 0 ]]; then
       err "failed to mount ${dev} on mount point ${mnt}"
       retrun 8
    fi
    return 0
}

function merge_fs () {
    local merge_dir="${1}"
    local target_dir="${2}"
    cp -a -f "${merge_dir}/"* "${target_dir}/"
    if [[ $? != 0 ]]; then
        err "failed to merge directory \"${merge_dir}\" to \"${target_dir}\""
        return 9
    fi
    return 0
}

function create_ubi_image () {
    local dir="${1}"
    local UbiImage="${2}"
    local retcode=0
    local ubifs_file=$(mktemp ubifs.XXX)
    mkfs.ubifs  -d "${dir}" -e 0x1f000 -c 2048 -m 0x800 -x lzo -o "${ubifs_file}" || retcode=$?
    if [[ ${retcode} == 0 ]]; then
        ubinize -o "${UbiImage}" -m 0x800 -p 0x20000 -s 2048 <( \
	echo "[ubifs]"; \
	echo "mode=ubi"; \
	echo "vol_id=0"; \
	echo "vol_type=dynamic"; \
	echo "vol_name=rootfs"; \
	echo "vol_alignment=1"; \
	echo "vol_flags=autoresize"; \
	echo "image=${ubifs_file}"; ) || retcode=$?
        if [[ ${retcode} == 0 ]];then
            # image fertig
            echo "image created ${UbiImage}" >&2
        else
            err "failed to ubinize ${ubifs_file} to ${ubi_file}"
            rm -f "${UbiImage}"
            return 11
        fi
        
        rm -f "${ubifs_file}"
    else
        err "failed to create ubifs image \"${image}fs\""
        return 10
    fi
    return 0
}

function merge_ubi () {
    local UbiImage="${1}"
    load_module nandsim first_id_byte=0xec second_id_byte=0xd3 third_id_byte=0x51 fourth_id_byte=0x95 || exit $?
    load_module ubi || exit $?
    load_module ubifs || exit $?
    local nandsim=$(grep "NAND simulator partition" /proc/mtd) ; 
    local mtddev="/dev/$( expr match "${nandsim}" '\(mtd[0-9]\+\)')"
    local ubidev="/dev/ubi$(expr match \"${mtddev}\" '.*\([0-9]\+\)')"
    local retcode=0
    device_exists "${mtddev}" || return $?
    flash_image "${mtddev}" || return $?
    attach "${mtddev}" || return $?
    device_exists "${ubidev}" || retcode=$? 
    if [[ ${retcode} == 0 ]]; then
        MNT_POINT=$(mktemp -d filesystem.XXX )
        create_mnt_point "${MNT_POINT}" || retcode=$?
        if [[ ${retcode} == 0 ]]; then
            mount_ubi "${ubidev}_0" "${MNT_POINT}" || retcode=$? 
            if [[ ${retcode} == 0 ]]; then
                merge_fs  "${MERGE_DIR}" "${MNT_POINT}" || retcode=$?
                if [[ ${retcode} == 0 ]]; then
                    create_ubi_image "${MNT_POINT}" "${UbiImage}" || retcode=$?
                fi
                umount "${ubidev}_0"
            fi
            rm -rf "${MNT_POINT}"
        fi
    fi

    ubidetach -p "${mtddev}"
    return ${retcode}
}   

checksu

MERGE_DIR="${1}"
if [[ ! -d ${MERGE_DIR} ]]; then
    err "failed to find the merge directory \"${MERGE_DIR}\""
    exit 21
fi

ROOTFS="${2}"
if [[ ! -f ${ROOTFS} ]]; then
    err "failed to find the rootfs ubi image \"${ROOTFS}\""
    exit 22
fi

ROOTFSAPP="${3}"
if [[ -f ${ROOTFSAPP} ]]; then
    echo "target file '$ROOTFSAPP' exists already"
    read -p "would you like to overwrite it? (Y/N)" -n 1 -r
    echo
    if [ "${REPLY}" != "y" -a "${REPLY}" != "Y" ]; then   
        exit 24
    fi
fi

echo ">>>>>> RootFS merge <<<<<<<<" >&2
COUNT=$(stat -c '%s' "${ROOTFS}")
echo "COUNT=${COUNT}"
dd if="${ROOTFS}" bs=1 count=${COUNT} | merge_ubi "${ROOTFSAPP}" # 2>/dev/null
if [[ ${PIPESTATUS[0]} != 0 || ${PIPESTATUS[1]} != 0 ]]; then
    err "failed to merge"
    exit 20
fi

