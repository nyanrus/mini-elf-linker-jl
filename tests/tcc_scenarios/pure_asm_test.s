# Pure assembly test - no C runtime needed
.section .text
.globl _start

_start:
    # Exit with code 123
    mov $123, %rdi        # exit code
    mov $60, %rax         # sys_exit syscall number  
    syscall               # exit(123)