#!/bin/bash
set -e
set -x

# Create target dir for build artefacts
WORKDIR=$PWD
BUILD_NR=${BUILD_NR:=$(date '+%Y%m%d-%H%M%S')}
BUILD_DEST=/builds/$BUILD_NR
mkdir -p $BUILD_DEST

# Get the Linux kernel 4.9 source
BRANCH=rpi-4.9.y
if [[ -d $LINUX ]]; then
  # update kernel repo
  cd $LINUX
  git pull
  git checkout $BRANCH
else
  # clone kernel repo
  git clone --single-branch --branch $BRANCH --depth 1 https://www.github.com/raspberrypi/linux $LINUX
  cd $LINUX
fi

# Compile Linux kernel
MAKE="make -j 8 ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE"

# Add kernel branding for HypriotOS
sed -i 's/^EXTRAVERSION =.*/EXTRAVERSION = -bee42/g' Makefile
export LOCALVERSION="" # suppress '+' sign in 4.9.2+

# Configure the kernel
$MAKE bcmrpi3_defconfig

# Get exact kernel version string
KR=$($MAKE kernelrelease | grep "^4")
echo "Kernel release= $KR"

# Copy kernel config for later reference
cp .config $BUILD_DEST/config-$KR

# Build the kernel and modules
$MAKE
$MAKE modules

# Install modules
INSTALLDIR=$WORKDIR/$KR
if [[ -d $INSTALLDIR ]]; then
  rm -fr $INSTALLDIR
  mkdir -p $INSTALLDIR
fi
$MAKE INSTALL_MOD_PATH=$INSTALLDIR modules_install
rm $INSTALLDIR/lib/modules/$KR/{build,source}

# Build kernel module dependencies
depmod -a -b $INSTALLDIR $KR

# Install kernel, dtb and overlays
mkdir -p $INSTALLDIR/boot/overlays
cp arch/arm64/boot/Image $INSTALLDIR/boot/kernel8.img
cp arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b.dtb $INSTALLDIR/boot/
cp arch/arm64/boot/dts/overlays/*.dtbo $INSTALLDIR/boot/overlays/

# Create tar file, all kernel files
TARFILE1=$KR.tar.gz
tar -cvzf $WORKDIR/$TARFILE1 -C $INSTALLDIR .
cd $WORKDIR
sha256sum $TARFILE1 > $TARFILE1.sha256

# Create tar file, only bootfiles
TARFILE2=bootfiles.tar.gz
tar -cvzf $WORKDIR/$TARFILE2 -C $INSTALLDIR/boot .
cd $WORKDIR
sha256sum $TARFILE2 > $TARFILE2.sha256

# Copy build artefacts
cp $TARFILE1* $BUILD_DEST/
cp $TARFILE2* $BUILD_DEST/

# List build artefacts
ls -al $BUILD_DEST/

