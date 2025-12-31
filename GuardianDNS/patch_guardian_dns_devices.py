from __future__ import annotations
import re, shutil, time, json
from pathlib import Path

PY = Path(r"C:\GuardianFW\GuardianDNS\guardian_dns.py")

NEW_DEVICE_HELPERS = r"""
DEVICES_PATH = BASE / "devices.json"
DEVICES_CACHE = {"loaded_at": 0.0, "data": None}
DEVICES_RELOAD_SECONDS = 3

def load_devices_cfg() -> dict:
    now = time.time()
    if DEVICES_CACHE["data"] is not None and (now - DEVICES_CACHE["loaded_at"]) < DEVICES_RELOAD_SECONDS:
        return DEVICES_CACHE["data"]
    try:
        obj = json.loads(DEVICES_PATH.read_text(encoding="utf-8-sig"))
        if not isinstance(obj, dict):
            obj = {}
    except Exception:
        obj = {}
    DEVICES_CACHE["loaded_at"] = now
    DEVICES_CACHE["data"] = obj
    return obj

def get_profile_for_client_ip(client_ip: str, cfg: dict) -> str:
    # priority:
    # 1) devices.json explicit per-IP
    # 2) devices.json default_profile
    # 3) active-profile.txt (your dashboard toggle)
    # 4) fallback Kids
    dcfg = load_devices_cfg() or {}
    devs = (dcfg.get("devices", {}) or {})
    rec = devs.get(client_ip, {}) if isinstance(devs, dict) else {}
    prof = (rec.get("profile") if isinstance(rec, dict) else None) or (dcfg.get("default_profile") if isinstance(dcfg, dict) else None)
    if prof:
        return str(prof).strip() or "Kids"
    try:
        p = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8-sig").strip()
        return p if p else "Kids"
    except Exception:
        return "Kids"
"""

REPLACE_SHOULD_BLOCK = r"""
def should_block(domain: str, qtype: str, cfg: dict, client_ip: str = "") -> bool:
    d = normalize_domain(domain)

    # temporary allow overrides everything
    ta = load_timed_allow()
    if d in ta:
        log(f"[ALLOW-TEMP] {d} ({qtype}) -> until {int(ta[d])}")
        return False

    # Choose profile per device IP
    profile = get_profile_for_client_ip(client_ip or "", cfg or {})

    allow, block = set(), set()

    # old style fallback
    for x in (cfg.get("domains", []) or []):
        if isinstance(x, str):
            block.add(normalize_domain(x))

    # new style global + profile
    g = (cfg.get("global", {}) or {})
    p = ((cfg.get("profiles", {}) or {}).get(profile, {}) or {})

    for x in (g.get("allow", []) or []): allow.add(normalize_domain(x))
    for x in (g.get("block", []) or []): block.add(normalize_domain(x))
    for x in (p.get("allow", []) or []): allow.add(normalize_domain(x))
    for x in (p.get("block", []) or []): block.add(normalize_domain(x))

    # allow wins
    block = {x for x in block if x and x not in allow}
    allow = {x for x in allow if x}

    # exact allow/block
    if d in allow:
        log(f"[ALLOW] {d} ({qtype}) -> allowlist [{profile}]")
        return False
    if d in block:
        return True

    # suffix allow/block
    parts = d.split(".")
    for i in range(1, len(parts)):
        suf = ".".join(parts[i:])
        if suf in allow:
            log(f"[ALLOW] {d} ({qtype}) -> allowlist [{profile}] ({suf})")
            return False
        if suf in block:
            return True

    return False
"""

def main():
    if not PY.exists():
        raise SystemExit(f"Missing: {PY}")

    text = PY.read_text(encoding="utf-8-sig", errors="replace")

    # Must already contain normalize_domain and load_timed_allow (from your previous successful patch)
    for needle in ("def normalize_domain", "def load_timed_allow", "ACTIVE_PROFILE_PATH"):
        if needle not in text:
            raise SystemExit(f"Refusing to patch: missing {needle}")

    # backup
    bak = PY.with_name(PY.name + f".bak_devicesPatch_{time.strftime('%Y%m%d_%H%M%S')}")
    shutil.copy2(PY, bak)
    print("Backup:", bak)

    # Insert device helpers if missing
    if "def get_profile_for_client_ip" not in text:
        mserve = re.search(r'(?m)^\s*def\s+serve\s*\(\s*\)\s*:\s*$', text)
        if not mserve:
            raise SystemExit("Refusing to patch: cannot find def serve(): to insert helpers before it")
        text = text[:mserve.start()] + NEW_DEVICE_HELPERS + "\n\n" + text[mserve.start():]

    # Replace should_block(...) definition completely
    m_sb = re.search(r'(?ms)^\s*def\s+should_block\s*\(.*?\)\s*:\s*.*?(?=^\s*def\s+|\Z)', text)
    if not m_sb:
        raise SystemExit("Refusing to patch: cannot find should_block() to replace")
    text = text[:m_sb.start()] + REPLACE_SHOULD_BLOCK + "\n\n" + text[m_sb.end():]

    # Ensure serve() calls should_block with client IP
    # Replace: should_block(qname, qtype, cfg)  -> should_block(qname, qtype, cfg, addr[0])
    text = re.sub(r'should_block\(\s*qname\s*,\s*qtype\s*,\s*cfg\s*\)',
                  r'should_block(qname, qtype, cfg, addr[0])', text)

    PY.write_text(text, encoding="utf-8")
    print("Patched per-device profile selection.")

if __name__ == "__main__":
    main()
