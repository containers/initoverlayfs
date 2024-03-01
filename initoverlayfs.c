#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include "initoverlayfs.h"
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
#include <sys/utsname.h>
#include <sys/vfs.h>
#include <sys/wait.h>
#include "config-parser.h"

#define fork_execl_no_wait(pid, exe, ...)      \
  do {                                         \
    pid = fork();                              \
    if (pid == -1) {                           \
      print("fail fork_execl_no_wait\n");      \
      break;                                   \
    } else if (pid > 0) {                      \
      break;                                   \
    }                                          \
                                               \
    execl(exe, exe, __VA_ARGS__, (char*)NULL); \
    exit(errno);                               \
  } while (0)

#define fork_execl(exe, ...)                   \
  do {                                         \
    printd("fork_execl(\"" exe "\")\n");       \
    const pid_t pid = fork();                  \
    if (pid == -1) {                           \
      print("fail fork_execl\n");              \
      break;                                   \
    } else if (pid > 0) {                      \
      printd("forked %d fork_execl\n", pid);   \
      waitpid(pid, 0, 0);                      \
      break;                                   \
    }                                          \
                                               \
    execl(exe, exe, __VA_ARGS__, (char*)NULL); \
    exit(errno);                               \
  } while (0)

#define fork_execlp(exe, ...)                   \
  do {                                          \
    printd("fork_execlp(\"" exe "\")\n");       \
    const pid_t pid = fork();                   \
    if (pid == -1) {                            \
      print("fail fork_execlp\n");              \
      break;                                    \
    } else if (pid > 0) {                       \
      printd("forked %d fork_execlp\n", pid);   \
      waitpid(pid, 0, 0);                       \
      break;                                    \
    }                                           \
                                                \
    execlp(exe, exe, __VA_ARGS__, (char*)NULL); \
    exit(errno);                                \
  } while (0)

#define fork_execlp_no_wait(pid, exe, ...)            \
  do {                                                \
    printd("fork_execlp_no_wait(\"" exe "\")\n");     \
    pid = fork();                                     \
    if (pid == -1) {                                  \
      print("fail fork_execlp_no_wait\n");            \
      break;                                          \
    } else if (pid > 0) {                             \
      printd("forked %d fork_execlp_no_wait\n", pid); \
      break;                                          \
    }                                                 \
                                                      \
    execlp(exe, exe, __VA_ARGS__, (char*)NULL);       \
    exit(errno);                                      \
  } while (0)

#define fork_execvp_no_wait(pid, exe)                 \
  do {                                                \
    printd("fork_execvp_no_wait(%p)\n", (void*)exe);  \
    pid = fork();                                     \
    if (pid == -1) {                                  \
      print("fail execvp_no_wait\n");                 \
      break;                                          \
    } else if (pid > 0) {                             \
      printd("forked %d fork_execvp_no_wait\n", pid); \
      break;                                          \
    }                                                 \
                                                      \
    execvp(exe[0], exe);                              \
    exit(errno);                                      \
  } while (0)

static inline long loop_ctl_get_free(void) {
  autoclose const int loopctlfd = open("/dev/loop-control", O_RDWR | O_CLOEXEC);
  if (loopctlfd < 0) {
    print("open(\"/dev/loop-control\", O_RDWR | O_CLOEXEC) = %d %d (%s)\n",
          loopctlfd, errno, strerror(errno));
    return 0;  // in error just try and continue with loop0
  }

  const long devnr = ioctl(loopctlfd, LOOP_CTL_GET_FREE);
  if (devnr < 0) {
    print("ioctl(%d, LOOP_CTL_GET_FREE) = %ld %d (%s)\n", loopctlfd, devnr,
          errno, strerror(errno));
    return 0;  // in error just try and continue with loop0
  }

  return devnr;
}

