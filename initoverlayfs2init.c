#include <sys/mount.h>
#include <errno.h>
#include <unistd.h>

static int try_to_run_init_process(const char* init_filename) {
  return execl(init_filename, init_filename, NULL);
}

int main() {
  if (mount(NULL, "/", NULL, MS_REMOUNT | MS_SILENT, NULL))
    return errno;

  // to-do parse 2init= karg also possibly
  try_to_run_init_process("/sbin/init");
  try_to_run_init_process("/etc/init");
  try_to_run_init_process("/bin/init");
  try_to_run_init_process("/bin/sh");

  // If you reach here you have failed, exec should have taken control of this
  // process
  return errno;
}
