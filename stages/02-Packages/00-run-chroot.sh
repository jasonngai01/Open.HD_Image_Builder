# This runs in context if the image (CHROOT)
# Any native compilation can be done here
# Do not use log here, it will end up in the image

#!/bin/bash
if [[ "${OS}" != "ubuntu" ]]; then
    # Remove bad and unnecessary symlinks if system is not ubuntu
    rm /lib/modules/*/build || true
    rm /lib/modules/*/source || true
fi


if [ "${APT_CACHER_NG_ENABLED}" == "true" ]; then
    echo "Acquire::http::Proxy \"${APT_CACHER_NG_URL}/\";" >> /etc/apt/apt.conf.d/10cache
fi

if [[ "${OS}" == "raspbian" ]]; then
    echo "OS is raspbian"
    rm /boot/config.txt
    rm /boot/cmdline.txt
    apt-mark hold firmware-atheros || exit 1
    apt purge firmware-atheros || exit 1
    apt -yq install firmware-misc-nonfree || exit 1
    apt-mark hold raspberrypi-kernel
    # Install libraspberrypi-dev before apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get -yq install libraspberrypi-doc libraspberrypi-dev libraspberrypi-dev libraspberrypi-bin libraspberrypi0 || exit 1
    apt-mark hold libraspberrypi-dev libraspberrypi-bin libraspberrypi0 libraspberrypi-doc
    apt purge raspberrypi-kernel
    PLATFORM_PACKAGES=""
fi


if [[ "${OS}" == "armbian" ]]; then
    echo "OS is armbian"
    PLATFORM_PACKAGES=""
fi


if [[ "${OS}" == "ubuntu" ]]; then
    echo "OS is ubuntu"
    PLATFORM_PACKAGES=""

    echo "-------------------------SHOW nvideo source list-------------------------------"
    #it appears some variable for source list gets missed when building images like this.. 
    #by deleting and rewriting source list entry it fixes it.
    rm /etc/apt/sources.list.d/nvidia-l4t-apt-source.list || true
    echo "deb https://repo.download.nvidia.com/jetson/common r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source2.list
    echo "deb https://repo.download.nvidia.com/jetson/t210 r32.6 main" > /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
    sudo cat /etc/apt/sources.list.d/nvidia-l4t-apt-source.list

    #remove some nvidia packages... if building from nvidia base image
    sudo apt remove ubuntu-desktop
    sudo apt remove libreoffice-writer chromium-browser chromium* yelp unity thunderbird rhythmbox nautilus gnome-software
    sudo apt remove ubuntu-artwork ubuntu-sounds ubuntu-wallpapers ubuntu-wallpapers-bionic
    sudo apt remove vlc-data gdm
    sudo apt remove unity-settings-daemon packagekit wamerican mysql-common libgdm1
    sudo apt remove ubuntu-release-upgrader-gtk ubuntu-web-launchers
    sudo apt remove --purge libreoffice*
    gnome-applet* gnome-bluetooth gnome-desktop* gnome-sessio* gnome-user* gnome-shell-common gnome-control-center gnome-screenshot
    sudo apt autoremove
    #appears redundandt as update is called twice below
    #sudo apt-get update -y 


fi


if [[ "${HAS_CUSTOM_KERNEL}" == "true" ]]; then
    echo "-----------------------has a custom kernel----------------------------------"
    PLATFORM_PACKAGES="${PLATFORM_PACKAGES} ${KERNEL_PACKAGE}"
fi

#echo "-------------------------SHOW sources content-------------------------------"

#sudo cat /etc/apt/sources.list
#sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak

echo "-------------------------GETTING FIRST UPDATE------------------------------------"

apt-get update --allow-releaseinfo-change || exit 1  

echo "-------------------------DONE GETTING FIRST UPDATE-------------------------------"

apt-get install -y apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1/cfg/gpg/gpg.0AD501344F75A993.key' | apt-key add -
curl -1sLf 'https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/cfg/gpg/gpg.58A6C96C088A96BF.key' | apt-key add -


echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1.list

if [[ "${TESTING}" == "testing" ]]; then
    echo "deb https://dl.cloudsmith.io/public/openhd/openhd-2-1-testing/deb/${OS} ${DISTRO} main" > /etc/apt/sources.list.d/openhd-2-1-testing.list
fi

echo "-------------------------GETTING SECOND UPDATE------------------------------------"

apt-get update --allow-releaseinfo-change || exit 1

echo "-------------------------DONE GETTING SECOND UPDATE------------------------------------"

echo "Purge packages that interfer/we dont need..."

PURGE="wireless-regdb crda cron avahi-daemon cifs-utils curl iptables triggerhappy man-db dphys-swapfile logrotate"

echo "install openhd version-${OPENHD_PACKAGE}"
if [[ "${OS}" == "ubuntu" ]]; then
    echo "install some Jetson essential apps and rtl8812au driver from sources"
    sudo apt install -y git nano python-pip jtop build-essential libelf-dev
    pip install -U jetson-stats
    sudo apt-get install linux-headers-`uname -r`
    sudo cd ../../ && git clone https://github.com/svpcom/rtl8812au.git
    cd rtl* && make && make install
    cp -r /rtl8812au/88XXau_wfb.ko /lib/modules/4.9.253-tegra/kernel/drivers/net/wireless/realtek/rtl8812au/
    mv /lib/modules/4.9.253-tegra/kernel/drivers/net/wireless/realtek/rtl8812au/rtl8812au.ko /lib/modules/4.9.253-tegra/kernel/drivers/net/wireless/realtek/rtl8812au/rtl8812au.ko.bak
fi

DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install \
${OPENHD_PACKAGE} \
${PLATFORM_PACKAGES} \
${GNUPLOT} || exit 1

DEBIAN_FRONTEND=noninteractive apt-get -yq purge ${PURGE} || exit 1

DEBIAN_FRONTEND=noninteractive apt-get -yq clean || exit 1
DEBIAN_FRONTEND=noninteractive apt-get -yq autoremove || exit 1

if [ ${APT_CACHER_NG_ENABLED} == "true" ]; then
    rm /etc/apt/apt.conf.d/10cache
fi


MNT_DIR="${STAGE_WORK_DIR}/mnt"

#
# Write the openhd package version back to the base of the image and
# in the work dir so the builder can use it in the image name
export OPENHD_VERSION=$(dpkg -s openhd | grep "^Version" | awk '{ print $2 }')

echo ${OPENHD_VERSION} > /openhd_version.txt
echo ${OPENHD_VERSION} > /boot/openhd_version.txt