static inline int loop_configure(const long devnr,
                                 const int filefd,
                                 char** loopdev,
                                 const char* file) {
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
  if (asprintf(loopdev, "/dev/loop%ld", devnr) < 0)
    return -1;

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

static inline int losetup(char** loopdev, const char* file) {
  autoclose const int filefd = open(file, O_RDONLY | O_CLOEXEC);
  if (filefd < 0) {
    print("open(\"%s\", O_RDONLY| O_CLOEXEC) = %d %d (%s)\n", file, filefd,
          errno, strerror(errno));
    return errno;
  }

  const int ret = loop_configure(loop_ctl_get_free(), filefd, loopdev, file);
  if (ret)
    return ret;

  return 0;
}

static inline bool convert_bootfs(conf* c) {
  if (!c->bootfs.val->c_str) {
    print("c->bootfs.val.c_str pointer is null\n");
    return false;
  }

  if (!c->bootfs.val->c_str[0]) {
    print("c->bootfs.val.c_str string is \"%s\"\n", c->bootfs.val->c_str);
    return false;
  }

  const char* token = strtok(c->bootfs.val->c_str, "=");
  autofree char* bootfs_tmp = 0;
  if (!strcmp(token, "PARTLABEL")) {
    token = strtok(NULL, "=");
    if (asprintf(&bootfs_tmp, "/dev/disk/by-partlabel/%s", token) < 0)
      return false;
  } else if (!strcmp(token, "LABEL")) {
    token = strtok(NULL, "=");
    if (asprintf(&bootfs_tmp, "/dev/disk/by-label/%s", token) < 0)
      return false;
  } else if (!strcmp(token, "UUID")) {
    token = strtok(NULL, "=");
    if (asprintf(&bootfs_tmp, "/dev/disk/by-uuid/%s", token) < 0)
      return false;
  } else if (!strcmp(token, "PARTUUID")) {
    token = strtok(NULL, "=");
    if (asprintf(&bootfs_tmp, "/dev/disk/by-partuuid/%s", token) < 0)
      return false;
  } else
    return false;

  swap(c->bootfs.scoped->c_str, bootfs_tmp);
  c->bootfs.val->c_str = c->bootfs.scoped->c_str;

  return true;
}

static inline int convert_fs(conf* c) {
  if (!c->fstype.scoped->c_str) {
    c->fstype.scoped->c_str = strdup("erofs");
    c->fstype.val->c_str = c->fstype.scoped->c_str;
  }

  autofree char* fs = 0;
  if (!c->fs.scoped->c_str) {
    struct utsname buf;
    uname(&buf);
    if (asprintf(&fs, "/boot/initoverlayfs-%s.img", buf.release) < 0)
      return -1;

    swap(fs, c->fs.scoped->c_str);
    c->fs.val->c_str = c->fs.scoped->c_str;
    return 0;
  }

  if (!c->fs.val->c_str) {
    print("c->fs.val->c_str pointer is null\n");
    return -2;
  }

  if (!c->fs.val->c_str[0]) {
    print("c->fs.val->c_str string is \"\"\n");
    return -3;
  }

  if (asprintf(&fs, "/boot%s", c->fs.val->c_str) < 0)
    return -4;

  swap(fs, c->fs.scoped->c_str);
  c->fs.val->c_str = c->fs.scoped->c_str;

  return 0;
}

#define OVERLAY_STR                                                      \
  "redirect_dir=on,lowerdir=/initrofs,upperdir=/overlay/upper,workdir=/" \
  "overlay/work"

#define SYSROOT "/initoverlayfs"

static inline void mounts(const conf* c) {
  autofree char* dev_loop = 0;
  if (c->fs.val->c_str && losetup(&dev_loop, c->fs.val->c_str))
    print("losetup(\"%s\", \"%s\") %d (%s)\n", dev_loop, c->fs.val->c_str,
          errno, strerror(errno));

  if (mount(dev_loop, "/initrofs", c->fstype.val->c_str, MS_RDONLY, NULL))
    print(
        "mount(\"%s\", \"/initrofs\", \"%s\", MS_RDONLY, NULL) "
        "%d (%s)\n",
        dev_loop, c->fstype.val->c_str, errno, strerror(errno));

  if (mount("overlay", SYSROOT, "overlay", 0, "volatile," OVERLAY_STR) &&
      errno == EINVAL && mount("overlay", SYSROOT, "overlay", 0, OVERLAY_STR))
    print("mount(\"overlay\", \"" SYSROOT "\", \"overlay\", 0, \"" OVERLAY_STR
          "\") %d (%s)\n",
          errno, strerror(errno));

  if (mount("/boot", SYSROOT "/boot", c->bootfstype.val->c_str, MS_MOVE, NULL))
    print("mount(\"/boot\", \"" SYSROOT
          "/boot\", \"%s\", MS_MOVE, NULL) "
          "%d (%s)\n",
          c->bootfstype.val->c_str, errno, strerror(errno));
}

static void wait_mount_bootfs(const conf* c) {
  fork_execlp("udevadm", "wait", c->bootfs.val->c_str);

  errno = 0;
  if (mount(c->bootfs.val->c_str, "/boot", c->bootfstype.val->c_str, 0, NULL))
    print(
        "mount(\"%s\", \"/boot\", \"%s\", 0, NULL) "
        "%d (%s)\n",
        c->bootfs.val->c_str, c->bootfstype.val->c_str, errno, strerror(errno));
}

static inline int mount_proc_sys_dev(void) {
  if (mount("proc", "/proc", "proc", MS_NOSUID | MS_NOEXEC | MS_NODEV, NULL)) {
    print(
        "mount(\"proc\", \"/proc\", \"proc\", MS_NOSUID | MS_NOEXEC | "
        "MS_NODEV, NULL) %d (%s)\n",
        errno, strerror(errno));
    return errno;
  }

  if (mount("sysfs", "/sys", "sysfs", MS_NOSUID | MS_NOEXEC | MS_NODEV, NULL)) {
    print(
        "mount(\"sysfs\", \"/sys\", \"sysfs\", MS_NOSUID | MS_NOEXEC | "
        "MS_NODEV, NULL) %d (%s)\n",
        errno, strerror(errno));
    return errno;
  }

  if (mount("devtmpfs", "/dev", "devtmpfs", MS_NOSUID | MS_STRICTATIME,
            "mode=0755,size=4m")) {
    print(
        "mount(\"devtmpfs\", \"/dev\", \"devtmpfs\", MS_NOSUID | "
        "MS_STRICTATIME, \"mode=0755,size=4m\") %d (%s)\n",
        errno, strerror(errno));
    return errno;
  }

  return 0;
}

static inline FILE* log_open_kmsg(void) {
  kmsg_f = fopen("/dev/kmsg", "w");
  if (!kmsg_f) {
    print("open(\"/dev/kmsg\", \"w\"), %d = errno\n", errno);
    return kmsg_f;
  }

  setvbuf(kmsg_f, 0, _IOLBF, 0);
  return kmsg_f;
}

int main(int argc, char* argv[]) {
  bool systemd = false;
  if (argc > 1)
    systemd = true;

  autofclose FILE* kmsg_f_scoped = NULL;
  if (!systemd) {
    mount_proc_sys_dev();
    kmsg_f = kmsg_f_scoped;
    log_open_kmsg();
  }

  if (systemd) {
    pid_t loop_pid;
    fork_execl_no_wait(loop_pid, "/usr/sbin/modprobe", "loop");
  }

  autofree_conf conf conf = {
      .bootfs = {0, 0}, .bootfstype = {0, 0}, .fs = {0, 0}, .fstype = {0, 0}};
  if (conf_construct(&conf))
    return 0;

  conf_read(&conf, "/etc/initoverlayfs.conf");
  const bool do_bootfs = convert_bootfs(&conf);
  convert_fs(&conf);
  if (systemd)
    waitpid(loop_pid, 0, 0);

  if (do_bootfs)
    wait_mount_bootfs(&conf);

  errno = 0;
  mounts(&conf);

  return 0;
}
