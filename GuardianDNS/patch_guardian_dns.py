from __future__ import annotations
import re, shutil, time
from pathlib import Path

PY = Path(r"C:\GuardianFW\GuardianDNS\guardian_dns.py")

NEW_HELPERS = r"""
def normalize_domain(d: str) -> str:
    d = (d or "").strip().lower()
    if d.endswith("."):
        d = d[:-1]
    return d

def load_active_profile() -> str:
    try:
        p = ACTIVE_PROFILE_PATH.read_text(encoding="utf-8-sig").strip()
        return p if p else "Kids"
    except Exception:
        return "Kids"

def load_timed_allow() -> dict:
    \"\"\"returns dict(domain -> expires_epoch_seconds)\"\"\"
    out = {}
    try:
        import datetime, json
        obj = json.loads(TIMED_ALLOW_PATH.read_text(encoding="utf-8-sig"))
        items = obj.get("items", []) or []
        now = time.time()
        for it in items:
            dom = normalize_domain(it.get("domain", ""))
            exp = it.get("expires_at", "")
            if not dom or not exp:
                continue
            try:
                dt = datetime.datetime.fromisoformat(exp.replace("Z","+00:00"))
                exp_ts = dt.timestamp()
                if exp_ts > now:
                    out[dom] = exp_ts
            except Exception:
                continue
    except Exception:
        pass
    return out

def _build_allow_block_sets(cfg: dict) -> tuple[set, set]:
    \"\"\"
    Supports BOTH formats:
      1) old: {"domains":[...]}
      2) new: {"global":{"allow":[...],"block":[...]}, "profiles":{"Kids":{...}}, ...}
    \"\"\"
    allow, block = set(), set()

    # old style fallback
    for d in (cfg.get("domains", []) or []):
        if isinstance(d, str):
            block.add(normalize_domain(d))

    # new style
    profile = load_active_profile()
    g = (cfg.get("global", {}) or {})
    p = ((cfg.get("profiles", {}) or {}).get(profile, {}) or {})

    for d in (g.get("allow", []) or []): allow.add(normalize_domain(d))
    for d in (g.get("block", []) or []): block.add(normalize_domain(d))
    for d in (p.get("allow", []) or []): allow.add(normalize_domain(d))
    for d in (p.get("block", []) or []): block.add(normalize_domain(d))

    # allow wins
    block = {d for d in block if d and d not in allow}
    allow = {d for d in allow if d}
    return allow, block

def should_block(domain: str, qtype: str, cfg: dict) -> bool:
    d = normalize_domain(domain)

    # temporary allow overrides everything
    ta = load_timed_allow()
    if d in ta:
        log(f"[ALLOW-TEMP] {d} ({qtype}) -> until {int(ta[d])}")
        return False

    allow, block = _build_allow_block_sets(cfg or {})

    # exact allow
    if d in allow:
        log(f"[ALLOW] {d} ({qtype}) -> allowlist")
        return False
    if d in block:
        return True

    # suffix match
    parts = d.split(".")
    for i in range(1, len(parts)):
        suf = ".".join(parts[i:])
        if suf in allow:
            log(f"[ALLOW] {d} ({qtype}) -> allowlist ({suf})")
            return False
        if suf in block:
            return True

    return False
"""

NEW_SERVE = r"""
def serve():
    log("[INFO] GuardianDNS starting on 127.0.0.1:53 (UDP)")
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    disable_udp_connreset(s)
    s.bind(("127.0.0.1", 53))

    while True:
        try:
            raw, addr = s.recvfrom(4096)
        except ConnectionResetError:
            continue
        except Exception:
            continue

        try:
            req = DNSRecord.parse(raw)
            cfg = load_list() or {}
            qname = str(req.q.qname).rstrip(".")
            qtype = QTYPE[req.q.qtype]

            if should_block(qname, qtype, cfg):
                log(f"[BLOCK] {qname} ({qtype}) -> sinkhole")
                resp = make_sinkhole_reply(req, "0.0.0.0")
            else:
                resp = forward_to_upstream(raw)

            s.sendto(resp, addr)

        except Exception as e:
            log(f"[ERR] {e}")
            try:
                resp = forward_to_upstream(raw)
                s.sendto(resp, addr)
            except Exception as e2:
                log(f"[ERR] upstream fail-open failed: {e2}")
"""

def main():
    if not PY.exists():
        raise SystemExit(f"Missing: {PY}")

    text = PY.read_text(encoding="utf-8-sig", errors="replace")

    # sanity: must contain load_list and forward_to_upstream and make_sinkhole_reply
    for needle in ("def load_list", "def forward_to_upstream", "def make_sinkhole_reply"):
        if needle not in text:
            raise SystemExit(f"Refusing to patch: missing {needle}")

    # backup
    bak = PY.with_name(PY.name + f".bak_safePatch_{time.strftime('%Y%m%d_%H%M%S')}")
    shutil.copy2(PY, bak)
    print("Backup:", bak)

    # ensure paths exist (TIMED_ALLOW_PATH, ACTIVE_PROFILE_PATH)  if missing, insert them near LIST_PATH
    if "TIMED_ALLOW_PATH" not in text:
        # insert after LIST_PATH definition if present
        m = re.search(r'(?m)^\s*LIST_PATH\s*=\s*.*$', text)
        if not m:
            raise SystemExit("Refusing to patch: cannot find LIST_PATH assignment to add TIMED_ALLOW_PATH")
        insert = '\nACTIVE_PROFILE_PATH = BASE / "active-profile.txt"\nTIMED_ALLOW_PATH    = BASE / "timed-allow.json"\n'
        text = text[:m.end()] + insert + text[m.end():]

    # insert helpers if normalize_domain / should_block not present
    if "def should_block" not in text:
        # insert helpers before serve()
        mserve = re.search(r'(?m)^\s*def\s+serve\s*\(\s*\)\s*:\s*$', text)
        if not mserve:
            raise SystemExit("Refusing to patch: cannot find def serve():")
        text = text[:mserve.start()] + NEW_HELPERS + "\n\n" + text[mserve.start():]

    # replace serve() body safely
    m1 = re.search(r'(?m)^\s*def\s+serve\s*\(\s*\)\s*:\s*$', text)
    if not m1:
        raise SystemExit("Refusing to patch: cannot find serve() to replace")

    # end at main guard if present; otherwise end at EOF
    m2 = re.search(r'(?m)^\s*if\s+__name__\s*==\s*[\'"]__main__[\'"]\s*:\s*$', text)
    end = m2.start() if m2 else len(text)

    before = text[:m1.start()]
    after  = text[end:]

    text2 = before + NEW_SERVE + "\n\n" + after

    PY.write_text(text2, encoding="utf-8")
    print("Patched serve() + temp-allow helpers.")

if __name__ == "__main__":
    main()
