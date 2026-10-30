#!/usr/bin/env python3
"""
ios_stats.py — седмичен iOS отчет за Taskify + Навици (App Store Connect API).

САМО ЧЕТЕНЕ по подразбиране. Не променя нищо в приложенията и НЕ пази ключове в кода.
Ключовете се четат от ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8

Данни:
  - Sales Reports (SALES / SUMMARY / DAILY) за последните N дни (по подразбиране 60):
      * нови изтегляния      (Product Type 1 / 1F / 1T)  — първо инсталиране
      * повторни изтегляния  (3 / 3F / 3T)               — reinstall / друго устройство
      * обновявания          (7 / 7F / 7T)
      * разбивка по държави и по дни (за новите изтегляния)
      * IAP (брой + Developer Proceeds) по продукт (IA*/F1)
  - Analytics Reports (ключ с роля Admin): installs, deletions, active devices,
      sessions, impressions, product page views. Генерират се асинхронно от Apple —
      `--setup-analytics` създава ONGOING заявка (еднократно); следващите пускания
      четат вече готовите инстанции. Изтривания/активни устройства за iOS идват САМО оттук.
  - Сравнителна таблица iOS vs Android (Android числата се подават в конфига).

Употреба:
  python3 ios_stats.py                          # 60 дни, Admin ключ по подразбиране
  python3 ios_stats.py --days 30
  python3 ios_stats.py --setup-analytics        # еднократна настройка на Analytics
  python3 ios_stats.py --out /path/to/folder    # + JSON изход

Изисква: pyjwt, cryptography.
ВАЖНО: не кръщавай файла на стандартен модул (inspect.py/json.py…) — чупи импортите.
"""
import argparse, gzip, io, json, os, sys, time, urllib.request, urllib.error
from collections import defaultdict
from datetime import date, timedelta

# ------------------------------------------------------------------ конфиг
ISSUER  = "3f2713b7-8091-4398-a640-42fd59f893f6"
VENDOR  = os.environ.get("ASC_VENDOR_NUMBER", "94318778")
KEYDIR  = os.path.expanduser("~/.appstoreconnect/private_keys")
BASE    = "https://api.appstoreconnect.apple.com"
DEFAULT_KEY = os.environ.get("ASC_KEY_ID", "CM7P755Z89")   # роля "Sales and Reports" (чете Sales + сваля Analytics)
# Забележка: `--setup-analytics` (СЪЗДАВАНЕ на нови report-заявки) иска роля Admin.
# Еднократната настройка е направена с Admin ключ RY2Q9H6UU3; за нея ползвай --key RY2Q9H6UU3.

APPS = {                       # name : (apple_id, sku)
    "Taskify": ("6768345070", "TASKIFY001"),
    "Навици":  ("6806278691", "habits1969"),
}

# Android числа (подадени ръчно; към 23.10.2026) за сравнителната таблица
ANDROID = {
    "Taskify": {"new": 169, "deletions": 135, "active": 76},
    "Навици":  {"new": 40,  "deletions": 20,  "active": 23},
}

NEW_TYPES        = {"1", "1F", "1T", "1E"}    # първо изтегляне
REDOWNLOAD_TYPES = {"3", "3F", "3T"}          # повторно изтегляне
UPDATE_TYPES     = {"7", "7F", "7T"}          # обновяване
IAP_TYPES        = {"IA1", "IA9", "IAY", "IAC", "IA5", "F1", "FI1"}

# ------------------------------------------------------------------ JWT / HTTP
def make_token(kid):
    import jwt
    with open(os.path.join(KEYDIR, f"AuthKey_{kid}.p8")) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
        key, algorithm="ES256", headers={"kid": kid, "typ": "JWT"},
    )

def api(kid, path, accept="application/json", method="GET", data=None):
    req = urllib.request.Request(BASE + path, method=method)
    req.add_header("Authorization", "Bearer " + make_token(kid))
    req.add_header("Accept", accept)
    body = None
    if data is not None:
        body = json.dumps(data).encode()
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, body, timeout=90) as r:
            return r.status, r.read(), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read(), dict(e.headers)
    except Exception as e:
        return "ERR", str(e).encode(), {}

