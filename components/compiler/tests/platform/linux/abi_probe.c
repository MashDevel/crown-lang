#include <fcntl.h>
#include <pthread.h>
#include <spawn.h>
#include <stdio.h>
#include <time.h>

int main(void) {
    printf("spawn_actions=%zu\n", sizeof(posix_spawn_file_actions_t));
    printf("spawn_attributes=%zu\n", sizeof(posix_spawnattr_t));
    printf("spawn_mode=%zu\n", sizeof(mode_t));
    printf("open_flags=%d\n", O_WRONLY | O_CREAT | O_TRUNC);
    printf("monotonic_clock=%d\n", CLOCK_MONOTONIC);
    printf("pthread_attributes=%zu\n", sizeof(pthread_attr_t));
    printf("pthread_mutex=%zu\n", sizeof(pthread_mutex_t));
    printf("pthread_rwlock=%zu\n", sizeof(pthread_rwlock_t));
    return 0;
}
