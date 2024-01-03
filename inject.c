// Petit programme pour court-circuiter les appels aux fonctions de la libc

#define _GNU_SOURCE

#include <string.h>
#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

typedef pid_t (*real_fork_t)(void);
typedef ssize_t (*real_read_t)(int, void *, size_t);
typedef ssize_t (*real_write_t)(int, const void *, size_t);
typedef size_t (*real_fread_t)(void *, size_t, size_t, FILE*);
typedef size_t (*real_fwrite_t)(const void *, size_t, size_t, FILE*);
typedef ssize_t (*real_copy_file_range_t)(int fd_in, off_t *off_in, int fd_out, off_t *off_out, size_t len, unsigned int flags);

static pid_t trololo_child_pid = 0;
FILE* trololo(void) {
       static FILE *lolo = NULL;
       if(!lolo) lolo = fdopen(3, "w");
       if(!lolo) {
	       perror("lolo");
	       exit(1);
       }
       return lolo;
}

int trace_all() {
	static int z=0;
	static int traceall=0;
	if (!z++)
		traceall = getenv("TRACEALL") != NULL;
	return traceall;
}

int trace_child() {
	static int z=0;
	static int tracechild=0;
	if (!z++)
		tracechild = getenv("TRACECHILD") != NULL;
	return tracechild;
}

pid_t fork(void) {
	FILE *f = fdopen(3, "w");
	if (trace_all())
		fprintf(trololo(), "fork()\n");
	fflush(trololo());

	pid_t child_pid = ((real_fork_t)dlsym(RTLD_NEXT, "fork"))();
	if (child_pid && !trololo_child_pid) {
		trololo_child_pid = child_pid;
	}
	return child_pid;
}

ssize_t read(int fd, void *data, size_t size) {
	static int x=0;

	if (trace_child() && trololo_child_pid) {
		return ((real_read_t)dlsym(RTLD_NEXT, "read"))(fd, data, size);
	}

	FILE *f = fdopen(3, "w");
	if (!x++ || trace_all())
		fprintf(trololo(), "read(%ld)\n", size);
		fflush(trololo());
	return ((real_read_t)dlsym(RTLD_NEXT, "read"))(fd, data, size);
}
ssize_t write(int fd, const void *data, size_t size) {
	static int y=0;

	if (trace_child()) {
		if (trololo_child_pid) {
			return ((real_write_t)dlsym(RTLD_NEXT, "write"))(fd, data, size);
		}
	}

	if (!y++ || trace_all())
		fprintf(trololo(), "write(%ld)\n", size);
		fflush(trololo());
	return ((real_write_t)dlsym(RTLD_NEXT, "write"))(fd, data, size);
}