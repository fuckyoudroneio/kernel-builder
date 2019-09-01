echo "***Kernel Builder***"
apt-get update
apt-get upgrade -y
echo $TG_API > /tmp/TG_API
echo $TG_CHAT > /tmp/TG_CHAT
echo $DEFCONFIG > /tmp/DEFCONFIG
echo $LINK > /tmp/LINK
export TZ=Europe/Moscow
echo `pwd` > /tmp/loc
sudo echo "ci ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
useradd -m -d /home/ci ci
useradd -g ci wheel
echo `pwd` > /tmp/loc
apt-get install git bc ccache automake lzop bison gperf build-essential zip curl zlib1g-dev g++-multilib python-networkx libxml2-utils bzip2 libbz2-dev libbz2-1.0 sudo libghc-bzlib-dev squashfs-tools pngcrush schedtool dpkg-dev liblz4-tool make optipng libssl-dev -y
git clone $(cat /tmp/LINK) kernel
cd kernel
git clone --progress -j32 --depth 5 --no-single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9.git
git clone --progress -j32 --depth 5 --no-single-branch https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9
git clone --depth 1 https://github.com/Panchajanya1999/clang-llvm.git -b 8.0
KERNEL_DIR=$PWD
cd aarch64-linux-android-4.9
git reset --hard 22f053ccdfd0d73aafcceff3419a5fe3c01e878b
cd $KERNEL_DIR/arm-linux-androideabi-4.9
git reset --hard 42e5864a7d23921858ca8541d52028ff88acb2b6
cd $KERNEL_DIR
git clone --depth 1 --no-single-branch https://github.com/rebenok90x/AnyKernel2.git
export ZIPNAME="NeonKernel"
export KBUILD_BUILD_USER="ctwoon"
export KBUILD_BUILD_HOST="neongang"
export ARCH=arm64
export SUBARCH=arm64
export BOT_MSG_URL="https://api.telegram.org/bot$(cat /tmp/TG_API)/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$(cat /tmp/TG_API)/sendDocument"
export CROSS_COMPILE=gcc/bin/aarch64-linux-android-
export CROSS_COMPILE_ARM32=gcc-arm/bin/arm-linux-androideabi-
export KBUILD_COMPILER_STRING=$($KERNEL_DIR/clang-llvm/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
LD_LIBRARY_PATH=$KERNEL_DIR/clang-llvm/lib64:$LD_LIBRARY_PATH
PATH=$KERNEL_DIR/clang-llvm/bin/:$KERNEL_DIR/aarch64-linux-android-4.9/bin/:$PATH
export PATH

#-----------------------------------------#
function check {
   if [ -f $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb ]
       then
         upload
       else
         ls
         tg_post_build error.log "$(cat /tmp/TG_CHAT)" "Build failed (@rebenok90x)"
        fi 
}
#------------------------------------------#
function tg_post_msg {
curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
-d "disable_web_page_preview=true" \
-d "parse_mode=html" \
-d text="$1"
}
#-----------------------------------------#
function tg_post_build {
curl --progress-bar -F document=@"$1" $BOT_BUILD_URL \
-F chat_id="$2"  \
-F "disable_web_page_preview=true" \
-F "parse_mode=html" \
-F caption="$3"
}
#------------------------------------------#
function upload {
mv $KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb AnyKernel2/Image.gz-dtb
cd AnyKernel2
zip -r9 $ZIPNAME-wayne * -x .git README.md
tg_post_build $ZIPNAME* "$(cat /tmp/TG_CHAT)" "Build took : $((DIFF / 60)) minute(s) and $((DIFF % 60)) second(s)"
echo "Build done"
}
#-------------------------------------------#
tg_post_msg "Starting kernel build" "$(cat /tmp/TG_CHAT)"
BUILD_START=$(date +"%s")
make O=out $(cat /tmp/DEFCONFIG)
make -j8 O=out \
CROSS_COMPILE=$KERNEL_DIR/aarch64-linux-android-4.9/bin/aarch64-linux-android- 2>&1 | tee error.log \
CROSS_COMPILE_ARM32=$KERNEL_DIR/arm-linux-androideabi-4.9/bin/arm-linux-androideabi- \
CC=$KERNEL_DIR/clang-llvm/bin/clang \
CLANG_TRIPLE=aarch64-linux-gnu- 2>&1| tee error.log
#------#
BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))
check
