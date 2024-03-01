#include <ctype.h>
#include <dirent.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define autofree __attribute__((cleanup(cleanup_free)))
#define autofree_str __attribute__((cleanup(cleanup_free_str)))
#define autofree_conf __attribute__((cleanup(cleanup_free_conf)))
#define autoclose __attribute__((cleanup(cleanup_close)))
#define autofclose __attribute__((cleanup(cleanup_fclose)))
#define autoclosedir __attribute__((cleanup(cleanup_closedir)))

#ifdef __cplusplus
#define typeof decltype
#endif

#define swap(a, b)      \
  do {                  \
    typeof(a) temp = a; \
    a = b;              \
    b = temp;           \
  } while (0)

#define print(...)                                   \
  do {                                               \
    if (kmsg_f) {                                    \
      fprintf(kmsg_f, "storage-init: " __VA_ARGS__); \
      break;                                         \
    }                                                \
                                                     \
    printf(__VA_ARGS__);                             \
  } while (0)

#if 1
#define DEBUG
#define printd(...)     \
  do {                  \
    print(__VA_ARGS__); \
  } while (0)
#else
#define printd(...)
#endif

static FILE* kmsg_f = 0;

typedef struct str {
  char* c_str;
  int len;
} str;

typedef struct pair {
  str* val;
  str* scoped;
} pair;

typedef struct conf {
  pair bootfs;
  pair bootfstype;
  pair fs;
  pair fstype;
} conf;

static inline void cleanup_free_conf(conf* p) {
  if (p->bootfs.scoped)
    free(p->bootfs.scoped->c_str);
  if (p->bootfstype.scoped)
    free(p->bootfstype.scoped->c_str);
  if (p->fs.scoped)
    free(p->fs.scoped->c_str);
  if (p->fstype.scoped)
    free(p->fstype.scoped->c_str);

  free(p->bootfs.scoped);
  free(p->bootfstype.scoped);
  free(p->fs.scoped);
  free(p->fstype.scoped);
  free(p->bootfs.val);
  free(p->bootfstype.val);
  free(p->fs.val);
  free(p->fstype.val);
}

static inline void cleanup_free(void* p) {
  free(*(void**)p);
}

static inline void cleanup_free_str(str** p) {
  if (!*p)
    return;

  free((*p)->c_str);
  free(*p);
}

static inline void cleanup_close(const int* fd) {
  if (*fd >= 0)
    close(*fd);
}

static inline void cleanup_fclose(FILE** stream) {
  if (*stream)
    fclose(*stream);
}

static inline void cleanup_closedir(DIR** dir) {
  if (*dir)
    closedir(*dir);
}
