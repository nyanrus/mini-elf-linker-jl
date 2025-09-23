// Simple printf stub that uses system calls
// This will satisfy the printf dependency

#include <stdarg.h>

// System call numbers for Linux x86_64
#define SYS_WRITE 1

// Simple write system call wrapper
static long sys_write(int fd, const void *buf, unsigned long count) {
    long result;
    __asm__ volatile (
        "syscall"
        : "=a" (result)
        : "a" (SYS_WRITE), "D" (fd), "S" (buf), "d" (count)
        : "rcx", "r11", "memory"
    );
    return result;
}

// Simple string length function
static unsigned long my_strlen(const char *s) {
    unsigned long len = 0;
    while (s[len]) len++;
    return len;
}

// Minimal printf implementation - just prints the format string
int printf(const char *format, ...) {
    // For simplicity, just print the format string directly
    // In a real implementation, we'd parse the format and arguments
    sys_write(1, format, my_strlen(format));
    return my_strlen(format);
}