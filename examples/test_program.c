#include <stdio.h>

int global_var = 42;

int add_numbers(int a, int b) {
    return a + b;
}

int main() {
    int result = add_numbers(10, 20);
    printf("Hello from ELF! Result: %d, Global: %d\n", result, global_var);
    return 0;
}