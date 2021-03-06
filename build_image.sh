#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later

# If you want to recover runtime you may need to run the below commands
# sudo umount -R sd
# sudo cryptsetup close pureos-l5
# sudo losetup -d /dev/loop0
# sudo rm -rf ./ramfs/
# rm sd

set -ex

#GIT_URL_ATF='https://github.com/ARM-software/arm-trusted-firmware.git'
#GIT_URL_UBM='https://gitlab.denx.de/u-boot/u-boot.git'
GIT_URL_ATF='https://github.com/crust-firmware/arm-trusted-firmware.git'
#GIT_URL_ATF='https://megous.com/git/atf'
GIT_URL_UBM='https://megous.com/git/u-boot'
#GIT_URL_PBP='https://megous.com/git/p-boot'
#GIT_URL_UBP='https://gitlab.com/pine64-org/u-boot.git'
PINE_LINUX_REPO='https://gitlab.com/pine64-org/linux'
PINE_LINUX_BRANCH='pine64-kernel-5.5.y'

LIBREM5_CI='https://arm01.puri.sm/job/Images/job/Image%20Build/api/xml'
LIBREM5_IMG='librem5r4'
CI_FILTER="contains(description,%20%27$LIBREM5_IMG%20byzantium%27)%20and%20contains(result,%20%27SUCCESS%27)"

SYS_IMG="$LIBREM5_IMG.img"

KERNEL_URL='https://xff.cz/kernels/5.12/pp.tar.gz'

fetch_system() {
  LAST=$(curl -sg "$LIBREM5_CI?depth=1&xpath=//build[$CI_FILTER][1]/url[text()]" | sed 's/<[^>]\+>//g')
  IMG_URL="$LAST/artifact/$SYS_IMG.xz"
  rc=1
  while [ $rc -ne 0 ]; do
    if curl $IMG_URL -O -C -; then
      rc=0
    else
      rc=1
    fi
  done
}
fetch_kernel() {
  rc=1
  while [ $rc -ne 0 ]; do
      curl -O "$KERNEL_URL" -C -
      rc=$?
  done
  #curl "$PINE_LINUX_REPO/-/jobs/artifacts/$PINE_LINUX_BRANCH/download?job=build" > pine64-linux.zip
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
fetch_system &
fetch_kernel &

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
ROOT_DEV=${LO}p2

if sudo cryptsetup isLuks $ROOT_DEV
then
  echo -n 123456 > k
  sudo cryptsetup open $ROOT_DEV pureos-l5 -d k
  ROOT_DEV=/dev/mapper/pureos-l5
  rm -f k
fi
sudo mount $ROOT_DEV $MNT
sudo mount ${LO}p1 $MNT/boot

sudo tar xf pp.tar.gz -C $MNT/boot --strip-components=1 --exclude=modules --exclude=headers
sudo chown 0:0 -R $MNT/boot/
sudo tar xf pp.tar.gz -C $MNT/lib/modules --strip-components=4 --wildcards '*/lib/modules/*'
sudo chown 0:0 -R $MNT/lib/modules/
sudo tar xf pp.tar.gz -C $MNT/usr/src/ --strip-components=1 --wildcards '*/headers/*'
sudo chown 0:0 -R $MNT/usr/src/

#echo "setenv bootargs root=/dev/mmcblk0p2 rootwait console=ttyS0,115200 loglevel=7 panic=10
# Let ramfs handle the rootfs now
echo "setenv bootargs console=ttyS0,115200 loglevel=7 panic=10
load mmc 0:1 \$kernel_addr_r Image
load mmc 0:1 \$fdt_addr_r sun50i-a64-pinephone.dtb
load mmc 0:1 \$ramdisk_addr_r initrd.uimg &&
booti \$kernel_addr_r \$ramdisk_addr_r \$fdt_addr_r
#booti \$kernel_addr_r - \$fdt_addr_r" > boot.txt

#zcat sd/boot/initrd.img |  lz4 -zcl  > initrd.lz4
## Rebuild initrd to add required drivers
rm -rf ramfs
mkdir ramfs
cd ramfs
bsdtar xf ../sd/boot/initrd.img
# add swrast mesa driver
ln -s etnaviv_dri.so usr/lib/aarch64-linux-gnu/dri/kms_swrast_dri.so
# remove l5 kernel modules
rm -rf lib/modules/*-librem5
# add touchscreen driver instead
cd ../sd/
find lib/modules/ -path '*-librem5' -prune -o -name goodix.ko -print0 -o -name 'modules.*.bin' -print0 | bsdtar -cf - -T - --null | bsdtar -xf - -C ../ramfs/usr/
cd ../ramfs
#echo "insmod /$(find lib/modules/ -name goodix.ko -print -quit)" >> scripts/init-premount/plymouth
echo goodix > conf/modules
# repack initrd
find . -mindepth 1 -printf '%P\0' | sort -z | bsdtar --null -cnf - -T - --format=newc --gid=0 --uid=0 | lz4 -c9l > ../initrd.lz4
cd ..
sudo rm -rf ./ramfs

cd $MNT/boot
sudo mv boot.scr boot.scr.orig
sudo mkimage -A arm64 -T script -n pinephone -d ../../boot.txt boot.scr

# this does not work because: we need lz4, swrast and goodix, see above
#sudo mkimage -A arm64 -T ramdisk -n pinephone -d initrd.img initrd.uimg
sudo mkimage -A arm64 -T ramdisk -n pinephone -d ../../initrd.lz4 initrd.uimg -C lz4

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
if [ $ROOT_DEV = "/dev/mapper/pureos-l5" ]
then
  sudo cryptsetup close $ROOT_DEV
fi
sudo losetup -d $LO

[ "x$1" = "x" ] && rm $SYS_IMG.xz
rm u-boot-sunxi-with-spl.bin
rm boot.txt
rm -r sd
echo "Copy image $SYS_IMG to SD card with
dd if=$SYS_IMG of=/dev/sdX bs=16k
"
