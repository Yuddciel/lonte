#!/usr/bin/env bash
#
# Copyright (C) 2023 Edwiin Kusuma Jaya (ryuzenn)
#
# Simple Local Kernel Build Script
#
# Configured for Poco x3 NFC / Surya custom kernel source
#
# Setup build env with akhilnarang/scripts repo
#
# Use this script on root of kernel directory

SECONDS=0 # builtin bash timer
LOCAL_DIR=/workspace/Yuddciel/
ZIPNAME="HyperOS:[HiraTeam]-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"
TC_DIR="${LOCAL_DIR}toolchain"
CLANG_DIR="${TC_DIR}/clang-rastamod"
GCC_64_DIR="${LOCAL_DIR}toolchain/aarch64-linux-android-4.9"
GCC_32_DIR="${LOCAL_DIR}toolchain/arm-linux-androideabi-4.9"
AK3_DIR="${LOCAL_DIR}/AnyKernel3"
DEFCONFIG="surya_defconfig"

export PATH="$CLANG_DIR/bin:$PATH"
export KBUILD_BUILD_USER="Mahirooo"
export KBUILD_BUILD_HOST="hirateam"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_BUILD_VERSION="1"
export LOCALVERSION

if ! [ -d "${CLANG_DIR}" ]; then
echo "Clang not found! Cloning to ${TC_DIR}..."
if ! git clone --depth=1 -b clang-21.0 https://gitlab.com/kutemeikito/rastamod69-clang ${CLANG_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if ! [ -d "${GCC_64_DIR}" ]; then
echo "gcc not found! Cloning to ${GCC_64_DIR}..."
if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${GCC_64_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if ! [ -d "${GCC_32_DIR}" ]; then
echo "gcc_32 not found! Cloning to ${GCC_32_DIR}..."
if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${GCC_32_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

# Repo info
PARSE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
PARSE_ORIGIN="$(git config --get remote.origin.url)"
COMMIT_POINT="$(git log --pretty=format:'%h : %s' -1)"
CHEAD="$(git rev-parse --short HEAD)"
LATEST_COMMIT="[$COMMIT_POINT](https://github.com/Yuddciel/lonte/commit/$CHEAD)"

# Telegram
CHATID="-1001156668998" # Group/channel chatid (use rose/userbot to get it)
TELEGRAM_TOKEN="${TG_TOKEN}"

# Export Telegram.sh
TELEGRAM_FOLDER="${HOME}"/telegram
if ! [ -d "${TELEGRAM_FOLDER}" ]; then
    git clone https://github.com/fabianonline/telegram.sh/ "${TELEGRAM_FOLDER}"
fi

TELEGRAM="${TELEGRAM_FOLDER}"/telegram
tg_cast() {
	curl -s -X POST https://api.telegram.org/bot"$TELEGRAM_TOKEN"/sendMessage -d disable_web_page_preview="true" -d chat_id="$CHATID" -d "parse_mode=MARKDOWN" -d text="$(
		for POST in "${@}"; do
			echo "${POST}"
		done
	)" &> /dev/null
}
tg_ship() {
    "${TELEGRAM}" -f "${ZIPNAME}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -H \
    "$(
                for POST in "${@}"; do
                        echo "${POST}"
                done
    )"
}
tg_fail() {
    "${TELEGRAM}" -f "${LOGS}" -t "${TELEGRAM_TOKEN}" -c "${CHATID}" -H \
    "$(
                for POST in "${@}"; do
                        echo "${POST}"
                done
    )"
}

# Versioning
versioning() {
    TMP=$(cat arch/arm64/configs/${DEFCONFIG} | grep CONFIG_LOCALVERSION= | tr '[' '+' )
    DEF=$(echo $TMP | sed 's/-SiLonT:+//g' | sed 's/]//g' | sed 's/"//g' | sed 's/CONFIG_LOCALVERSION/KERNELTYPE/g')
    export $DEF
}

# Patch Defconfig
patch_config() {
    sed -i "s/${KERNELTYPE}/${KERNELTYPE}-TEST/g" "${KERNEL_DIR}/arch/arm64/configs/${DEFCONFIG}"
    sed -i 's/CONFIG_THINLTO=y/CONFIG_THINLTO=n/g' arch/arm64/configs/"${DEFCONFIG}"
    sed -i 's/# CONFIG_LOCALVERSION_AUTO is not set/CONFIG_LOCALVERSION_AUTO=y/g' arch/arm64/configs/"${DEFCONFIG}"
    sed -i 's/# CONFIG_LOCALVERSION_BRANCH_SHA is not set/CONFIG_LOCALVERSION_AUTO=y/g' arch/arm64/configs/"${DEFCONFIG}"
}

