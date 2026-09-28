extern int abs(int value);

volatile unsigned int crown_external_data = 21;
volatile unsigned int crown_external_zero[4];
volatile unsigned int *crown_external_pointer = &crown_external_data;

unsigned int crown_external_answer(unsigned int value) {
    return value + *crown_external_pointer + crown_external_zero[2];
}

int crown_external_absolute(int value) {
    return abs(value);
}
