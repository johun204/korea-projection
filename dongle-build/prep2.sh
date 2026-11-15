set -e
export ARCH=arm CROSS_COMPILE=/opt/gcc47/bin/arm-linux-androideabi-
cd ${KDIR:-/k/linux}
grep -q K8_TCC_COMPAT arch/arm/Kconfig || cat >> arch/arm/Kconfig <<'E'

# Options Telechips' ARCH_TCC selects that change struct layouts seen by modules
config K8_TCC_COMPAT
	def_bool y
	select PINCTRL
	select PINMUX
	select PINCONF
	select ARCH_DMA_ADDR_T_64BIT
	select ZONE_DMA
	select ARCH_REQUIRE_GPIOLIB
	select PM_GENERIC_DOMAINS
	select PM_OPP
	select USB_OTG
	select USB_PHY
	select GENERIC_IRQ_CHIP
	select CLKSRC_MMIO
E
cp /w/car-diag/kernel.config .config
printf 'CONFIG_ARCH_MULTIPLATFORM=y\nCONFIG_ARCH_MULTI_V7=y\nCONFIG_ARCH_VIRT=y\n' >> .config
make olddefconfig > /k/olddefconfig.log 2>&1 || { tail -20 /k/olddefconfig.log; exit 1; }
grep -i warning /k/olddefconfig.log | head
# old toolchain binaries crash at random under Rosetta: repeat until a pass has no crash
for i in 1 2 3 4 5 6 7 8 9 10; do
  make -j4 modules_prepare > /k/prepare.log 2>&1 && ! grep -q "Segmentation fault" /k/prepare.log && break
  [ $i = 10 ] && { tail -30 /k/prepare.log; exit 1; }
  rm -rf arch/arm/include/generated include/generated
done
[ -f arch/arm/include/generated/asm/types.h ] || [ -f arch/arm/include/asm/types.h ] || { echo "asm/types.h missing"; exit 1; }
cp .config /w/kbuild/built.config
grep -E "CONFIG_(PINCTRL|ARCH_DMA_ADDR_T_64BIT|ZONE_DMA|USB_OTG|PM_GENERIC_DOMAINS|PM_RUNTIME|USB_PHY)=" .config
