#include <dirent.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
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

#define STATFS_RAMFS_MAGIC 0x858458f6
#define STATFS_TMPFS_MAGIC 0x01021994

#ifdef __GNUC__
#define F_TYPE_EQUAL(a, b) (a == (__typeof__(a))b)
#else
#define F_TYPE_EQUAL(a, b) (a == (__SWORD_TYPE)b)
#endif

static int switchroot(const char* newroot) {
  /*  Don't try to unmount the old "/", there's no way to do it. */
  const char* umounts[] = {"/dev", "/proc", "/sys", "/run", NULL};
  int i;
  int cfd = -1;
  struct stat newroot_stat, oldroot_stat, sb;

  if (stat("/", &oldroot_stat) != 0) {
    warn("stat of %s failed", "/");
    return -1;
  }

  if (stat(newroot, &newroot_stat) != 0) {
    warn("stat of %s failed", newroot);
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
      warn("failed to mount moving %s to %s", umounts[i], newmount);
      warnx("forcing unmount of %s", umounts[i]);
      umount2(umounts[i], MNT_FORCE);
    }

    printf("succeeeded to mount moving %s to %s", umounts[i], newmount);
  }

  if (chdir(newroot)) {
    warn("failed to change directory to %s", newroot);
    return -1;
  }

  cfd = open("/", O_RDONLY);
  if (cfd < 0) {
    warn("cannot open %s", "/");
    goto fail;
  }

if (false) {
  if (mount(newroot, "/", NULL, MS_MOVE, NULL) < 0) {
    warn("failed final mount moving %s to /", newroot);
    goto fail;
  }
}

  if (chroot(".")) {
    warn("failed to change root");
    goto fail;
  }

  if (chdir("/")) {
    warn("cannot change directory to %s", "/");
    goto fail;
  }

fail:
  if (cfd >= 0)
    close(cfd);
  return -1;
}

static int try_to_run_init_process(const char* init_filename) {
  return execl(init_filename, init_filename, NULL);
}

static int pivot_root(const char* new_root, const char* put_old) {
  return syscall(__NR_pivot_root, new_root, put_old);
}

#ifndef UNLOCK_OVERLAYDIR
#define UNLOCK_OVERLAYDIR "/var/tmp/initoverlay"
#endif

static int mount_overlayfs() {
  if (chdir("/") < 0)
    err(1, "chdir");

  if (mount("overlay", "/initoverlayfs", "overlay", MS_RDONLY,
            "lowerdir=usr,upperdir=" UNLOCK_OVERLAYDIR
            "/upper,workdir=" UNLOCK_OVERLAYDIR "/work") < 0)
    err(1, "mount");

  return 0;
}

int main() {
  // mount rw overlayfs /initoverlayfs
  //  const int ret = mount(NULL, "/", NULL, MS_REMOUNT, NULL);
  if (false) {
    const int ret = mount_overlayfs();
    if (ret) {
      warn("failed to mount overlayfs: %d", ret);
      return errno;
    }
  }

  if (false) {
    errno = 0;
    if (pivot_root("/initoverlayfs", "/")) {
      warn("failed to pivot_root");
    }
  }

  if (switchroot("/initoverlayfs")) {
    warn("failed to switchroot");
//    return errno;
  }

  if (false) {
    if (chroot("/initoverlayfs")) {
      warn("failed to chroot");
      return errno;
    }
  }

  // to-do parse 2init= karg also possibly
  try_to_run_init_process("/sbin/init");
  try_to_run_init_process("/etc/init");
  try_to_run_init_process("/bin/init");
  try_to_run_init_process("/bin/sh");

  // If you reach here you have failed, exec should have taken control of this
  // process
  warn("failed to exec init process");
  return errno;
}
