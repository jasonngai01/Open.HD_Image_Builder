# Do this to the WORK folder of this stage
pushd ${STAGE_WORK_DIR}

cp ${STAGE_WORK_DIR}/mnt/openhd_version.txt ${WORK_DIR}/openhd_version.txt


MNT_DIR="${STAGE_WORK_DIR}/mnt"

# Rename the DOS partition
BOOT_MNT_DIR="${STAGE_WORK_DIR}/mnt/boot"
BOOT_LOOP_DEV="$(findmnt -nr -o source $BOOT_MNT_DIR)"

fatlabel "$BOOT_LOOP_DEV" "OPENHD"

if [[ "${DISTRO}" == "buster" ]]; then

echo "
[all]
dtoverlay=vc4-fkms-v3d
" >> ${BOOT_MNT_DIR}/config.txt

fi

#return
popd
