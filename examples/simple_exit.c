// Minimal test program that just exits with code 42
// This should be the simplest possible working program

// System call numbers for Linux x86_64
#define SYS_EXIT 60

// Function to make exit system call
void exit(int status) {
    __asm__ volatile (
        "movl %0, %%edi\n\t"    // status -> edi (first argument, 32-bit)
        "movl $60, %%eax\n\t"   // SYS_EXIT -> eax (syscall number, 32-bit)
        "syscall\n\t"           // make system call
        :
        : "r" (status)
        : "eax", "edi"
    );
    __builtin_unreachable();
}

int main() {
    exit(42);
    return 0;  // Never reached
}