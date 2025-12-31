from __future__ import annotations
import re, shutil, time, json
from pathlib import Path

PY = Path(r"C:\GuardianFW\GuardianDNS\guardian_dns.py")

DOH_HELPERS = r"""
DOH_PATH = BASE / "doh.json"

DOH_CACHE = {"loaded_at": 0.0, "cfg": None}
DOH_RELOAD_SECONDS = 5

def load_doh_cfg() -> dict:
    now = time.time()
    if DOH_CACHE["cfg"] is not None and (now - DOH_CACHE["loaded_at"]) < DOH_RELOAD_SECONDS:
        return DOH_CACHE["cfg"]
    try:
        obj = json.loads(DOH_PATH.read_text(encoding="utf-8-sig"))
        if not isinstance(obj, dict):
            obj = {}
    except Exception:
        obj = {}
    DOH_CACHE["loaded_at"] = now
    DOH_CACHE["cfg"] = obj
    return obj

_REQUESTS_SESSION = None

def forward_to_upstream_doh(raw: bytes) -> bytes:
    cfg = load_doh_cfg() or {}
    url1 = (cfg.get("primary") or "").strip()
    url2 = (cfg.get("secondary") or "").strip()
    timeout = float(cfg.get("timeout_seconds") or 3)

    # If no DoH configured, signal caller to use UDP path
    if not url1 and not url2:
        raise RuntimeError("DoH not configured")

    global _REQUESTS_SESSION
    if _REQUESTS_SESSION is None:
        import requests
        _REQUESTS_SESSION = requests.Session()

    import requests
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
            # DoH returns wire-format DNS message in body
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

    # must have forward_to_upstream and UPSTREAM_DNS in current file
    for needle in ("def forward_to_upstream", "UPSTREAM_DNS"):
        if needle not in text:
            raise SystemExit(f"Refusing to patch: missing {needle}")

    bak = PY.with_name(PY.name + f".bak_dohPatch_{time.strftime('%Y%m%d_%H%M%S')}")
    shutil.copy2(PY, bak)
    print("Backup:", bak)

    # insert helpers before forward_to_upstream if not present
    if "def forward_to_upstream_doh" not in text:
        m = re.search(r'(?m)^\s*def\s+forward_to_upstream\s*\(.*\)\s*:\s*$', text)
        if not m:
            raise SystemExit("Refusing to patch: cannot find def forward_to_upstream(...)")
        text = text[:m.start()] + DOH_HELPERS + "\n\n" + text[m.start():]

    # replace forward_to_upstream body to: try DoH -> fallback UDP
    m2 = re.search(r'(?ms)^\s*def\s+forward_to_upstream\s*\(raw:\s*bytes\)\s*->\s*bytes\s*:\s*.*?(?=^\s*def\s+|\Z)', text)
    if not m2:
        # also accept no annotations
        m2 = re.search(r'(?ms)^\s*def\s+forward_to_upstream\s*\(.*?\)\s*:\s*.*?(?=^\s*def\s+|\Z)', text)
    if not m2:
        raise SystemExit("Refusing to patch: cannot locate forward_to_upstream function block")

    repl = r"""
def forward_to_upstream(raw: bytes) -> bytes:
    # Prefer DoH if configured, fallback to UDP upstream
    try:
        return forward_to_upstream_doh(raw)
    except Exception as e:
        # fallback UDP
        s = get_upstream_sock()
        try:
            s.sendto(raw, UPSTREAM_DNS)
            resp, _ = s.recvfrom(4096)
            return resp
        except Exception:
            # bubble up to serve() fail-open logic
            raise
"""
    text = text[:m2.start()] + repl + "\n\n" + text[m2.end():]

    PY.write_text(text, encoding="utf-8")
    print("Patched DoH upstream (requests) + UDP fallback.")

if __name__ == "__main__":
    main()
