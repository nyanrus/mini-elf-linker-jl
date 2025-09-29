int add_two_numbers(int a, int b) {
    return a + b;
}

int main() {
    int result = add_two_numbers(5, 3);
    return result == 8 ? 0 : 1;  // Exit code 0 for success
}
