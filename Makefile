# 目录结构定义
SRC_DIR := /mnt/c/Users/Xiyinxuan/Desktop/TheFirstPageOS/src
EFI_DIR := $(SRC_DIR)/efi
KERNEL_DIR := $(SRC_DIR)/kernel

# 基础配置
TARGET := thefirstpage-tired
ARCH := x86_64
CROSS_COMPILE ?= x86_64-linux-gnu

# 目录结构
  GRUB_DIRS := /usr/lib/grub/x86_64-efi /boot/grub/x86_64-efi /usr/local/lib/grub/x86_64-efi
  GRUB_CONFIG := $(SRC_DIR)/grub/grub.cfg
BUILD_DIR := /mnt/c/Users/Xiyinxuan/Desktop/TheFirstPageOS/build
ISO_DIR := $(BUILD_DIR)/iso
EFI_BIN_DIR := $(BUILD_DIR)/efi/bin
# 编译器和链接器
EFI_CC := gcc
CC := $(CROSS_COMPILE)-gcc
LD := $(CROSS_COMPILE)-ld
OBJCOPY := $(CROSS_COMPILE)-objcopy
GRUB_INSTALL := grub-install
QEMU := qemu-system-$(ARCH)
QEMU_EFI_CODE := $(BUILD_DIR)/OVMF_CODE_4M.fd
QEMU_EFI_VARS := $(BUILD_DIR)/OVMF_VARS_4M.fd

# 复制OVMF文件到构建目录
$(BUILD_DIR)/OVMF_CODE_4M.fd:
	@if [ ! -f "$@" ]; then \
		cp ./OVMF_CODE.fd $(BUILD_DIR)/OVMF_CODE_4M.fd; \
		chmod 644 $(BUILD_DIR)/OVMF_CODE_4M.fd; \
	fi

$(BUILD_DIR)/OVMF_VARS_4M.fd:
	@if [ ! -f "$@" ]; then \
		cp ./OVMF_VARS.fd $(BUILD_DIR)/OVMF_VARS_4M.fd; \
		chmod 644 $(BUILD_DIR)/OVMF_VARS_4M.fd; \
	fi

# EFI应用程序构建
$(BUILD_DIR)/efi/main.o: $(SRC_DIR)/efi/main.c
	mkdir -p $(BUILD_DIR)/efi
	$(EFI_CC) $(CFLAGS) -c $< -o $@

$(EFI_BIN_DIR)/bootx64.so: $(BUILD_DIR)/efi/main.o
	mkdir -p $(EFI_BIN_DIR)
	$(LD) $(LDFLAGS_EFI) -o $@ $^

# 编译选项
CFLAGS = -ffreestanding -fshort-wchar -mno-red-zone -Wall -Wextra -fPIC -D__EFI__ -DEFI_FUNCTION_WRAPPER \
    -I/usr/include/efi -I/usr/include/efi/x86_64 -I/usr/include/efi/protocol \
    -I$(SRC_DIR)/kernel
LDFLAGS_EFI := -nostdlib -znocombreloc -zmax-page-size=0x1000 --Ttext=0x800000 --entry=efi_main /usr/lib/crt0-efi-x86_64.o -L/usr/lib -lgnuefi -lefi --defsym=EFI_SUBSYSTEM=1 -T /usr/lib/elf_x86_64_efi.lds -static --no-dynamic-linker --defsym=_DYNAMIC=0
LDFLAGS_KERNEL := -nostdlib -zmax-page-size=0x1000 -T $(KERNEL_DIR)/kernel.ld

# EFI源文件和目标文件
$(BUILD_DIR)/efi/%.o: $(EFI_DIR)/%.c
	mkdir -p $(@D)
	$(EFI_CC) $(CFLAGS) -c $< -o $@

