#ifndef IO_H
#define IO_H

#include <stdint.h>

// 从I/O端口读取一个字节
static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    asm volatile ("inb %1, %0" : "=a"(ret) : "Nd"(port));
    return ret;
}

// 向I/O端口写入一个字节
static inline void outb(uint16_t port, uint8_t value) {
    asm volatile ("outb %0, %1" :: "a"(value), "Nd"(port));
}

#endif // IO_H