# ------------------------------------------------------------------ Sales Reports
def fetch_sales_day(kid, day):
    path = (f"/v1/salesReports?filter[frequency]=DAILY&filter[reportType]=SALES"
            f"&filter[reportSubType]=SUMMARY&filter[vendorNumber]={VENDOR}"
            f"&filter[version]=1_0&filter[reportDate]={day.isoformat()}")
    st, body, _ = api(kid, path, accept="application/a-gzip, application/json")
    if st == 200:
        try:
            raw = gzip.GzipFile(fileobj=io.BytesIO(body)).read().decode("utf-8", "replace")
        except OSError:
            raw = body.decode("utf-8", "replace")
        lines = [l for l in raw.splitlines() if l.strip()]
        if not lines:
            return [], None
        hs = lines[0].split("\t")
        return [dict(zip(hs, ln.split("\t"))) for ln in lines[1:]], None
    if st == 404:
        return [], None
    try:
        e = json.loads(body.decode())["errors"][0]
        return [], f"{st} {e.get('code')}: {e.get('detail')}"
    except Exception:
        return [], f"{st}: {body[:160]!r}"

def collect_sales(kid, days):
    today = date.today()
    start = today - timedelta(days=days)
    agg = {n: {"new": 0, "redownloads": 0, "updates": 0,
               "by_country": defaultdict(int), "by_day": defaultdict(int),
               "iap_units": defaultdict(int), "iap_proceeds": defaultdict(float)}
           for n in APPS}
    id2name  = {aid: n for n, (aid, sku) in APPS.items()}
    sku2name = {sku: n for n, (aid, sku) in APPS.items()}
    first_err, days_seen = None, 0
    d = start
    while d < today:
        rows, err = fetch_sales_day(kid, d)
        if err:
            first_err = first_err or f"{d}: {err}"
        if rows:
            days_seen += 1
        for r in rows:
            name = id2name.get((r.get("Apple Identifier") or "").strip()) \
                   or sku2name.get((r.get("SKU") or "").strip())
            if not name:
                continue
            pt = (r.get("Product Type Identifier") or "").strip()
            try:    units = int(float(r.get("Units", "0") or 0))
            except ValueError: units = 0
            try:    proceeds = float(r.get("Developer Proceeds", "0") or 0)
            except ValueError: proceeds = 0.0
            a = agg[name]
            if pt in NEW_TYPES:
                a["new"] += units
                a["by_country"][(r.get("Country Code") or "").strip()] += units
                a["by_day"][(r.get("Begin Date") or "").strip()] += units
            elif pt in REDOWNLOAD_TYPES:
                a["redownloads"] += units
            elif pt in UPDATE_TYPES:
                a["updates"] += units
            elif pt in IAP_TYPES:
                a["iap_units"][pt] += units
                a["iap_proceeds"][pt] += proceeds * units
        time.sleep(0.15)
        d += timedelta(days=1)
    return agg, days_seen, first_err

# ------------------------------------------------------------------ Analytics Reports
def analytics_status(kid):
    """Връща per-app: има ли ONGOING заявка и колко reports са налични."""
    out = {}
    for name, (aid, sku) in APPS.items():
        st, body, _ = api(kid, f"/v1/apps/{aid}/analyticsReportRequests?limit=50")
        if st != 200:
            out[name] = {"ok": False, "info": f"{st}"}
            continue
        reqs = json.loads(body).get("data", [])
        out[name] = {"ok": True, "requests": [
            {"id": r["id"], "accessType": r["attributes"].get("accessType"),
             "stopped": r["attributes"].get("stoppedDueToInactivity")} for r in reqs]}
    return out