EFI_SRC := $(wildcard $(EFI_DIR)/*.c)
EFI_OBJ := $(patsubst $(EFI_DIR)/%.c, $(BUILD_DIR)/efi/%.o, $(EFI_SRC))

# 内核源文件和目标文件
$(BUILD_DIR)/kernel/%.o: $(KERNEL_DIR)/%.c
	mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

KERNEL_SRC := $(wildcard $(KERNEL_DIR)/*.c)
KERNEL_OBJ := $(patsubst $(KERNEL_DIR)/%.c, $(BUILD_DIR)/kernel/%.o, $(KERNEL_SRC))



# 检查必要文件是否存在
ifeq ($(strip $(wildcard $(KERNEL_DIR)/kernel.ld)),)
$(error ERROR: Kernel linker script not found: $(KERNEL_DIR)/kernel.ld)
endif
# 调试变量值
$(info GRUB_CONFIG=$(GRUB_CONFIG))
$(info EFI_DIR=$(EFI_DIR))
$(info EFI_SRC=$(EFI_SRC))
# 检查源文件是否存在
ifeq ($(strip $(EFI_SRC)),)
$(error ERROR: No EFI source files found in $(EFI_DIR))
endif
ifeq ($(strip $(KERNEL_SRC)),)
$(error ERROR: No kernel source files found in $(KERNEL_DIR))
endif

# 默认目标
all: $(BUILD_DIR)/$(TARGET).iso

# 构建ISO目录
$(ISO_DIR): $(BUILD_DIR)/kernel.bin $(EFI_BIN_DIR)/BOOTX64.EFI
	mkdir -p $(ISO_DIR)/EFI/BOOT
	mkdir -p $(ISO_DIR)/boot
	# 复制内核文件
	cp $(BUILD_DIR)/kernel.bin $(ISO_DIR)/boot/
	# 复制EFI应用程序到正确位置
	cp $(EFI_BIN_DIR)/BOOTX64.EFI $(ISO_DIR)/EFI/BOOT/
	# 添加UEFI Shell自动启动脚本
	printf 'echo ==== STARTUP DEBUG ==== > COM1\r\necho Shell initialized successfully > COM1\r\necho Current directory: %%cd%% > COM1\r\necho Listing all devices: > COM1\nmap -r > COM1\r\necho Checking fs0: existence... > COM1\r\nif exist fs0: echo fs0: exists > COM1; else echo fs0: NOT found > COM1; endif\r\necho Checking EFI/BOOT directory... > COM1\r\nif exist fs0:/EFI/BOOT/ echo Directory exists > COM1; else echo Directory NOT found > COM1; endif\r\necho Listing BOOT directory contents: > COM1\r\nls fs0:/EFI/BOOT/ > COM1 || echo Listing failed > COM1\r\necho Attempting to run EFI application... > COM1\r\nfs0:/EFI/BOOT/BOOTX64.EFI || echo FAILED to execute BOOTX64.EFI > COM1\r\necho EFI application execution completed > COM1\r\n' > $(BUILD_DIR)/iso/startup.nsh
	# 验证startup.nsh内容
	@echo "Verifying startup.nsh content:" && cat $(ISO_DIR)/startup.nsh

# 构建ISO镜像
$(BUILD_DIR)/$(TARGET).iso: $(ISO_DIR) $(EFI_BIN_DIR)/BOOTX64.EFI $(BUILD_DIR)/kernel.bin
	@echo "Verifying EFI boot file..." > build_debug.log
	@if [ ! -f "$(ISO_DIR)/EFI/BOOT/BOOTX64.EFI" ]; then echo "ERROR: BOOTX64.EFI not found in ISO directory" | tee -a build_debug.log; exit 1; fi
	@echo "Listing ISO directory contents..." | tee -a build_debug.log
	@ls -laR $(ISO_DIR) | tee -a build_debug.log
	@echo "Creating ISO image..." | tee -a build_debug.log
	@xorriso -as mkisofs -v -o $@ -V "THEFIRSTPAGE" --efi-boot EFI/BOOT/BOOTX64.EFI --efi-boot-part --efi-boot-image -R -J -input-charset utf-8 --protective-msdos-label $(ISO_DIR) 2>&1 | tee -a build_debug.log
	@if [ -f "$@" ]; then echo "ISO created successfully: $@" | tee -a build_debug.log; else echo "ISO creation failed: $@ not found" | tee -a build_debug.log; exit 1; fi

# 构建EFI应用程序
$(EFI_BIN_DIR)/BOOTX64.EFI: $(BUILD_DIR)/efi/bootx64.so
	mkdir -p $(EFI_BIN_DIR)
	$(OBJCOPY) -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .rel -j .rela -j .reloc --target=efi-app-$(ARCH) $< $@

$(BUILD_DIR)/efi/bootx64.so: $(EFI_OBJ)
	mkdir -p $(@D)
	$(LD) $(LDFLAGS_EFI) -o $@ $^

# 构建内核
$(BUILD_DIR)/kernel.bin: $(KERNEL_OBJ)
	mkdir -p $(@D)
	$(LD) $(LDFLAGS_KERNEL) -o $@ $^

# 编译EFI目标文件
$(BUILD_DIR)/efi/%.o: $(EFI_DIR)/%.c
	mkdir -p $(@D)
	$(EFI_CC) $(CFLAGS) -I/usr/include/efi -I/usr/include/efi/$(ARCH) -I/usr/include/efi/protocol -c $< -o $@

# 编译内核目标文件
$(BUILD_DIR)/kernel/%.o: $(KERNEL_DIR)/%.c
	mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

# 运行QEMU模拟
run: $(BUILD_DIR)/$(TARGET).iso
	@echo "Checking for OVMF files..."
	@if [ ! -f /usr/share/ovmf/OVMF.fd ]; then \
	  echo "Error: OVMF files not found. Please install ovmf package."; \
	  echo "On Debian/Ubuntu: sudo apt-get install ovmf"; \
	  exit 1; \
	fi
	@echo "Starting QEMU with $(BUILD_DIR)/$(TARGET).iso..."
	$(QEMU) -drive if=pflash,format=raw,file=/usr/share/ovmf/OVMF.fd,readonly=on \
	$(if $(DEBUG),-s ,) \
	-drive id=cdrom,if=none,file=$(BUILD_DIR)/$(TARGET).iso,format=raw \
	-device ahci,id=ahci \
	-device ide-cd,drive=cdrom,bus=ahci.0 \
	-boot order=d,strict=on -m 2G -serial file:build/serial.log \
	-monitor stdio -vga std -display sdl -debugcon file:uefi_debug.log \
	-global isa-debugcon.iobase=0x402 > $(BUILD_DIR)/qemu.log 2>&1

# 清理构建文件
clean:
	@if [ -d "$(BUILD_DIR)" ]; then chown -R $$USER:$$USER $(BUILD_DIR); fi
	rm -rf $(BUILD_DIR)

.PHONY: all run clean
	@cp OVMF_CODE.fd $(BUILD_DIR)/OVMF_CODE_4M.fd
	@cp OVMF_VARS.fd $(BUILD_DIR)/OVMF_VARS_4M.fd