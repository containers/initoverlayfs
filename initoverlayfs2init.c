#include <dirent.h>
#include <err.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/vfs.h>
#include <unistd.h>

#define STATFS_RAMFS_MAGIC 0x858458f6
#define STATFS_TMPFS_MAGIC 0x01021994

#ifdef __GNUC__
#define F_TYPE_EQUAL(a, b) (a == (__typeof__(a))b)
#else
#define F_TYPE_EQUAL(a, b) (a == (__SWORD_TYPE)b)
#endif

static int recursiveRemove(int fd) {
  struct stat rb;
  DIR* dir;
  int rc = -1;
  int dfd;

  if (!(dir = fdopendir(fd))) {
    warn("failed to open directory");
    goto done;
  }

  /* fdopendir() precludes us from continuing to use the input fd */
  dfd = dirfd(dir);
  if (fstat(dfd, &rb)) {
    warn("stat failed");
    goto done;
  }

  while (1) {
    struct dirent* d;
    int isdir = 0;

    errno = 0;
    if (!(d = readdir(dir))) {
      if (errno) {
        warn("failed to read directory");
        goto done;
      }
      break; /* end of directory */
    }

    if (!strcmp(d->d_name, ".") || !strcmp(d->d_name, ".."))
      continue;
#ifdef _DIRENT_HAVE_D_TYPE
    if (d->d_type == DT_DIR || d->d_type == DT_UNKNOWN)
#endif
    {
      struct stat sb;

      if (fstatat(dfd, d->d_name, &sb, AT_SYMLINK_NOFOLLOW)) {
        warn("stat of %s failed", d->d_name);
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
      warn("failed to unlink %s", d->d_name);
  }

  rc = 0; /* success */
done:
  if (dir)
    closedir(dir);
  else
    close(fd);
  return rc;
}

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

  if (mount(newroot, "/", NULL, MS_MOVE, NULL) < 0) {
    warn("failed to mount moving %s to /", newroot);
    goto fail;
  }

  if (chroot(".")) {
    warn("failed to change root");
    goto fail;
  }

  if (chdir("/")) {
    warn("cannot change directory to %s", "/");
    goto fail;
  }

  switch (fork()) {
    case 0: /* child */
    {
      struct statfs stfs;

      if (fstatfs(cfd, &stfs) == 0 &&
          (F_TYPE_EQUAL(stfs.f_type, STATFS_RAMFS_MAGIC) ||
           F_TYPE_EQUAL(stfs.f_type, STATFS_TMPFS_MAGIC)))
        recursiveRemove(cfd);
      else {
        warn("old root filesystem is not an initramfs");
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

static int try_to_run_init_process(const char* init_filename) {
  return execl(init_filename, init_filename, NULL);
}

static int pivot_root(const char* new_root, const char* put_old) {
  return syscall(__NR_pivot_root, new_root, put_old);
}

int main() {
  // mount rw overlayfs /initoverlayfs
  if (mount(NULL, "/", NULL, MS_REMOUNT, NULL)) {
    warn("failed to mount overlayfs");
    return errno;
  }

  if (pivot_root("/initoverlayfs", "/")) {
    warn("failed to pivot_root");
  }

  if (errno && switchroot("/initoverlayfs")) {
    warn("failed to switchroot");
    return errno;
  }

  // to-do parse 2init= karg also possibly
  try_to_run_init_process("/sbin/init");
  try_to_run_init_process("/etc/init");
  try_to_run_init_process("/bin/init");
  try_to_run_init_process("/bin/sh");

  // If you reach here you have failed, exec should have taken control of this
  // process
  warn("failed to exec init process: %s");
  return errno;
}
