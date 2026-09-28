#include <dirent.h>
#include <pthread.h>
#include <spawn.h>
#include <stddef.h>
_Static_assert(offsetof(struct dirent, d_name) == 21, "Darwin directory name offset");
_Static_assert(sizeof(pthread_attr_t) == 64, "Darwin thread attribute storage");
_Static_assert(sizeof(pthread_mutex_t) == 64, "Darwin mutex storage");
_Static_assert(sizeof(pthread_rwlock_t) <= 256, "Darwin read-write lock storage");
_Static_assert(sizeof(posix_spawnattr_t) == 8, "Darwin spawn attribute storage");
struct dirent *directory_entry(DIR *directory) { return readdir(directory); }
unsigned long directory_offset(void) { return offsetof(struct dirent, d_name); }
unsigned long attribute_size(void) { return sizeof(pthread_attr_t); }
unsigned long mutex_size(void) { return sizeof(pthread_mutex_t); }
unsigned long rwlock_size(void) { return sizeof(pthread_rwlock_t); }
unsigned long spawn_attribute_size(void) { return sizeof(posix_spawnattr_t); }
