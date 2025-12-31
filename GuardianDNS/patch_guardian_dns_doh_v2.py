from __future__ import annotations
import re, shutil, time
from pathlib import Path

PY = Path(r"C:\GuardianFW\GuardianDNS\guardian_dns.py")

DOH_HELPERS = r"""
DOH_PATH = BASE / "doh.json"
DOH_CACHE = {"loaded_at": 0.0, "cfg": None}
DOH_RELOAD_SECONDS = 5
_REQUESTS_SESSION = None

def load_doh_cfg() -> dict:
    now = time.time()
    if DOH_CACHE["cfg"] is not None and (now - DOH_CACHE["loaded_at"]) < DOH_RELOAD_SECONDS:
        return DOH_CACHE["cfg"]
    try:
        import json
        obj = json.loads(DOH_PATH.read_text(encoding="utf-8-sig"))
        if not isinstance(obj, dict):
            obj = {}
    except Exception:
        obj = {}
    DOH_CACHE["loaded_at"] = now
    DOH_CACHE["cfg"] = obj
    return obj

def forward_to_upstream_doh(raw: bytes) -> bytes:
    cfg = load_doh_cfg() or {}
    url1 = (cfg.get("primary") or "").strip()
    url2 = (cfg.get("secondary") or "").strip()
    timeout = float(cfg.get("timeout_seconds") or 3)

    if not url1 and not url2:
        raise RuntimeError("DoH not configured")

    global _REQUESTS_SESSION
    if _REQUESTS_SESSION is None:
        import requests
        _REQUESTS_SESSION = requests.Session()

    headers = {
        "accept": "application/dns-message",
        "content-type": "application/dns-message",
        "user-agent": "GuardianDNS/1.0",
    }

    last_err = None
    for url in (url1, url2):
        if not url:
            continue
        try:
            r = _REQUESTS_SESSION.post(url, data=raw, headers=headers, timeout=timeout)
            r.raise_for_status()
            if not r.content:
                raise RuntimeError("Empty DoH response")
            return r.content
        except Exception as e:
            last_err = e
            continue

    raise RuntimeError(f"DoH failed: {last_err}")
"""

def main():
    if not PY.exists():
        raise SystemExit(f"Missing: {PY}")

    text = PY.read_text(encoding="utf-8-sig", errors="replace")

    # We need serve() and some existing UDP forwarding path indicators
    if "def serve" not in text:
        raise SystemExit("Refusing to patch: cannot find serve()")
    if "sendto(" not in text:
        raise SystemExit("Refusing to patch: no UDP upstream sendto() found in file")

    # backup
    bak = PY.with_name(PY.name + f".bak_dohPatch2_{time.strftime('%Y%m%d_%H%M%S')}")
    shutil.copy2(PY, bak)
    print("Backup:", bak)

    # Insert helpers before serve() if not already present
    if "def forward_to_upstream_doh" not in text:
        mserve = re.search(r'(?m)^\s*def\s+serve\s*\(\s*\)\s*:\s*$', text)
        if not mserve:
            raise SystemExit("Refusing: cannot find serve() header for insertion")
        text = text[:mserve.start()] + DOH_HELPERS + "\n\n" + text[mserve.start():]

    # Patch serve() call site: replace "resp = <forward_func>(raw)" with DoH-prefer wrapper
    # We look for a simple assignment line: resp = SOMEFUNC(raw)
    # then wrap it:
    #   try: resp = forward_to_upstream_doh(raw)
    #   except: resp = SOMEFUNC(raw)
    #
    # This avoids needing to rename / replace your original forwarding function.
    pattern = r'(?m)^(?P<indent>\s*)resp\s*=\s*(?P<fn>[A-Za-z_]\w*)\(\s*raw\s*\)\s*$'
    m = re.search(pattern, text)
    if not m:
        raise SystemExit("Refusing: cannot find line like 'resp = SOMEFUNC(raw)' to patch in serve()")

    indent = m.group("indent")
    fn = m.group("fn")

    block = (
        f"{indent}try:\n"
        f"{indent}    resp = forward_to_upstream_doh(raw)\n"
        f"{indent}except Exception:\n"
        f"{indent}    resp = {fn}(raw)\n"
    )

    text = text[:m.start()] + block + text[m.end():]
    PY.write_text(text, encoding="utf-8")
    print(f"Patched DoH at serve() callsite; UDP fallback uses: {fn}(raw)")

if __name__ == "__main__":
    main()
