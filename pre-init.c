#include <assert.h>
#include <dirent.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/loop.h>
#include <linux/magic.h>
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

#define print(...)                  \
  do {                              \
    if (kmsg_f) {                   \
      fprintf(kmsg_f, __VA_ARGS__); \
      break;                        \
    }                               \
                                    \
    printf(__VA_ARGS__);            \
  } while (0)

#define printd(...)     \
  do {                  \
    print(__VA_ARGS__); \
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

#define exec_absolute_path(exe)     \
  do {                              \
    printd("execl(\"%s\")\n", exe); \
    execl(exe, exe, (char*)NULL);   \
  } while (0)

static inline void cleanup_free(void* p) {
  free(*(void**)p);
}

static inline void cleanup_close(const int* fd) {
  if (*fd > 2)  // Greater than 2 to protect stdin, stdout and stderr
    close(*fd);
}

static inline char* read_proc_cmdline(void) {
  FILE* f = fopen("/proc/cmdline", "r");
  char* cmdline = NULL;
  size_t len;

  if (!f)
    goto out;

  /* Note that /proc/cmdline will not end in a newline, so getline
   * will fail unelss we provide a length.
   */
  if (getline(&cmdline, &len, f) < 0)
    goto out;
  /* ... but the length will be the size of the malloc buffer, not
   * strlen().  Fix that.
   */
  len = strlen(cmdline);

  if (cmdline[len - 1] == '\n')
    cmdline[len - 1] = '\0';

out:
  if (f)
    fclose(f);

  return cmdline;
}

static inline char* find_proc_cmdline_key(const char* cmdline,
                                          const char* key) {
  const size_t key_len = strlen(key);
  for (const char* iter = cmdline; iter;) {
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

static inline bool string_contains(const char* cmdline, const char c) {
  for (; cmdline; ++cmdline)
    if (*cmdline == c)
      return true;

  return false;
}

static FILE* kmsg_f = 0;

static inline int log_open_kmsg(void) {
  kmsg_f = fopen("/dev/kmsg", "w");
  if (!kmsg_f) {
    print("open(\"/dev/kmsg\", \"w\"), %d = errno", errno);
    return errno;
  }

  setvbuf(kmsg_f, 0, _IOLBF, 0);
  return 0;
}

static inline int losetup(char* loopdev, const char* file) {
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
      .fd = filefd,
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
               .lo_init = {0, 0}}};
  strncpy((char*)loopconfig.info.lo_file_name, file, LO_NAME_SIZE - 1);
  sprintf(loopdev, "/dev/loop%ld", devnr);
  autoclose const int loopfd = open(loopdev, O_RDWR | O_CLOEXEC);
  if (loopfd < 0) {
    print("open(\"%s\", O_RDWR | O_CLOEXEC) = %d %d (%s)\n", loopdev, loopfd,
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
    char newmount[PATH_MAX];

    snprintf(newmount, sizeof(newmount), "%s%s", newroot, umounts[i]);

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

int main(void) {
  printd("Start pre-init\n");
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

  log_open_kmsg();
  printd("log_open_kmsg()\n");
  fork_exec_absolute("/lib/systemd/systemd-udevd", "--daemon");
  printd("Finish systemd-udevd\n");
  fork_exec_path("udevadm", "trigger", "--type=devices", "--action=add",
                 "--subsystem-match=module", "--subsystem-match=block",
                 "--subsystem-match=virtio", "--subsystem-match=pci",
                 "--subsystem-match=nvme");
  printd("Finish udevadm\n");

  autofree char* cmdline = read_proc_cmdline();
  printd("read_proc_cmdline() = \"%s\"\n", cmdline ? cmdline : "(nil)");

  autofree char* initoverlayfs =
      find_proc_cmdline_key(cmdline, "initoverlayfs");
  printd("find_proc_cmdline_key(\"%s\", \"initoverlayfs\") = \"%s\"\n",
         cmdline ? cmdline : "(nil)", initoverlayfs ? initoverlayfs : "(nil)");

  autofree char* initoverlayfstype =
      find_proc_cmdline_key(cmdline, "initoverlayfstype");
  printd("find_proc_cmdline_key(\"%s\", \"initoverlayfstype\") = \"%s\"\n",
         cmdline ? cmdline : "(nil)", initoverlayfstype ? initoverlayfstype : "(nil)");

  if (string_contains(initoverlayfs, ':')) {
    strtok(initoverlayfs, ":");
    const char* file = strtok(NULL, ":");
    const char* part = initoverlayfs;
    strtok(initoverlayfstype, ":");
    const char* filefstype = strtok(NULL, ":");
    const char* partfstype = initoverlayfstype;
    fork_exec_path("udevadm", "wait", part);
    if (mount(part, "/boot", partfstype, 0, NULL))
      print(
          "mount(\"%s\", \"/boot\", \"%s\", 0, NULL) "
          "%d (%s)\n",
          part, partfstype, errno, strerror(errno));

    printd(
        "mount(\"%s\", \"/boot\", \"%s\", 0, NULL) = 0 "
        "%d (%s)\n",
        part, partfstype, errno, strerror(errno));

    fork_exec_absolute("/usr/sbin/modprobe", "loop");

    char dev_loop[16];
    if (losetup(dev_loop, file))
      print("losetup(\"%s\", \"%s\") %d (%s)\n", dev_loop, file, errno,
            strerror(errno));
    // fork_exec_absolute("/usr/sbin/losetup", "/dev/loop0", file);
    if (mount("/dev/loop0", "/initrofs", filefstype, MS_RDONLY, NULL))
      print(
          "mount(\"/dev/loop0\", \"/initrofs\", \"%s\", MS_RDONLY, NULL) "
          "%d (%s)\n",
          filefstype, errno, strerror(errno));

    if (mount("overlay", "/initoverlayfs", "overlay", 0,
              "redirect_dir=on,lowerdir=/initrofs,upperdir=/overlay/"
              "upper,workdir=/overlay/work"))
      print(
          "mount(\"overlay\", \"/initoverlayfs\", \"overlay\", 0, "
          "\"redirect_dir=on,lowerdir=/initrofs,upperdir=/overlay/"
          "upper,workdir=/overlay/work\") %d (%s)\n",
          errno, strerror(errno));

    if (mount("/boot", "/initoverlayfs/boot", "ext4", MS_MOVE, NULL))
      print(
          "mount(\"/boot\", \"/initoverlayfs/boot\", \"ext4\", MS_MOVE, NULL) "
          "%d (%s)\n",
          errno, strerror(errno));

    if (switchroot("/initoverlayfs"))
      print("switchroot(\"initoverlayfs\") %d (%s)\n", errno, strerror(errno));

//    exec_path("bash");
    exec_absolute_path("/sbin/init");
    exec_absolute_path("/etc/init");
    exec_absolute_path("/bin/init");
    exec_absolute_path("/bin/sh");

    return errno;
  }

  fclose(kmsg_f);

  return errno;
}