# Costumize
patch_config
versioning
KERNEL="[TEST]-SiLonT"
DEVICE="Surya"
KERNELNAME="${KERNEL}-${DEVICE}-${KERNELTYPE}-$(date +%y%m%d-%H%M)"
TEMPZIPNAME="${KERNELNAME}-unsigned.zip"
ZIPNAME="${KERNELNAME}.zip"

# Regenerating Defconfig
regenerate() {
    cp out/.config arch/arm64/configs/"${DEFCONFIG}"
    git add arch/arm64/configs/"${DEFCONFIG}"
    git commit -m "defconfig: Regenerate"
}

# Build Failed
build_failed() {
	    END=$(date +"%s")
	    DIFF=$(( END - START ))
	    echo -e "Kernel compilation failed, See buildlog to fix errors"
	    tg_fail "Build for ${DEVICE} <b>failed</b> in $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)!"
	    exit 1
}

# Building
mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out \
					  ARCH=arm64 \
					  CC=clang \
					  LD=ld.lld \
					  AR=llvm-ar \
					  AS=llvm-as \
					  NM=llvm-nm \
					  OBJCOPY=llvm-objcopy \
					  OBJDUMP=llvm-objdump \
					  STRIP=llvm-strip \
					  CROSS_COMPILE=aarch64-linux-android- \
					  CROSS_COMPILE_COMPAT=arm-linux-gnueabi- \
					  CLANG_TRIPLE=aarch64-linux-gnu- \
					  Image \
                                          dtb.img \
					  dtbo.img

# Packing kranul
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
if [ -d "$AK3_DIR" ]; then
cp -r $AK3_DIR AnyKernel3
elif ! git clone -q https://github.com/ardia-kun/AnyKernel3; then
echo -e "\nAnyKernel3 repo not found locally and cloning failed! Aborting..."
exit 1
fi
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
cp out/arch/arm64/boot/dtbo.img AnyKernel3
cp out/arch/arm64/boot/dtb.img AnyKernel3

rm -f *zip
cd AnyKernel3
git checkout main &> /dev/null
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
fi
cd ..

rm -rf AnyKernel3

    # Zip the kernel, or fail
    cd "${AK3_DIR}" || exit
    zip -r9 "${TEMPZIPNAME}" ./* -x .git README.md *placeholder

    # Sign the zip before sending it to Telegram
    curl -sLo zipsigner-4.0.jar https://raw.githubusercontent.com/baalajimaestro/AnyKernel3/master/zipsigner-4.0.jar
    java -jar zipsigner-4.0.jar "${TEMPZIPNAME}" "${ZIPNAME}"

    END=$(date +"%s")
    DIFF=$(( END - START ))

    # Ship it to the CI channel
    tg_ship "<b>-------- $DRONE_BUILD_NUMBER Build Succeed --------</b>" \
            "" \
            "<b>Device:</b> ${DEVICE}" \
            "<b>Version:</b> ${KERNELTYPE}" \
            "<b>Commit Head:</b> ${CHEAD}" \
            "<b>Time elapsed:</b> $((DIFF / 60)):$((DIFF % 60))" \
            "" \
            "Leave a comment below if encountered any bugs!"
}

# Starting
NOW=$(date +%d/%m/%Y-%H:%M)
START=$(date +"%s")
tg_cast "*$DRONE_BUILD_NUMBER CI Build Triggered*" \
	"Compiling with *$(nproc --all)* CPUs" \
	"-----------------------------------------" \
	"*Compiler:* ${CSTRING}" \
	"*Device:* ${DEVICE}" \
	"*Kernel:* ${KERNEL}" \
	"*Version:* ${KERNELTYPE}" \
	"*Linux Version:* $(make kernelversion)" \
	"*Branch:* ${DRONE_BRANCH}" \
	"*Clocked at:* ${NOW}" \
	"*Latest commit:* ${LATEST_COMMIT}" \
 	"------------------------------------------" \
	"${LOGS_URL}"

makekernel
