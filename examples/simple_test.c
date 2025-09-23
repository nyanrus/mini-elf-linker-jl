// Simple self-contained C program for testing ELF linking
// This program doesn't call any external functions

int global_number = 100;

int add_two_numbers(int a, int b) {
    return a + b;
}

int main() {
    // Simple computation that should work without external dependencies
    int result = add_two_numbers(global_number, 42);
    
    // Exit with the result (truncated to fit in exit code)
    return result % 256;
}