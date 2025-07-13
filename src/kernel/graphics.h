#ifndef GRAPHICS_H
#define GRAPHICS_H

#include <stdint.h>

// 图形信息结构体，存储EFI传递的显示参数
typedef struct {
    uint32_t* framebuffer;   // 帧缓冲区地址
    uint32_t width;          // 屏幕宽度（像素）
    uint32_t height;         // 屏幕高度（像素）
    uint32_t pitch;          // 每行字节数
    uint32_t bits_per_pixel; // 每像素位数
} GraphicsInfo;

#endif // GRAPHICS_H