def setup_analytics(kid):
    """Създава ONGOING + ONE_TIME_SNAPSHOT analyticsReportRequest за всяко приложение.
    ONGOING = седмичен цикъл занапред; ONE_TIME_SNAPSHOT = исторически данни (до ~1 г.)."""
    for name, (aid, sku) in APPS.items():
        st, body, _ = api(kid, f"/v1/apps/{aid}/analyticsReportRequests?limit=50")
        have = {r["attributes"].get("accessType") for r in json.loads(body).get("data", [])} if st == 200 else set()
        for access in ("ONGOING", "ONE_TIME_SNAPSHOT"):
            if access in have:
                print(f"  {name}: вече има {access} заявка")
                continue
            payload = {"data": {"type": "analyticsReportRequests",
                                "attributes": {"accessType": access},
                                "relationships": {"app": {"data": {"type": "apps", "id": aid}}}}}
            st2, body2, _ = api(kid, "/v1/analyticsReportRequests", method="POST", data=payload)
            if st2 in (200, 201):
                print(f"  {name}: създадена {access} заявка {json.loads(body2)['data']['id']}")
            else:
                try: e = json.loads(body2.decode())["errors"][0]; print(f"  {name}: {access} ГРЕШКА {st2} {e.get('code')}: {e.get('detail')}")
                except Exception: print(f"  {name}: {access} ГРЕШКА {st2} {body2[:120]}")

# ------------------------------------------------------------------ печат
def report(agg, days, days_seen, astat, first_err):
    print(f"\n{'='*70}\n iOS отчет — последни {days} дни (данни за {days_seen} дни)\n{'='*70}")
    if first_err:
        print(f" ⚠ грешка при теглене: {first_err}")
    for name in APPS:
        a = agg[name]
        print(f"\n### {name}  ({APPS[name][0]})")
        print(f"  Нови изтегляния     : {a['new']}")
        print(f"  Повторни изтегляния : {a['redownloads']}")
        print(f"  Обновявания         : {a['updates']}")
        top = sorted(a["by_country"].items(), key=lambda x: -x[1])[:10]
        print("  Топ държави (нови)  : " + (", ".join(f"{c}={n}" for c, n in top) if top else "—"))
        if a["iap_units"]:
            for t, u in a["iap_units"].items():
                print(f"  IAP {t}: {u} бр, proceeds≈{a['iap_proceeds'][t]:.2f}")
        else:
            print("  IAP                 : 0")
    print(f"\n{'='*70}\n iOS vs Android  (Android: ръчно, към 23.10.2026)\n{'='*70}")
    print(f"  {'App':9} | {'iOS нови':>8} | {'And нови':>8} | {'iOS изтр.':>9} | {'And изтр.':>9} | {'iOS актив':>9} | {'And актив':>9}")
    for name in APPS:
        ios_del = ios_act = "—"   # идват от Analytics (async)
        print(f"  {name:9} | {agg[name]['new']:>8} | {ANDROID[name]['new']:>8} | "
              f"{ios_del:>9} | {ANDROID[name]['deletions']:>9} | {ios_act:>9} | {ANDROID[name]['active']:>9}")
    print("  (iOS изтривания/активни = от Analytics Reports; '—' = още не е генерирано)")
    print(f"\n Analytics Reports API:")
    for name, s in astat.items():
        if not s["ok"]:
            print(f"  {name}: недостъпно ({s['info']})")
        elif not s.get("requests"):
            print(f"  {name}: достъпно, но НЯМА заявка още → пусни `--setup-analytics`")
        else:
            print(f"  {name}: {len(s['requests'])} заявки " +
                  ", ".join(f"[{r['accessType']}{' STOPPED' if r['stopped'] else ''}]" for r in s["requests"]))

# ------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=int, default=60)
    ap.add_argument("--key", default=DEFAULT_KEY)
    ap.add_argument("--setup-analytics", action="store_true")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    if args.setup_analytics:
        print("Настройка на Analytics (ONGOING заявки):")
        setup_analytics(args.key)
        print("Данните се генерират от Apple асинхронно (обикновено до ~1 ден).")
        return

    astat = analytics_status(args.key)
    agg, days_seen, first_err = collect_sales(args.key, args.days)
    report(agg, args.days, days_seen, astat, first_err)

    if args.out:
        os.makedirs(args.out, exist_ok=True)
        dump = {n: {k: (dict(v) if isinstance(v, defaultdict) else v)
                    for k, v in agg[n].items()} for n in APPS}
        p = os.path.join(args.out, f"ios_stats_{date.today().isoformat()}.json")
        with open(p, "w") as f:
            json.dump(dump, f, ensure_ascii=False, indent=2)
        print(f"\n JSON записан: {p}")

if __name__ == "__main__":
    main()
