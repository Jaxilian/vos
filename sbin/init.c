#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>

void mount_or_die(
    const char *source,
    const char *target,  
    const char *type,
    unsigned long flags,
    const void *data) {

    if (mount(
        source,
        target,
        type,
        flags,
        data ) != 0) {

        perror("mount failed");
        exit(1);
    }
}

int main() {
    printf("Initializing VOS ...\n");

    mount_or_die("", "/", "rootfs", MS_REMOUNT, NULL);
    mount_or_die("proc", "/proc", "proc", 0, NULL);
    mount_or_die("sysfs", "/sys", "sysfs", 0, NULL);
    mount_or_die("devtmpfs", "/dev", "devtmpfs", 0, NULL);
    mkdir("/dev/pts", 0755);
    mount_or_die("devpts", "/dev/pts", "devpts", 0, NULL);

    mount_or_die("tmpfs", "/run", "tmpfs", 0, "mode=755");
    mount_or_die("tmpfs", "/tmp", "tmpfs", 0, "mode=1777");

    mount_or_die(
        "", "/dev", "devtmpfs",
        MS_REMOUNT | MS_NOSUID | MS_STRICTATIME,
        "mode=0755"
    );

    if (fork() == 0) {
        execl("/bin/sh", "/bin/sh", NULL);
        perror("exec failed");
        exit(1);
    }

    while (1) {
        wait(NULL);
    }

    return 0;
}