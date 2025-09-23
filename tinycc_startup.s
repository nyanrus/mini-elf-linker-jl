# TinyCC-compatible startup for C programs
.section .text
.globl _start

_start:
    # Clear frame pointer
    xor %rbp, %rbp
    
    # Align stack to 16 bytes (required by System V ABI)
    and $-16, %rsp
    
    # Call main function
    call main
    
    # Exit with main's return value
    mov %rax, %rdi        # main's return value -> exit code
    mov $60, %rax         # sys_exit syscall number
    syscall               # exit(main_return_value)