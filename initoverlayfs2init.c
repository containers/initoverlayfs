#include <sys/mount.h>
#include <errno.h>
#include <unistd.h>

static int try_to_run_init_process(const char* init_filename) {
  return execl(init_filename, init_filename, NULL);
}

int main() {
  const int ret = mount(NULL, "/", NULL, MS_REMOUNT | MS_SILENT, NULL);

  // to-do parse 2init= karg also possibly
  if (!try_to_run_init_process("/sbin/init") ||
      !try_to_run_init_process("/etc/init") ||
      !try_to_run_init_process("/bin/init") ||
      !try_to_run_init_process("/bin/sh"))
    return ret;

  // No working init found
  return errno;
}
