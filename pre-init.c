#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <assert.h>
#include <dirent.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/loop.h>
#include <linux/magic.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/syscall.h>
#include <sys/vfs.h>
#include <sys/wait.h>
#include <unistd.h>

#define autofree __attribute__((cleanup(cleanup_free)))
#define autoclose __attribute__((cleanup(cleanup_close)))
#define autofclose __attribute__((cleanup(cleanup_fclose)))
#define autova_end __attribute__((cleanup(cleanup_va_end)))

#ifdef __cplusplus
#define typeof decltype
#endif

#define SWAP(a, b)      \
  do {                  \
    typeof(a) temp = a; \
    a = b;              \
    b = temp;           \
  } while (0)

#define fork_exec_absolute(exe, ...)           \
  do {                                         \
    printd("execl(\"%s\")\n", exe);            \
    const pid_t pid = fork();                  \
    if (pid == -1) {                           \
      print("fail exec_absolute\n");           \
      break;                                   \
    } else if (pid > 0) {                      \
      waitpid(pid, 0, 0);                      \
      break;                                   \
    }                                          \
                                               \
    execl(exe, exe, __VA_ARGS__, (char*)NULL); \
  } while (0)

#define exec_absolute_no_wait(exe)           \
  do {                                       \
    printd("execl(\"%s\")\n", exe);          \
    const pid_t pid = fork();                \
    if (pid == -1) {                         \
      print("fail exec_absolute_no_wait\n"); \
      break;                                 \
    } else if (pid > 0) {                    \
      break;                                 \
    }                                        \
                                             \
    execl(exe, exe, (char*)NULL);            \
  } while (0)

#define fork_exec_path(exe, ...)                \
  do {                                          \
    printd("execlp(\"%s\")\n", exe);            \
    const pid_t pid = fork();                   \
    if (pid == -1) {                            \
      print("fail exec_path\n");                \
      break;                                    \
    } else if (pid > 0) {                       \
      waitpid(pid, 0, 0);                       \
      break;                                    \
    }                                           \
                                                \
    execlp(exe, exe, __VA_ARGS__, (char*)NULL); \
  } while (0)

#define exec_path(exe)               \
  do {                               \
    printd("execlp(\"%s\")\n", exe); \
    execlp(exe, exe, (char*)NULL);   \
  } while (0)

static FILE* kmsg_f = 0;

static inline void cleanup_free(void* p) {
  free(*(void**)p);
}

static inline void cleanup_close(const int* fd) {
  if (*fd > 2)  // Greater than 2 to protect stdin, stdout and stderr
    close(*fd);
}

static inline void cleanup_fclose(FILE** stream) {
  fclose(*stream);
}

static inline void cleanup_va_end(va_list* args) {
  va_end(*args);
}

static inline void print(const char* f, ...) {
  autova_end va_list args;
  va_start(args, f);
  if (kmsg_f) {
    vfprintf(kmsg_f, f, args);
    return;
  }

  vprintf(f, args);
}

static inline void printd(const char* f, ...) {
  autova_end va_list args;
  va_start(args, f);
  print(f, args);
}

static inline void exec_absolute_path(const char* exe) {
  printd("execl(\"%s\")\n", exe);
  execl(exe, exe, (char*)NULL);
}

static inline char* read_conf(const char* file) {
  autofclose FILE* f = fopen(file, "r");
  char* cmdline = NULL;
  size_t len;

  if (!f)
    return NULL;

  /* Note that /proc/cmdline will not end in a newline, so getline
   * will fail unelss we provide a length.
   */
  if (getline(&cmdline, &len, f) < 0)
    return NULL;

  /* ... but the length will be the size of the malloc buffer, not
   * strlen().  Fix that.
   */
  len = strlen(cmdline);

  if (cmdline[len - 1] == '\n')
    cmdline[len - 1] = '\0';

  return cmdline;
}

static inline char* find_conf_key(const char* line, const char* key) {
  const size_t key_len = strlen(key);
  for (const char* iter = line; iter;) {
    const char* next = strchr(iter, ' ');
    if (strncmp(iter, key, key_len) == 0 && iter[key_len] == '=') {
      const char* start = iter + key_len + 1;
      if (next)
        return strndup(start, next - start);

      return strdup(start);
    }

    if (next)
      next += strspn(next, " ");

    iter = next;
  }

  return NULL;
}

#if 0
static inline bool string_contains(const char* cmdline, const char c) {
  for (; cmdline; ++cmdline)
    if (*cmdline == c)
      return true;

  return false;
}
#endif

