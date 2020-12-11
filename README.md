# pureos-pinephone

While building and testing I've noticed the purism's build server very frequently (almost always) aborts download prematurely - perhaps they put some protection against abuse, dunno, so I've made the script to try to continue download if the file already exists. In addition to that, to be able to tinker with the image if you add anything after the script (eg. ./build_image 1) it will also preserve original pureos image archive so that you can re-extract and do whatever you want with it.

Also to pretend it's more complex than it really is the script runs in a verbose/debug/tracing/-x mode so you can see where it fails (if it does). Although because initial time consuming tasks (build and image download) are running as background tasks in parallel - it might be very tough to understand where it actually failed (eg download may fail while build is still running and you see error only after build finished).

```
...
  LD      spl/drivers/power/built-in.o
  LD      spl/drivers/power/pmic/built-in.o
  LD      spl/drivers/power/regulator/built-in.o
  CC      spl/drivers/serial/serial.o
  CC      spl/drivers/serial/serial_ns16550.o
  CC      spl/drivers/serial/ns16550.o
  LD      spl/drivers/serial/built-in.o
  LD      spl/drivers/soc/built-in.o
  LD      spl/drivers/built-in.o
  LD      spl/dts/built-in.o
  CC      spl/fs/fs_internal.o
  LD      spl/fs/built-in.o
  LDS     spl/u-boot-spl.lds
  LD      spl/u-boot-spl
  OBJCOPY spl/u-boot-spl-nodtb.bin
  COPY    spl/u-boot-spl.bin
  MKSUNXI spl/sunxi-spl.bin
  MKIMAGE u-boot.img
  COPY    u-boot.dtb
  MKIMAGE u-boot-dtb.img
./"board/sunxi/mksunxi_fit_atf.sh" \
arch/arm/dts/sun50i-a64-pine64-lts.dtb > u-boot.its
  MKIMAGE u-boot.itb
  CAT     u-boot-sunxi-with-spl.bin
===================== WARNING ======================
This board uses CONFIG_SPL_FIT_GENERATOR. Please migrate
to binman instead, to avoid the proliferation of
arch-specific scripts with no tests.
====================================================
  CFGCHK  u-boot.cfg
+ cp u-boot-sunxi-with-spl.bin ../
+ cd ..
+ wait -f
+ xzcat librem5r3.img.xz
xzcat: librem5r3.img.xz: Unerwartetes Ende der Eingabe
```

Here you can see build has finished, then script resumed sequential execution and failed at unpacking the image. After this kind of error you just need to re-execute the script and it will continue downloading the pureos image while partially rebuilding the u-boot.

```
$ ./build_image.sh 
+ GIT_URL_ATF=https://megous.com/git/atf
+ GIT_URL_UBM=https://megous.com/git/u-boot
+ PINE_LINUX_REPO=https://gitlab.com/pine64-org/linux
+ PINE_LINUX_BRANCH=pine64-kernel-5.5.y
+ LIBREM5_CI=https://arm01.puri.sm/job/Images/job/Image%20Build/api/xml
+ LIBREM5_IMG=librem5r3
+ CI_FILTER='contains(description,%20%27librem5r3%27)%20and%20contains(result,\
	%20%27SUCCESS%27)'
+ SYS_IMG=librem5r3.img
+ KERNEL_URL=https://xff.cz/kernels/5.9/pp.tar.gz
+ fetch_system
++ curl -sg 'https://arm01.puri.sm/job/Images/job/Image%20Build/api/xml?depth=1&...
++ sed 's/<<[^>]\+>//g'
+ LAST=https://arm01.puri.sm/job/Images/job/Image%20Build/6058/
+ IMG_URL=https://arm01.puri.sm/job/Images/job/Image%20Build/6058//artifact/\
	librem5r3.img.xz
+ fetch_kernel
+ curl https://arm01.puri.sm/job/Images/job/Image%20Build/6058//artifact/\
	librem5r3.img.xz -O -C -
+ '[' x = x ']'
+ build_uboot
+ curl -O https://xff.cz/kernels/5.9/pp.tar.gz -C -
+ test -d atf
+ git -C atf pull
** Resuming transfer from byte position 220252415
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
** Resuming transfer from byte position 13343754
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   190  100   190    0     0    524      0 --:--:-- --:--:-- --:--:--   524
Bereits aktuell.
+ cd atf
+ make CROSS_COMPILE=aarch64-linux-gnu- PLAT=sun50i_a64 DEBUG=1 bl31

...

+ wait -f
100  647M  100  647M    0     0  3038k      0  0:03:38  0:03:38 --:--:-- 3019k
+ xzcat librem5r3.img.xz
+ dd if=u-boot-sunxi-with-spl.bin of=librem5r3.img bs=8k seek=1 conv=notrunc
86+1 Datensätze ein
86+1 Datensätze aus
707804 Bytes (708 kB, 691 KiB) kopiert, 0,00577333 s, 123 MB/s
+ MNT=sd
+ test -d sd
+ mkdir sd
++ losetup -f
+ LO=/dev/loop1
+ sudo losetup -P /dev/loop1 librem5r3.img
[sudo] Passwort für ruff: 
+ sudo mount /dev/loop1p2 sd
+ sudo mount /dev/loop1p1 sd/boot
+ sudo tar xf pp.tar.gz -C sd/boot --strip-components=1 --exclude=modules \
	--exclude=headers
+ sudo tar xf pp.tar.gz -C sd/lib/modules --strip-components=4 --wildcards \
	'*/lib/modules/*'
+ sudo tar xf pp.tar.gz -C sd/usr/src/ --strip-components=1 --wildcards '*/headers/*'
+ echo 'setenv bootargs root=/dev/mmcblk0p2 rootwait console=ttyS0,115200 loglevel=7 \
	panic=10
load mmc 0:1 $kernel_addr_r Image
load mmc 0:1 $fdt_addr_r sun50i-a64-pinephone.dtb
#load mmc 0:1 $ramdisk_addr_r initrd.uimg &&
#booti $kernel_addr_r $ramdisk_addr_r $fdt_addr_r
booti $kernel_addr_r - $fdt_addr_r'
+ cd sd/boot
+ sudo mv boot.scr boot.scr.orig
+ sudo mkimage -A arm64 -T script -n pinephone -d ../../boot.txt boot.scr
Image Name:   pinephone
Created:      Thu Dec 10 21:17:56 2020
Image Type:   AArch64 Linux Script (gzip compressed)
Data Size:    308 Bytes = 0.30 KiB = 0.00 MiB
Load Address: 00000000
Entry Point:  00000000
Contents:
   Image 0: 300 Bytes = 0.29 KiB = 0.00 MiB
+ sudo ln -s board-1.1.dtb sun50i-a64-pinephone.dtb
+ cd ../..
+ sudo umount -R sd
+ sudo losetup -d /dev/loop1
+ '[' x = x ']'
+ rm librem5r3.img.xz
+ rm u-boot-sunxi-with-spl.bin
+ rm boot.txt
+ rm -r sd
+ echo 'Copy image librem5r3.img to SD card with
dd if=librem5r3.img of=/dev/sdX bs=16k
'
Copy image librem5r3.img to SD card with
dd if=librem5r3.img of=/dev/sdX bs=16k
```

This is how script succeeds.
