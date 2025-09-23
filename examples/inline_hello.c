// Very simple hello world using inline assembly only
// This minimizes relocations

int main() {
    // Use inline assembly to write "Hello World!\n" directly
    __asm__ volatile (
        "mov $1, %%rax\n\t"          // SYS_WRITE = 1
        "mov $1, %%rdi\n\t"          // stdout = 1
        "mov $hello_msg, %%rsi\n\t"  // message buffer
        "mov $13, %%rdx\n\t"         // message length
        "syscall\n\t"               // write syscall
        
        "mov $60, %%rax\n\t"         // SYS_EXIT = 60
        "mov $0, %%rdi\n\t"          // exit status = 0
        "syscall\n\t"               // exit syscall
        
        "hello_msg:\n\t"
        ".ascii \"Hello World!\\n\""
        :
        :
        : "rax", "rdi", "rsi", "rdx", "rcx", "r11", "memory"
    );
    return 0; // Never reached
}