static inline int log_open_kmsg(void) {
  kmsg_f = fopen("/dev/kmsg", "w");
  if (!kmsg_f) {
    print("open(\"/dev/kmsg\", \"w\"), %d = errno", errno);
    return errno;
  }

  setvbuf(kmsg_f, 0, _IOLBF, 0);
  return 0;
}

static inline int losetup(char** loopdev, const char* file) {
  autoclose const int loopctlfd = open("/dev/loop-control", O_RDWR | O_CLOEXEC);
  if (loopctlfd < 0) {
    print("open(\"/dev/loop-control\", O_RDWR | O_CLOEXEC) = %d %d (%s)\n",
          loopctlfd, errno, strerror(errno));
    return errno;
  }

  const long devnr = ioctl(loopctlfd, LOOP_CTL_GET_FREE);
  if (devnr < 0) {
    print("ioctl(%d, LOOP_CTL_GET_FREE) = %ld %d (%s)\n", loopctlfd, devnr,
          errno, strerror(errno));
    return errno;
  }

  autoclose const int filefd = open(file, O_RDONLY | O_CLOEXEC);
  if (filefd < 0) {
    print("open(\"%s\", O_RDONLY| O_CLOEXEC) = %d %d (%s)\n", file, filefd,
          errno, strerror(errno));
    return errno;
  }

  const struct loop_config loopconfig = {
      .fd = (unsigned int)filefd,
      .block_size = 0,
      .info = {.lo_device = 0,
               .lo_inode = 0,
               .lo_rdevice = 0,
               .lo_offset = 0,
               .lo_sizelimit = 0,
               .lo_number = 0,
               .lo_encrypt_type = LO_CRYPT_NONE,
               .lo_encrypt_key_size = 0,
               .lo_flags = LO_FLAGS_PARTSCAN,
               .lo_file_name = "",
               .lo_crypt_name = "",
               .lo_encrypt_key = "",
               .lo_init = {0, 0}},
      .__reserved = {0, 0, 0, 0, 0, 0, 0, 0}};
  strncpy((char*)loopconfig.info.lo_file_name, file, LO_NAME_SIZE - 1);
  asprintf(loopdev, "/dev/loop%ld", devnr);
  autoclose const int loopfd = open(*loopdev, O_RDWR | O_CLOEXEC);
  if (loopfd < 0) {
    print("open(\"%s\", O_RDWR | O_CLOEXEC) = %d %d (%s)\n", *loopdev, loopfd,
          errno, strerror(errno));
    return errno;
  }

  if (ioctl(loopfd, LOOP_CONFIGURE, &loopconfig) < 0) {
    print("ioctl(%d, LOOP_CONFIGURE, %p) %d (%s)\n", loopfd, (void*)&loopconfig,
          errno, strerror(errno));
    return errno;
  }

  return 0;
}

/* remove all files/directories below dirName -- don't cross mountpoints */
static inline int recursiveRemove(int fd) {
  struct stat rb;
  DIR* dir;
  int rc = -1;
  int dfd;

  if (!(dir = fdopendir(fd))) {
    print("failed to open directory");
    goto done;
  }

  /* fdopendir() precludes us from continuing to use the input fd */
  dfd = dirfd(dir);
  if (fstat(dfd, &rb)) {
    print("stat failed");
    goto done;
  }

  while (1) {
    struct dirent* d;
    int isdir = 0;

    errno = 0;
    if (!(d = readdir(dir))) {
      if (errno) {
        print("failed to read directory");
        goto done;
      }
      break; /* end of directory */
    }

    if (!strcmp(d->d_name, ".") || !strcmp(d->d_name, "..") ||
        !strcmp(d->d_name, "initoverlayfs"))
      continue;
#ifdef _DIRENT_HAVE_D_TYPE
    if (d->d_type == DT_DIR || d->d_type == DT_UNKNOWN)
#endif
    {
      struct stat sb;

      if (fstatat(dfd, d->d_name, &sb, AT_SYMLINK_NOFOLLOW)) {
        print("stat of %s failed", d->d_name);
        continue;
      }

      /* skip if device is not the same */
      if (sb.st_dev != rb.st_dev)
        continue;

      /* remove subdirectories */
      if (S_ISDIR(sb.st_mode)) {
        int cfd;

        cfd = openat(dfd, d->d_name, O_RDONLY);
        if (cfd >= 0)
          recursiveRemove(cfd); /* it closes cfd too */
        isdir = 1;
      }
    }

    if (unlinkat(dfd, d->d_name, isdir ? AT_REMOVEDIR : 0))
      print("failed to unlink %s", d->d_name);
  }

  rc = 0; /* success */
done:
  if (dir)
    closedir(dir);
  else
    close(fd);
  return rc;
}

