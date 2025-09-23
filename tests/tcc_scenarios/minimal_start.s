# Minimal _start function for static executables
.section .text
.globl _start

_start:
    # Clear the frame pointer
    xor %rbp, %rbp
    
    # Call main
    call main
    
    # Exit with main's return value
    mov %rax, %rdi        # main's return value -> exit code
    mov $60, %rax         # sys_exit syscall number
    syscall               # exit(main_return_value)