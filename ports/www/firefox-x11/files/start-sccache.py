"""Start the shared build cache without inheriting MacPorts' private pipes."""
import os
import socket
import subprocess
import sys


def running():
    try:
        with socket.create_connection(('127.0.0.1', 4227), timeout=1):
            return True
    except OSError:
        return False


if not running():
    env = dict(os.environ, SCCACHE_DIR=sys.argv[2], SCCACHE_SERVER_PORT='4227',
               SCCACHE_CACHE_SIZE='20G')
    # mach's compiler children can inherit MacPorts' output descriptors above
    # stderr. A detached cache retaining one keeps port waiting for EOF even
    # after mach has exited. Explicitly close all nonstandard descriptors.
    result = subprocess.run([sys.argv[1], '--start-server'], env=env,
                            close_fds=True)
    if result.returncode and not running():
        raise SystemExit(result.returncode)
