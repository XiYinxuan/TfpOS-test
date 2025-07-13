# TheFirstPageOS Tried版
By:席胤轩
简介：一个简单的操作系统实现，包含EFI引导和基本命令行功能。
鸣谢：王廷旭
## 环境要求
- WSL2 Ubuntu 22.04.5
- 以下工具需要在WSL中安装：
  ```bash
  sudo apt update
  sudo apt install -y build-essential gcc-x86-64-elf grub-common xorriso qemu-system-x86 gnu-efi
  ```

## 编译步骤
1. 在WSL中导航到项目目录：
   ```bash
   cd /home/xiyinxuan/TheFirstPageOS
   ```

2. 编译项目：
   ```bash
   make
   ```

3. 运行QEMU模拟：
   ```bash

   cd /mnt/c/Users/Xiyinxuan/Desktop/TheFirstPageOS                  
   ```

2. 编译项目：
   ```bash
   make
   ```

3. 运行QEMU模拟：
   ```bash
   make run
   ```

## 项目结构
- `src/efi/`: EFI引导程序代码
- `src/kernel/`: 内核代码
- `Makefile`: 编译配置文件
- `sysInfo.txt`: 系统配置信息

## 注意事项
- 目前键盘输入功能尚未完全实现
- 如需调试，可使用QEMU的调试选项：`make run DEBUG=1`