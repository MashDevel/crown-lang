int darwin_narrow(signed char a, unsigned char b, short c, unsigned short d, int e, unsigned f, long g, unsigned long h, signed char i, unsigned char j, short k, unsigned short l) {
    if (a != -1 || b != 2 || c != -3 || d != 4) return 1;
    if (e != -5 || f != 6 || g != -7 || h != 8) return 2;
    if (i != -9 || j != 10 || k != -11 || l != 12) return 3;
    return 42;
}
int darwin_variadic(int fixed, ...) {
    __builtin_va_list values;
    __builtin_va_start(values, fixed);
    int a = __builtin_va_arg(values, int);
    int b = __builtin_va_arg(values, int);
    double c = __builtin_va_arg(values, double);
    long d = __builtin_va_arg(values, long);
    __builtin_va_end(values);
    if (fixed != 7 || a != -8 || b != 60000) return 4;
    if (c != 1.5 || d != -123456789) return 5;
    return 42;
}
extern signed char crown_darwin_echo(signed char, signed char, signed char, signed char, signed char, signed char, signed char, signed char, signed char, signed char);
int darwin_return_check(void) {
    return crown_darwin_echo(1, 2, 3, 4, 5, 6, 7, 8, -9, -10) == -10 ? 42 : 7;
}
