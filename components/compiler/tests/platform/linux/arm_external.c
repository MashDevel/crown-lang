#include "external.c"

extern char *realpath(const char *path, char *output);
extern void free(void *pointer);
extern char **environ;
extern char **crown_process_environment(void);

int main(void) {
    if (crown_external_answer(21) != 42) {
        return 1;
    }
    if (crown_external_absolute(-42) != 42) {
        return 2;
    }
    char *path = realpath("/", 0);
    if (!path) {
        return 3;
    }
    free(path);
    if (crown_process_environment() != environ) {
        return 4;
    }
    return 42;
}
