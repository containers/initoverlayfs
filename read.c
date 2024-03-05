#include <sys/time.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>

#define BUFFER_SIZE (1 * 1024 * 1024)

int main(int argc, char* argv[])
{
    unsigned char buffer[BUFFER_SIZE]; // 1 MiB buffer

    const int fd = open(argv[1], O_RDONLY);
    while (read(fd, buffer, BUFFER_SIZE) > 0);
    close(fd);

    printf("Early service started");

    return 0;
}

