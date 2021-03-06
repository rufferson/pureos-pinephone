#!/bin/bash
set -ex

KERNEL_URL="https://xff.cz/kernels/5.11/pp.tar.gz"
CMD='wget -c '
if command -v curl ; then
CMD='curl -C - -O '
fi
$CMD $KERNEL_URL

ROOT=/you/must/override/this
if [ "x$1" != "x" ]; then
	ROOT=$1
fi

sudo tar xf pp.tar.gz --owner=0 --group=0 -C $ROOT/lib/modules --strip-components=4 --wildcards '*/lib/modules/*'
test -f $ROOT/boot/Image && sudo mv $ROOT/boot/Image $ROOT/boot/Image.old
sudo tar xf pp.tar.gz --owner=0 --group=0 -C $ROOT/boot --strip-components=1 --exclude=modules --exclude=headers 
sudo rm -rf $ROOT/usr/src/headers.old/
test -d $ROOT/usr/src/headers && sudo mv $ROOT/usr/src/headers $ROOT/usr/src/headers.old
sudo tar xf pp.tar.gz --owner=0 --group=0 -C $ROOT/usr/src/ --strip-components=1 --wildcards '*/headers/*'

sudo chown 0:0 -R $ROOT/boot/
sudo chown 0:0 -R $ROOT/lib/modules/
sudo chown 0:0 -R $ROOT/usr/src/headers/

rm pp.tar.gz
