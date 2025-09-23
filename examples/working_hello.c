// Extremely simple hello program that should work
// Using minimal features to reduce relocation issues

const char hello_msg[] = "Hello World!\n";

int write_syscall(int fd, const char *buf, int count) {
    int result;
    __asm__ volatile (
        "movl $1, %%eax\n\t"
        "movl %1, %%edi\n\t"
        "movq %2, %%rsi\n\t"
        "movl %3, %%edx\n\t"
        "syscall\n\t"
        "movl %%eax, %0\n\t"
        : "=r" (result)
        : "r" (fd), "r" (buf), "r" (count)
        : "eax", "edi", "rsi", "edx", "rcx", "r11"
    );
    return result;
}

void exit_syscall(int code) {
    __asm__ volatile (
        "movl $60, %%eax\n\t"
        "movl %0, %%edi\n\t"
        "syscall\n\t"
        :
        : "r" (code)
        : "eax", "edi", "rcx", "r11"
    );
}

int main() {
    write_syscall(1, hello_msg, 13);
    exit_syscall(0);
    return 0;
}