static inline int switchroot(const char* newroot) {
  /*  Don't try to unmount the old "/", there's no way to do it. */
  const char* umounts[] = {"/dev", "/proc", "/sys", "/run", NULL};
  int i;
  int cfd = -1;
  struct stat newroot_stat, oldroot_stat, sb;

  if (stat("/", &oldroot_stat) != 0) {
    print("stat of %s failed", "/");
    return -1;
  }

  if (stat(newroot, &newroot_stat) != 0) {
    print("stat of %s failed", newroot);
    return -1;
  }

  for (i = 0; umounts[i] != NULL; i++) {
    autofree char* newmount;

    asprintf(&newmount, "%s%s", newroot, umounts[i]);

    if ((stat(umounts[i], &sb) == 0) && sb.st_dev == oldroot_stat.st_dev) {
      /* mount point to move seems to be a normal directory or stat failed */
      continue;
    }

    if ((stat(newmount, &sb) != 0) || (sb.st_dev != newroot_stat.st_dev)) {
      /* mount point seems to be mounted already or stat failed */
      umount2(umounts[i], MNT_DETACH);
      continue;
    }

    if (mount(umounts[i], newmount, NULL, MS_MOVE, NULL) < 0) {
      print("failed to mount moving %s to %s", umounts[i], newmount);
      print("forcing unmount of %s", umounts[i]);
      umount2(umounts[i], MNT_FORCE);
    }
  }

  if (chdir(newroot)) {
    print("failed to change directory to %s", newroot);
    return -1;
  }

  cfd = open("/", O_RDONLY);
  if (cfd < 0) {
    print("cannot open %s", "/");
    goto fail;
  }

  if (mount(newroot, "/", NULL, MS_MOVE, NULL) < 0) {
    print("failed to mount moving %s to /", newroot);
    goto fail;
  }

  if (chroot(".")) {
    print("failed to change root");
    goto fail;
  }

  if (chdir("/")) {
    print("cannot change directory to %s", "/");
    goto fail;
  }

  switch (fork()) {
    case 0: /* child */
    {
      struct statfs stfs;

      if (fstatfs(cfd, &stfs) == 0 &&
          (stfs.f_type == RAMFS_MAGIC || stfs.f_type == TMPFS_MAGIC))
        recursiveRemove(cfd);
      else {
        print("old root filesystem is not an initramfs");
        close(cfd);
      }
      exit(EXIT_SUCCESS);
    }
    case -1: /* error */
      break;

    default: /* parent */
      close(cfd);
      return 0;
  }

fail:
  if (cfd >= 0)
    close(cfd);
  return -1;
}

static inline int mount_proc_sys_dev(void) {
  if (mount("proc", "/proc", "proc", MS_NOSUID | MS_NOEXEC | MS_NODEV, NULL)) {
    print(
        "mount(\"proc\", \"/proc\", \"proc\", MS_NOSUID | MS_NOEXEC | "
        "MS_NODEV, "
        "NULL) %d (%s)\n",
        errno, strerror(errno));
    return errno;
  }

  if (mount("sysfs", "/sys", "sysfs", MS_NOSUID | MS_NOEXEC | MS_NODEV, NULL)) {
    print(
        "mount(\"sysfs\", \"/sys\", \"sysfs\", MS_NOSUID | MS_NOEXEC | "
        "MS_NODEV, "
        "NULL) %d (%s)\n",
        errno, strerror(errno));
    return errno;
  }

  if (mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID | MS_STRICTATIME,
            "mode=0755,size=4m")) {
    print(
        "mount(\"devtmpfs\", \"/dev\", \"devtmpfs\", MS_NOSUID | "
        "MS_STRICTATIME, "
        "NULL) %d (%s)\n",
        errno, strerror(errno));
    return errno;
  }

  return 0;
}

static inline void start_udev(void) {
  fork_exec_absolute("/lib/systemd/systemd-udevd", "--daemon");
  fork_exec_path("udevadm", "trigger", "--type=devices", "--action=add",
                 "--subsystem-match=module", "--subsystem-match=block",
                 "--subsystem-match=virtio", "--subsystem-match=pci",
                 "--subsystem-match=nvme");
}

