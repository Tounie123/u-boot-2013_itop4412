以下是关于编译u-boot的步骤说明：
1.在编译之前首先执行make distclean清空当前工程
2.执行make origen_config进行单板的配置（包括单板的CPU架构、系列，单板名称等）
3.步骤执行成功后，执行make即可编译出u-boot.bin文件
4.对u-boot进行反汇编指令如下：arm-unknown-linux-gnueabi-objdump -d u-boot > my.asm

iTOP4412精英版SCP2G板子u-boot制作步骤如下:
1.将编译出来的u-boot.bin拷贝至CodeSign4SecureBoot_SCP目录下
2.执行如下指令：cat E4412_N.bl1.SCP2G.bin bl2.bin all00_padding.bin u-boot.bin tzsw_SMDK4412_SCP_2GB.bin > u-boot-iTOP-4412.bin生成u-boot-iTOP-4412.bin
3.执行如下命令进行烧写到SD卡：sudo dd if=u-boot-iTOP-4412.bin of=/dev/sdb seek=1
