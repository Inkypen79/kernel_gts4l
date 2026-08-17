#!/usr/bin/env bash
set -Eeuxo pipefail

KERN="$HOME/KernelTabS4OneUI3.1"
TOOLCHAIN="$HOME/toolchains/aarch64-linux-android-4.9"
OUT="$KERN/out"
WETA="$KERN/WETA"
TODAY="$(date '+%Y-%m-%d.%H-%M')"
JOBS="$(nproc)"

export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE="$TOOLCHAIN/bin/aarch64-linux-android-"
export PATH="$KERN/tools:$TOOLCHAIN/bin:$PATH"


# Ensure the legacy Android GCC toolchain is present and executable.
if [[ ! -x "${CROSS_COMPILE}gcc" ]]; then
    echo "ERROR: GCC compiler is missing:"
    echo "  expected: ${CROSS_COMPILE}gcc"
    echo "  found in bin/:"
    ls -lah "${TOOLCHAIN}/bin"
    exit 1
fi

"${CROSS_COMPILE}gcc" --version
cd "$KERN"

# Use -p: succeeds whether out/ already exists or not.
mkdir -p "$OUT" "$WETA/old"

cd ~/KernelTabS4OneUI3.1
mkdir -p out/firmware
ln -sfn ../../firmware/epen out/firmware/epen

# Configure then compile.
make O="$OUT" \
  CROSS_COMPILE="$CROSS_COMPILE" \
  KCFLAGS="-mno-android" \
  gts4llte_eur_open_defconfig

make -j"$JOBS" O="$OUT" \
  CROSS_COMPILE="$CROSS_COMPILE" \
  KCFLAGS="-mno-android"

# Fail immediately if the expected build artifact was not created.
IMAGE_GZ_DTB="$OUT/arch/arm64/boot/Image.gz-dtb"
[[ -f "$IMAGE_GZ_DTB" ]] || {
  echo "Build succeeded but expected image is missing: $IMAGE_GZ_DTB" >&2
  exit 1
}

# Keep copies used by your existing WETA packaging setup.
[[ -f "$OUT/arch/arm64/boot/Image" ]] && \
  cp -f "$OUT/arch/arm64/boot/Image" "$KERN/arch/arm64/boot/Image"

[[ -f "$OUT/arch/arm64/boot/Image.gz" ]] && \
  cp -f "$OUT/arch/arm64/boot/Image.gz" "$WETA/Image.gz"

cp -f "$IMAGE_GZ_DTB" "$WETA/Image.gz-dtb"

echo
echo "###########################################"
echo "# Building flashable AnyKernel ZIP         #"
echo "###########################################"

shopt -s nullglob
old_zips=("$WETA"/WETA_Kernel*.zip)
(( ${#old_zips[@]} )) && mv "${old_zips[@]}" "$WETA/old/"

cp -f "$IMAGE_GZ_DTB" "$WETA/weta_anykernel/zImage"

(
  cd "$WETA/weta_anykernel"
  zip -r9 "$WETA/WETA_Kernel_$TODAY.zip" .
)

echo
echo "###########################################"
echo "# Building boot.img                        #"
echo "###########################################"

old_imgs=("$WETA"/weta_boot_*.img)
(( ${#old_imgs[@]} )) && mv "${old_imgs[@]}" "$WETA/old/"

(
  cd "$WETA/AIK"
  ./unpackimg.sh
  cp -f "$IMAGE_GZ_DTB" ./split_img/boot.img-zImage
  ./repackimg.sh
  mv -f ./image-new.img "$WETA/weta_boot_$TODAY.img"
  ./cleanup.sh
)

echo
echo "###########################################"
echo "# Done                                      #"
echo "# ZIP: $WETA/WETA_Kernel_$TODAY.zip"
echo "# IMG: $WETA/weta_boot_$TODAY.img"
echo "###########################################"