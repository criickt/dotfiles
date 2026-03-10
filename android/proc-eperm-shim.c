#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

/* proot returns EPERM on /proc readlink; convert to EACCES for nix gc */
static void fix_errno(const char *path) {
    if (errno == EPERM && strncmp(path, "/proc/", 6) == 0)
        errno = EACCES;
}

ssize_t readlink(const char *path, char *buf, size_t bufsiz) {
    static ssize_t (*real)(const char *, char *, size_t);
    if (!real) real = dlsym(RTLD_NEXT, "readlink");
    ssize_t ret = real(path, buf, bufsiz);
    if (ret == -1) fix_errno(path);
    return ret;
}

ssize_t readlinkat(int fd, const char *path, char *buf, size_t bufsiz) {
    static ssize_t (*real)(int, const char *, char *, size_t);
    if (!real) real = dlsym(RTLD_NEXT, "readlinkat");
    ssize_t ret = real(fd, path, buf, bufsiz);
    if (ret == -1) fix_errno(path);
    return ret;
}

int lstat(const char *path, struct stat *st) {
    static int (*real)(const char *, struct stat *);
    if (!real) real = dlsym(RTLD_NEXT, "lstat");
    int ret = real(path, st);
    if (ret == -1) fix_errno(path);
    return ret;
}

int fstatat(int fd, const char *path, struct stat *st, int flags) {
    static int (*real)(int, const char *, struct stat *, int);
    if (!real) real = dlsym(RTLD_NEXT, "fstatat");
    int ret = real(fd, path, st, flags);
    if (ret == -1) fix_errno(path);
    return ret;
}
