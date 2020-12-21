#!/bin/bash
#
set -ex

#GIT_URL_ATF='https://github.com/ARM-software/arm-trusted-firmware.git'
#GIT_URL_UBM='https://gitlab.denx.de/u-boot/u-boot.git'
GIT_URL_ATF='https://megous.com/git/atf'
GIT_URL_UBM='https://megous.com/git/u-boot'
#GIT_URL_PBP='https://megous.com/git/p-boot'
#GIT_URL_UBP='https://gitlab.com/pine64-org/u-boot.git'
PINE_LINUX_REPO='https://gitlab.com/pine64-org/linux'
PINE_LINUX_BRANCH='pine64-kernel-5.5.y'

LIBREM5_CI='https://arm01.puri.sm/job/Images/job/Image%20Build/api/xml'
LIBREM5_IMG='librem5r4'
CI_FILTER="contains(description,%20%27$LIBREM5_IMG%20byzantium%27)%20and%20contains(result,%20%27SUCCESS%27)"

SYS_IMG="$LIBREM5_IMG.img"

KERNEL_URL='https://xff.cz/kernels/5.10/pp.tar.gz'

fetch_system() {
  LAST=$(curl -sg "$LIBREM5_CI?depth=1&xpath=//build[$CI_FILTER][1]/url[text()]" | sed 's/<[^>]\+>//g')
  IMG_URL="$LAST/artifact/$SYS_IMG.xz"
  curl $IMG_URL -O -C - &
}
fetch_kernel() {
  curl -O "$KERNEL_URL" -C - &
  #curl "$PINE_LINUX_REPO/-/jobs/artifacts/$PINE_LINUX_BRANCH/download?job=build" > pine64-linux.zip &
  #unzip -d pine64-linux pine64-linux.zip
  #ar x $(ls -1 pine64-linux/linux-image-*_arm64.deb|grep -v dbg) data.tar.xz

}

build_uboot() {
  test -d atf && git -C atf pull || git clone --depth=1 $GIT_URL_ATF atf
  cd atf
  make CROSS_COMPILE=aarch64-linux-gnu- PLAT=sun50i_a64 DEBUG=1 bl31
  cd ..
  test -d u-boot && git -C u-boot pull || git clone $GIT_URL_UBM u-boot
  cd u-boot
  if [ "x$GIT_URL_UBP" != "x" ]; then
    git remote add pine64 $GIT_URL_UBP
    git pull -r pine64 master
  fi
  make CROSS_COMPILE=aarch64-linux-gnu- BL31=../atf/build/sun50i_a64/debug/bl31.bin pine64-lts_defconfig
  #make CROSS_COMPILE=aarch64-linux-gnu- BL31=../atf/build/sun50i_a64/debug/bl31.bin menuconfig
  make CROSS_COMPILE=aarch64-linux-gnu- BL31=../atf/build/sun50i_a64/debug/bl31.bin
  
  cp u-boot-sunxi-with-spl.bin ../
  cd ..
}

### START ###
fetch_system
fetch_kernel

if [ "x$UBOOT_BIN" = "x" ]
then
  build_uboot
fi

wait -f

xzcat $SYS_IMG.xz > $SYS_IMG
dd if=u-boot-sunxi-with-spl.bin of=$SYS_IMG bs=8k seek=1 conv=notrunc

# 
MNT=sd
test -d sd || mkdir sd
LO=`sudo losetup -f`
sudo losetup -P $LO $SYS_IMG
sudo mount ${LO}p2 $MNT
sudo mount ${LO}p1 $MNT/boot

sudo tar xf pp.tar.gz -C $MNT/boot --strip-components=1 --exclude=modules --exclude=headers
sudo chown 0:0 -R $MNT/boot/
sudo tar xf pp.tar.gz -C $MNT/lib/modules --strip-components=4 --wildcards '*/lib/modules/*'
sudo chown 0:0 -R $MNT/lib/modules/
sudo tar xf pp.tar.gz -C $MNT/usr/src/ --strip-components=1 --wildcards '*/headers/*'
sudo chown 0:0 -R $MNT/usr/src/

echo "setenv bootargs root=/dev/mmcblk0p2 rootwait console=ttyS0,115200 loglevel=7 panic=10
load mmc 0:1 \$kernel_addr_r Image
load mmc 0:1 \$fdt_addr_r sun50i-a64-pinephone.dtb
#load mmc 0:1 \$ramdisk_addr_r initrd.uimg &&
#booti \$kernel_addr_r \$ramdisk_addr_r \$fdt_addr_r
booti \$kernel_addr_r - \$fdt_addr_r" > boot.txt

cd $MNT/boot
sudo mv boot.scr boot.scr.orig
sudo mkimage -A arm64 -T script -n pinephone -d ../../boot.txt boot.scr
sudo ln -s board-1.1.dtb sun50i-a64-pinephone.dtb
cd ..

# Pin the kernel to avoid bricking on update
echo "Package: linux-image-librem5
Pin: version 5.*
Pin-Priority: -1

Package: linux-image-5.*-librem5
Pin: origin \"repo.pureos.net\"
Pin-Priority: -1" > ../pin-kernel.pref
sudo cp ../pin-kernel.pref etc/apt/preferences.d/

cd ..
sudo umount -R $MNT
sudo losetup -d $LO

[ "x$1" = "x" ] && rm $SYS_IMG.xz
rm u-boot-sunxi-with-spl.bin
rm boot.txt
rm -r sd
echo "Copy image $SYS_IMG to SD card with
dd if=$SYS_IMG of=/dev/sdX bs=16k
"
