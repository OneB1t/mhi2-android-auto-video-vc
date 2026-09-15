/*
 * dmdt_flush.so:
 * Interposes _exit() in /eso/bin/apps/dmdt.
 * Standard dmdt calls _exit(0) upon normal completion without calling
 * fflush(stdout) or exit(0). When stdout is a pipe or file, libc block-buffers
 * its output (4KB buffer); because dmdt's output is ~500-800 bytes, the entire
 * output is lost when _exit destroys the process address space.
 * This interposer flushes stdout and stderr before calling _Exit(), allowing
 * dmdt output to be reliably captured via popen(), pipes, and redirections.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

void _exit(int status)
{
    (void)fflush(stdout);
    (void)fflush(stderr);
    _Exit(status);
}