int main(void) {
  if (mount_proc_sys_dev()) {
    return errno;
  }

  log_open_kmsg();
  start_udev();
  autofree char* cmdline = read_conf("/proc/cmdline");
  printd("read_conf(\"%s\") = \"%s\"\n", "/proc/cmdline",
         cmdline ? cmdline : "(nil)");

  // Other than initoverlayfs and initoverlayfstype, put all other
  // configuration in here if possible to avoid polluting kernel cmdline.
  autofree char* conf = read_conf("/etc/initoverlayfs.conf");
  printd("read_conf(\"%s\") = \"%s\"\n", "/etc/initoverlayfs.conf",
         conf ? conf : "(nil)");

  autofree char* initoverlayfs = find_conf_key(cmdline, "initoverlayfs");
  const char* token = strtok(initoverlayfs, "=");
  autofree char* initoverlayfs_tmp = 0;
  if (!strcmp(token, "LABEL")) {
    token = strtok(NULL, "=");
    asprintf(&initoverlayfs_tmp, "/dev/disk/by-label/%s", token);
    SWAP(initoverlayfs, initoverlayfs_tmp);
  } else if (!strcmp(token, "UUID")) {
    token = strtok(NULL, "=");
    asprintf(&initoverlayfs_tmp, "/dev/disk/by-uuid/%s", token);
    SWAP(initoverlayfs, initoverlayfs_tmp);
  }

  printd("find_conf_key(\"%s\", \"initoverlayfs\") = \"%s\"\n",
         cmdline ? cmdline : "(nil)", initoverlayfs ? initoverlayfs : "(nil)");

  autofree char* initoverlayfstype =
      find_conf_key(cmdline, "initoverlayfstype");

  autofree char* fs = NULL;
  autofree char* fstype = NULL;
  autofree char* fs_abs = NULL;
  if (conf) {
    fs = find_conf_key(conf, "fs");

    if (!fs) {
      print("return 1;\n");
      return 1;  // fatal error, something is drastically wrong
    }

    fs_abs = (char*)malloc(sizeof("/boot") + strlen(fs));
    if (!fs_abs)
      return 2;  // fatal error, something is drastically wrong if realloc fails

    strcpy(fs_abs, "/boot");
    strcpy(fs_abs + sizeof("/boot") - 1, fs);

    printd("strcpy(\"%s\", \"/boot\")\n", fs_abs ? fs_abs : "(nil)");

    fstype = find_conf_key(conf, "fstype");
    printd("find_conf_key(\"%s\", \"fstype\") = \"%s\"\n",
           conf ? conf : "(nil)", fstype ? fstype : "(nil)");
  }

  fork_exec_path("udevadm", "wait", initoverlayfs);
  if (mount(initoverlayfs, "/boot", initoverlayfstype, 0, NULL))
    print(
        "mount(\"%s\", \"/boot\", \"%s\", 0, NULL) "
        "%d (%s)\n",
        initoverlayfs, initoverlayfstype, errno, strerror(errno));

  fork_exec_absolute("/usr/sbin/modprobe", "loop");

  autofree char* dev_loop = 0;
  if (fs_abs && losetup(&dev_loop, fs_abs))
    print("losetup(\"%s\", \"%s\") %d (%s)\n", dev_loop, fs_abs, errno,
          strerror(errno));

  if (mount(dev_loop, "/initrofs", fstype, MS_RDONLY, NULL))
    print(
        "mount(\"%s\", \"/initrofs\", \"%s\", MS_RDONLY, NULL) "
        "%d (%s)\n",
        dev_loop, fstype, errno, strerror(errno));

  if (mount("overlay", "/initoverlayfs", "overlay", 0,
            "redirect_dir=on,lowerdir=/initrofs,upperdir=/overlay/"
            "upper,workdir=/overlay/work"))
    print(
        "mount(\"overlay\", \"/initoverlayfs\", \"overlay\", 0, "
        "\"redirect_dir=on,lowerdir=/initrofs,upperdir=/overlay/"
        "upper,workdir=/overlay/work\") %d (%s)\n",
        errno, strerror(errno));

  if (mount("/boot", "/initoverlayfs/boot", initoverlayfstype, MS_MOVE, NULL))
    print(
        "mount(\"/boot\", \"/initoverlayfs/boot\", \"%s\", MS_MOVE, NULL) "
        "%d (%s)\n",
        initoverlayfstype, errno, strerror(errno));

  if (switchroot("/initoverlayfs"))
    print("switchroot(\"initoverlayfs\") %d (%s)\n", errno, strerror(errno));

  exec_absolute_path("/sbin/init");
  exec_absolute_path("/etc/init");
  exec_absolute_path("/bin/init");
  exec_absolute_path("/bin/sh");

  fclose(kmsg_f);

  return errno;
}
