#!/bin/sh
sec_path="../uboot/CodeSign4SecureBoot_SCP/"
rm -rf $sec_path/u-boot*
make distclean
make origen_config
make
cp u-boot.bin $sec_path/
cd $sec_path/
cat E4412_N.bl1.SCP2G.bin bl2.bin all00_padding.bin u-boot.bin tzsw_SMDK4412_SCP_2GB.bin > u-boot-origen.bin
cd -
