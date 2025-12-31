import os, sys, ctypes

def real_exe_path():
    buf = ctypes.create_unicode_buffer(4096)
    ctypes.windll.kernel32.GetModuleFileNameW(None, buf, 4096)
    return buf.value

print("RUN_SERVICE PID =", os.getpid(), "PPID =", os.getppid(), flush=True)
print("RUN_SERVICE sys.executable =", sys.executable, flush=True)
print("RUN_SERVICE real_exe_path  =", real_exe_path(), flush=True)
print("RUN_SERVICE VIRTUAL_ENV   =", os.environ.get("VIRTUAL_ENV"), flush=True)
print("RUN_SERVICE PATH          =", os.environ.get("PATH"), flush=True)

import uvicorn
uvicorn.run("app.main:app", host="127.0.0.1", port=5050, log_level="info")
