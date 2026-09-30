extern int crown_callback(int value);

__declspec(noinline) int native_value(int value) {
    volatile int storage[8];
    storage[0] = value;
    return crown_callback(storage[0]) + 1;
}
