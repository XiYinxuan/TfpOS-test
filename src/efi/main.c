#include <efi.h>
#include <efilib.h>
#include "../kernel/io.h"

// 添加图形信息结构体
typedef struct {
    void* framebuffer;        // 帧缓冲区地址
    uint32_t width;           // 屏幕宽度
    uint32_t height;          // 屏幕高度
    uint32_t pitch;           // 每行字节数
    uint32_t bits_per_pixel;  // 每像素位数
} GraphicsInfo;

// 全局图形信息变量
GraphicsInfo graphics_info;

EFI_STATUS efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable) {
    InitializeLib(ImageHandle, SystemTable);
    Print(L"TheFirstPage-tired OS Bootloader\n");
    Print(L"Debug: EFI main started\n");

    // 获取图形输出协议
    EFI_GRAPHICS_OUTPUT_PROTOCOL *gop = NULL;
    EFI_STATUS status = SystemTable->BootServices->LocateProtocol(
        &gEfiGraphicsOutputProtocolGuid,
        NULL,
        (VOID **)&gop
    );
    if (EFI_ERROR(status)) {
        Print(L"Failed to locate Graphics Output Protocol: %r\n", status);
        return status;
    }
    Print(L"Debug: Graphics Output Protocol located successfully\n");

    // 初始化图形信息
    GraphicsInfo graphics_info;
    graphics_info.framebuffer = (void*)gop->Mode->FrameBufferBase; // 添加类型转换
    graphics_info.width = gop->Mode->Info->HorizontalResolution;
    graphics_info.height = gop->Mode->Info->VerticalResolution;
    
    // 修复像素格式解析
    switch(gop->Mode->Info->PixelFormat) {
        case PixelRedGreenBlueReserved8BitPerColor:
        case PixelBlueGreenRedReserved8BitPerColor:
            graphics_info.bits_per_pixel = 32;
            break;
        case PixelBitMask:
            graphics_info.bits_per_pixel = gop->Mode->Info->PixelInformation.RedMask + 
                                          gop->Mode->Info->PixelInformation.GreenMask + 
                                          gop->Mode->Info->PixelInformation.BlueMask + 
                                          gop->Mode->Info->PixelInformation.ReservedMask;
            graphics_info.bits_per_pixel /= 8; // 转换为字节数后再转为位数
            break;
        default:
            graphics_info.bits_per_pixel = 32; // 默认32位
    }
    graphics_info.pitch = gop->Mode->Info->PixelsPerScanLine * (graphics_info.bits_per_pixel / 8);
    Print(L"Debug: Graphics info initialized - Resolution: %dx%d, BPP: %d\n", graphics_info.width, graphics_info.height, graphics_info.bits_per_pixel);

    Print(L"Loading kernel...\n");
    
    // 恢复内核加载代码
    EFI_LOADED_IMAGE_PROTOCOL *LoadedImage;
    EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *FileSystem;
    EFI_FILE_PROTOCOL *RootDir, *KernelFile;
    UINTN FileSize;
    VOID *KernelBuffer;
    
    // 获取当前加载的镜像协议
    status = SystemTable->BootServices->HandleProtocol(
        ImageHandle,
        &gEfiLoadedImageProtocolGuid,
        (VOID **)&LoadedImage
    );
    if (EFI_ERROR(status)) {
        Print(L"Failed to get loaded image protocol: %r\n", status);
        return status;
    }
    Print(L"Debug: Loaded image protocol retrieved\n");
    
    // 获取文件系统协议
    status = SystemTable->BootServices->HandleProtocol(
        LoadedImage->DeviceHandle,
        &gEfiSimpleFileSystemProtocolGuid,
        (VOID **)&FileSystem
    );
    if (EFI_ERROR(status)) {
        Print(L"Failed to get file system protocol: %r\n", status);
        return status;
    }
    Print(L"Debug: File system protocol retrieved\n");

    // 打开根目录
    status = FileSystem->OpenVolume(FileSystem, &RootDir);
    if (EFI_ERROR(status)) {
        Print(L"Failed to open root directory: %r\n", status);
        return status;
    }
    Print(L"Debug: Root directory opened\n");
    
    // 打开内核文件
    status = RootDir->Open(RootDir, &KernelFile, L"boot/kernel.bin", EFI_FILE_MODE_READ, 0);
    if (EFI_ERROR(status)) {
        Print(L"Failed to open kernel.bin: %r\n", status);
        return status;
    }
    Print(L"Debug: kernel.bin opened successfully\n");
    
    // 获取文件大小
    status = KernelFile->GetInfo(
        KernelFile,
        &gEfiFileInfoGuid,
        &FileSize,
        NULL
    );
    if (EFI_ERROR(status) && status != EFI_BUFFER_TOO_SMALL) {
        Print(L"Failed to get file info: %r\n", status);
        return status;
    }
    Print(L"Debug: Kernel file size retrieved: %d bytes\n", FileSize);
    
    // 分配内存
    status = SystemTable->BootServices->AllocatePool(
        EfiLoaderData,
        FileSize,
        &KernelBuffer
    );
    if (EFI_ERROR(status)) {
        Print(L"Failed to allocate memory: %r\n", status);
        return status;
    }
    Print(L"Debug: Memory allocated for kernel at 0x%x\n", KernelBuffer);
    
    // 读取文件内容
    status = KernelFile->Read(KernelFile, &FileSize, KernelBuffer);
    if (EFI_ERROR(status)) {
        Print(L"Failed to read kernel file: %r\n", status);
        return status;
    }
    Print(L"Debug: Kernel file read successfully\n");
    
    // 关闭文件
    KernelFile->Close(KernelFile);
    RootDir->Close(RootDir);
    
    // 获取内存映射
    UINTN MemoryMapSize = 0;
    EFI_MEMORY_DESCRIPTOR *MemoryMap = NULL;
    UINTN MapKey;
    UINTN DescriptorSize;
    UINT32 DescriptorVersion;
    
    // 首先获取所需缓冲区大小
    status = SystemTable->BootServices->GetMemoryMap(
        &MemoryMapSize,
        MemoryMap,
        &MapKey,
        &DescriptorSize,
        &DescriptorVersion
    );
    if (status != EFI_BUFFER_TOO_SMALL) {
        Print(L"Failed to get memory map size: %r\n", status);
        return status;
    }
    Print(L"Debug: Memory map size determined: %d bytes\n", MemoryMapSize);
    
    // 分配内存缓冲区
    status = SystemTable->BootServices->AllocatePool(
        EfiBootServicesData,
        MemoryMapSize,
        (VOID **)&MemoryMap
    );
    if (EFI_ERROR(status)) {
        Print(L"Failed to allocate memory for memory map: %r\n", status);
        return status;
    }
    Print(L"Debug: Memory allocated for memory map at 0x%x\n", MemoryMap);
    
    // 获取实际内存映射
    status = SystemTable->BootServices->GetMemoryMap(
        &MemoryMapSize,
        MemoryMap,
        &MapKey,
        &DescriptorSize,
        &DescriptorVersion
    );
    if (EFI_ERROR(status)) {
        Print(L"Failed to get memory map: %r\n", status);
        return status;
    }
    Print(L"Debug: Memory map retrieved successfully\n");
    
    // 为图形信息分配持久化内存
    GraphicsInfo* kernel_graphics_info;
    status = SystemTable->BootServices->AllocatePool(
        EfiBootServicesData, sizeof(GraphicsInfo), (VOID**)&kernel_graphics_info
    );
    if (EFI_ERROR(status)) {
        Print(L"Failed to allocate memory for graphics info: %r\n", status);
        return status;
    }
    *kernel_graphics_info = graphics_info;
 
    // 退出Boot Services
    status = SystemTable->BootServices->ExitBootServices(ImageHandle, MapKey);

    if (EFI_ERROR(status)) {
        Print(L"Failed to exit boot services: %r\n", status);
        return status;
    }
    Print(L"Debug: Boot services exited successfully\n");

    // 发送串口调试信息
    const char* test_msg = "EFI: About to call kernel_main\n";
    for (int i = 0; test_msg[i] != '\0'; i++) {
        while ((inb(0x3F8 + 5) & 0x20) == 0);
        outb(0x3F8, test_msg[i]);
    }

    // 跳转到内核入口点
    void (*kernel_main)(GraphicsInfo*) = (void (*)(GraphicsInfo*))KernelBuffer;
    kernel_main(kernel_graphics_info);

    // 如果内核返回，输出错误信息
    Print(L"Debug: Kernel returned unexpectedly\n");
    if (EFI_ERROR(status)) {
        Print(L"Failed to allocate memory for graphics info: %r\n", status);
        return status;
    }
    *kernel_graphics_info = graphics_info;

    // 跳转到内核入口点，传递图形信息指针
    Print(L"Jumping to kernel entry point with graphics info...\n");
    ((void (*)(GraphicsInfo*))KernelBuffer)(kernel_graphics_info);
    // 如果内核返回，显示错误
    Print(L"Kernel returned unexpectedly!\n");
    
    // 理论上不会执行到这里
    return EFI_SUCCESS;
}