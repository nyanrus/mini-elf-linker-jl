// Hello World C program using direct system calls
// This avoids the need for libc and printf

// System call numbers for Linux x86_64
#define SYS_WRITE 1
#define SYS_EXIT 60

// File descriptors
#define STDOUT_FILENO 1

// Function to make system calls
long syscall(long number, long arg1, long arg2, long arg3) {
    long result;
    __asm__ volatile (
        "syscall"
        : "=a" (result)
        : "a" (number), "D" (arg1), "S" (arg2), "d" (arg3)
        : "rcx", "r11", "memory"
    );
    return result;
}

// Simple write function
long write(int fd, const char *buf, unsigned long count) {
    return syscall(SYS_WRITE, fd, (long)buf, count);
}

// Simple exit function
void exit(int status) {
    syscall(SYS_EXIT, status, 0, 0);
    __builtin_unreachable();
}

// String length function
unsigned long strlen(const char *s) {
    unsigned long len = 0;
    while (s[len]) len++;
    return len;
}

// Simple print function
void print(const char *str) {
    write(STDOUT_FILENO, str, strlen(str));
}

int main() {
    print("Hello World!\n");
    exit(0);
    return 0;
}