#!/usr/bin/env python3
"""
Synthetic logistics data generator for the Snowflake delivery analytics platform.
Everything is SYNTHETIC. Standard library only (no installs needed).

Usage:
  python3 generate_data.py --shipments 100000 --out ./out
  python3 generate_data.py --shipments 5000000 --days 140 --out ./out   (big run)
"""
import argparse
import csv
import json
import os
import random
from collections import defaultdict
from datetime import datetime, timedelta

# hub_id, hub_name, city, state, region, capacity_per_day
HUBS = [
    ("H01", "Delhi Hub", "Delhi", "Delhi", "North", 9000),
    ("H02", "Mumbai Hub", "Mumbai", "Maharashtra", "West", 10000),
    ("H03", "Bengaluru Hub", "Bengaluru", "Karnataka", "South", 9500),
    ("H04", "Chennai Hub", "Chennai", "Tamil Nadu", "South", 8000),
    ("H05", "Hyderabad Hub", "Hyderabad", "Telangana", "South", 8000),
    ("H06", "Kolkata Hub", "Kolkata", "West Bengal", "East", 7000),
    ("H07", "Pune Hub", "Pune", "Maharashtra", "West", 6000),
    ("H08", "Ahmedabad Hub", "Ahmedabad", "Gujarat", "West", 6000),
    ("H09", "Jaipur Hub", "Jaipur", "Rajasthan", "North", 4500),
    ("H10", "Lucknow Hub", "Lucknow", "Uttar Pradesh", "North", 4500),
    ("H11", "Coimbatore Hub", "Coimbatore", "Tamil Nadu", "South", 3500),
    ("H12", "Kochi Hub", "Kochi", "Kerala", "South", 3000),
    ("H13", "Bhubaneswar Hub", "Bhubaneswar", "Odisha", "East", 2500),
    ("H14", "Nagpur Hub", "Nagpur", "Maharashtra", "Central", 3000),
    ("H15", "Patna Hub", "Patna", "Bihar", "East", 3000),
    ("H16", "Chandigarh Hub", "Chandigarh", "Chandigarh", "North", 3000),
]
PIN_PREFIX = {"Delhi": "110", "Mumbai": "400", "Bengaluru": "560", "Chennai": "600",
              "Hyderabad": "500", "Kolkata": "700", "Pune": "411", "Ahmedabad": "380",
              "Jaipur": "302", "Lucknow": "226", "Coimbatore": "641", "Kochi": "682",
              "Bhubaneswar": "751", "Nagpur": "440", "Patna": "800", "Chandigarh": "160"}
BAD_HUBS = {"H06", "H10", "H15"}   # Kolkata, Lucknow, Patna: planted problem hubs

FIRST = ["Aarav", "Vivaan", "Aditya", "Arjun", "Karthik", "Rahul", "Rohan", "Suresh", "Vikram",
         "Anil", "Priya", "Ananya", "Divya", "Kavya", "Meera", "Neha", "Pooja", "Sneha",
         "Lakshmi", "Deepa", "Manoj", "Ravi", "Sanjay", "Harish", "Nisha", "Swathi"]
LAST = ["Sharma", "Verma", "Iyer", "Nair", "Reddy", "Patel", "Singh", "Kumar", "Das", "Gupta",
        "Menon", "Rao", "Chauhan", "Mishra", "Pillai", "Joshi", "Banerjee", "Shetty", "Yadav", "Naidu"]
PACKAGE_TYPES = ["DOCUMENT", "PARCEL", "FRAGILE", "ELECTRONICS", "APPAREL"]
VEHICLES = ["BIKE", "BIKE", "BIKE", "SCOOTER", "VAN"]
COMPLAINT_CATS = {
    "LATE_DELIVERY": ["Parcel arrived much later than promised.", "Delivery was delayed by days."],
    "DAMAGED": ["Package arrived damaged.", "Item inside was broken."],
    "RIDER_BEHAVIOUR": ["Rider was rude on the call.", "Rider did not wait at the address."],
    "WRONG_ADDRESS": ["Rider went to the wrong address.", "Address was marked incorrect without a call."],
    "STATUS_NOT_UPDATING": ["Tracking has not updated for a long time."],
}
SLA_HOURS = {  # (intra_city, inter_city)
    "EXPRESS": (18, 48), "STANDARD": (36, 72), "ECONOMY": (72, 120),
}
SPEED = {"EXPRESS": 0.7, "STANDARD": 1.0, "ECONOMY": 1.3}
WEEKDAY_WEIGHT = [1.0, 1.0, 1.0, 1.0, 1.05, 0.9, 0.7]
HOUR_WEIGHTS = [1] * 7 + [3, 5, 6, 6, 5, 5, 5, 5, 5, 5, 5, 4, 3, 2, 1, 1, 1]   # 24 values


def fmt(dt):
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def hrs(rng, a, b):
    return timedelta(hours=rng.uniform(a, b))


def phone(rng):
    return str(rng.randint(6, 9)) + "".join(str(rng.randint(0, 9)) for _ in range(9))


class DailyWriter:
    """Keeps one open file per date; closes dates that can no longer receive rows."""

    def __init__(self, folder, prefix, ext, header=None):
        os.makedirs(folder, exist_ok=True)
        self.folder, self.prefix, self.ext, self.header = folder, prefix, ext, header
        self.handles = {}

    def write(self, day, row):
        key = day.strftime("%Y%m%d")
        if key not in self.handles:
            fh = open(os.path.join(self.folder, f"{self.prefix}_{key}.{self.ext}"),
                      "w", newline="", encoding="utf-8")
            w = csv.writer(fh) if self.ext == "csv" else None
            if w and self.header:
                w.writerow(self.header)
            self.handles[key] = (fh, w)
        fh, w = self.handles[key]
        if w:
            w.writerow(row)
        else:
            fh.write(json.dumps(row) + "\n")

    def close_before(self, day):
        limit = day.strftime("%Y%m%d")
        for key in [k for k in self.handles if k < limit]:
            self.handles.pop(key)[0].close()

    def close_all(self):
        for fh, _ in self.handles.values():
            fh.close()
        self.handles.clear()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--shipments", type=int, default=100000)
    ap.add_argument("--start", default="2026-06-01")
    ap.add_argument("--days", type=int, default=140)
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--out", default="./out")
    a = ap.parse_args()

    rng = random.Random(a.seed)
    start = datetime.strptime(a.start, "%Y-%m-%d")
    cutoff = start + timedelta(days=a.days)
    os.makedirs(a.out, exist_ok=True)

    # ---------- reference data ----------
    with open(os.path.join(a.out, "hubs.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["hub_id", "hub_name", "city", "state", "region", "capacity_per_day"])
        w.writerows(HUBS)
    hub_by_city = {h[2]: h[0] for h in HUBS}
    hub_ids = [h[0] for h in HUBS]
    hub_weights = [h[5] for h in HUBS]

    riders, active = [], defaultdict(list)
    rid = 0
    for h in HUBS:
        for _ in range(max(25, h[5] // 120)):
            rid += 1
            r = f"R{rid:05d}"
            riders.append((r, f"{rng.choice(FIRST)} {rng.choice(LAST)}", phone(rng), h[0],
                           rng.choice(VEHICLES),
                           (start - timedelta(days=rng.randint(30, 900))).strftime("%Y-%m-%d"), "ACTIVE"))
            active[h[0]].append(r)
    with open(os.path.join(a.out, "riders.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["rider_id", "rider_name", "phone", "hub_id", "vehicle_type", "join_date", "status"])
        w.writerows(riders)

    # rider transfers = source data for SCD Type 2
    changes_by_day, change_rows = defaultdict(list), []
    for r in rng.sample(riders, max(1, int(len(riders) * 0.08))):
        day_i = rng.randint(int(a.days * 0.1), int(a.days * 0.9))
        new_hub = rng.choice([h for h in hub_ids if h != r[3]])
        change_rows.append((f"C{len(change_rows) + 1:05d}", r[0], r[3], new_hub,
                            (start + timedelta(days=day_i)).strftime("%Y-%m-%d")))
        changes_by_day[day_i].append((r[0], r[3], new_hub))
    with open(os.path.join(a.out, "rider_changes.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["change_id", "rider_id", "old_hub_id", "new_hub_id", "effective_date"])
        w.writerows(change_rows)

    n_cust = min(300000, max(5000, a.shipments // 6))
    customers = []
    for i in range(1, n_cust + 1):
        hub = rng.choices(HUBS, weights=hub_weights)[0]
        fn, ln = rng.choice(FIRST), rng.choice(LAST)
        customers.append((f"CU{i:07d}", f"{fn} {ln}", phone(rng),
                          f"{fn.lower()}.{ln.lower()}{i}@example.com",
                          f"{rng.randint(1, 250)}, Sample Street {rng.randint(1, 40)}",
                          hub[2], hub[3], PIN_PREFIX[hub[2]] + f"{rng.randint(0, 999):03d}", hub[4]))
    with open(os.path.join(a.out, "customers.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["customer_id", "full_name", "phone", "email", "address_line",
                    "city", "state", "pincode", "region"])
        w.writerows(customers)

    # ---------- daily volumes ----------
    weights = []
    for i in range(a.days):
        d = start + timedelta(days=i)
        weights.append(WEEKDAY_WEIGHT[d.weekday()] * (1.5 if i >= a.days - 30 else 1.0))
    tot = sum(weights)
    counts = [int(a.shipments * w / tot) for w in weights]
    for i in range(a.shipments - sum(counts)):
        counts[i % a.days] += 1

    ship_w = DailyWriter(os.path.join(a.out, "shipments"), "shipments", "csv",
                         ["shipment_id", "customer_id", "origin_hub_id", "dest_hub_id", "order_ts",
                          "promised_ts", "weight_kg", "package_type", "service_level",
                          "payment_mode", "cod_amount"])
    ev_w = DailyWriter(os.path.join(a.out, "events"), "events", "csv",
                       ["event_id", "shipment_id", "status", "event_ts", "hub_id", "rider_id", "ingested_ts"])
    cp_w = DailyWriter(os.path.join(a.out, "complaints"), "complaints", "jsonl")

    stats = {"shipments": 0, "delivered_by_cutoff": 0, "late_deliveries": 0, "failed_attempts": 0,
             "events_written": 0, "dup_events": 0, "late_arriving_events": 0,
             "missing_event_ts": 0, "impossible_event_ts": 0, "missing_hub_id": 0,
             "orphan_events": 0, "complaints": 0}
    hub_deliv, hub_late = defaultdict(int), defaultdict(int)
    ship_n = ev_n = cp_n = 0

    for day_i in range(a.days):
        day = start + timedelta(days=day_i)
        for rider, old, new in changes_by_day.get(day_i, []):
            if rider in active[old]:
                active[old].remove(rider)
                active[new].append(rider)
        for wtr in (ship_w, ev_w, cp_w):
            wtr.close_before(day)
        peak = day_i >= a.days - 30

        for _ in range(counts[day_i]):
            ship_n += 1
            sid = f"S{ship_n:09d}"
            cust = rng.choice(customers)
            d_hub = hub_by_city[cust[5]]
            o_hub = d_hub if rng.random() < 0.30 else rng.choices(hub_ids, weights=hub_weights)[0]
            service = rng.choices(["EXPRESS", "STANDARD", "ECONOMY"], weights=[0.2, 0.6, 0.2])[0]
            hour = rng.choices(range(24), weights=HOUR_WEIGHTS)[0]
            order_ts = day + timedelta(hours=hour, minutes=rng.randint(0, 59), seconds=rng.randint(0, 59))
            inter = o_hub != d_hub
            promised = order_ts + timedelta(hours=SLA_HOURS[service][1 if inter else 0])
            cod = rng.random() < 0.4
            ship_w.write(order_ts, [sid, cust[0], o_hub, d_hub, fmt(order_ts), fmt(promised),
                                    round(rng.uniform(0.1, 25), 2), rng.choice(PACKAGE_TYPES), service,
                                    "COD" if cod else "PREPAID", rng.randint(200, 8000) if cod else 0])

            # ---- true timeline ----
            ev = [("ORDER_PLACED", order_ts, o_hub, "")]
            t = order_ts + hrs(rng, 1, 6)
            ev.append(("PICKED_UP", t, o_hub, rng.choice(active[o_hub])))
            t += hrs(rng, 1, 5)
            if o_hub in BAD_HUBS and rng.random() < 0.20:
                t += hrs(rng, 6, 20)
            ev.append(("AT_ORIGIN_HUB", t, o_hub, ""))
            if inter:
                t += hrs(rng, 1, 8)
                ev.append(("IN_TRANSIT", t, o_hub, ""))
                t += timedelta(hours=rng.uniform(12, 40) * SPEED[service])
                if 6 <= t.month <= 9 and rng.random() < 0.12:
                    t += hrs(rng, 10, 30)          # monsoon delay
                ev.append(("AT_DEST_HUB", t, d_hub, ""))
            if d_hub in BAD_HUBS and rng.random() < 0.35:
                t += hrs(rng, 12, 36)              # planted: congested hubs
            if peak and rng.random() < 0.20:
                t += hrs(rng, 4, 16)               # sale-season surge
            t += hrs(rng, 2, 12)
            rider = rng.choice(active[d_hub])
            ev.append(("OUT_FOR_DELIVERY", t, d_hub, rider))
            t += hrs(rng, 1, 6)
            delivered = None
            if rng.random() < 0.08 + (0.07 if d_hub in BAD_HUBS else 0):
                stats["failed_attempts"] += 1
                ev.append(("FAILED_ATTEMPT", t, d_hub, rider))
                if rng.random() < 0.12:
                    t += hrs(rng, 12, 36)
                    ev.append(("RETURNED", t, o_hub, ""))
                else:
                    t += hrs(rng, 18, 30)
                    ev.append(("OUT_FOR_DELIVERY", t, d_hub, rider))
                    t += hrs(rng, 1, 6)
                    ev.append(("DELIVERED", t, d_hub, rider))
                    delivered = t
            else:
                ev.append(("DELIVERED", t, d_hub, rider))
                delivered = t

            stats["shipments"] += 1
            if delivered and delivered <= cutoff:
                stats["delivered_by_cutoff"] += 1
                hub_deliv[d_hub] += 1
                late_h = (delivered - promised).total_seconds() / 3600
                if late_h > 0:
                    stats["late_deliveries"] += 1
                    hub_late[d_hub] += 1
                if rng.random() < (0.35 if late_h > 24 else 0.03):
                    cat = "LATE_DELIVERY" if late_h > 24 else rng.choice(list(COMPLAINT_CATS)[1:])
                    created = delivered + hrs(rng, 1, 48)
                    if created <= cutoff:
                        cp_n += 1
                        cp_w.write(created, {"complaint_id": f"CP{cp_n:08d}", "shipment_id": sid,
                                             "customer_id": cust[0], "category": cat,
                                             "message": rng.choice(COMPLAINT_CATS[cat]),
                                             "created_ts": fmt(created)})
                        stats["complaints"] += 1

            # ---- emit events with planted defects ----
            for status, ts, hub, rdr in ev:
                if ts > cutoff:
                    continue
                ev_n += 1
                eid = f"E{ev_n:010d}"
                lag = rng.uniform(5, 1800)
                if rng.random() < 0.03:
                    lag = rng.uniform(86400, 7 * 86400)
                    stats["late_arriving_events"] += 1
                ingested = ts + timedelta(seconds=lag)
                if ingested > cutoff:
                    continue
                ts_out, hub_out = fmt(ts), hub
                if status != "ORDER_PLACED":
                    if rng.random() < 0.004:
                        ts_out = ""
                        stats["missing_event_ts"] += 1
                    elif rng.random() < 0.003:
                        ts_out = fmt(order_ts - hrs(rng, 1, 48))
                        stats["impossible_event_ts"] += 1
                if rng.random() < 0.005:
                    hub_out = ""
                    stats["missing_hub_id"] += 1
                row = [eid, sid, status, ts_out, hub_out, rdr, fmt(ingested)]
                ev_w.write(ingested, row)
                stats["events_written"] += 1
                if rng.random() < 0.02:                      # duplicate, arrives later
                    dup_ing = ingested + hrs(rng, 1, 48)
                    if dup_ing <= cutoff:
                        ev_w.write(dup_ing, row[:6] + [fmt(dup_ing)])
                        stats["dup_events"] += 1
                if rng.random() < 0.002:                     # orphan event
                    ev_n += 1
                    ev_w.write(ingested, [f"E{ev_n:010d}", f"SZ{rng.randint(0, 99999999):08d}",
                                          status, ts_out, hub_out, rdr, fmt(ingested)])
                    stats["orphan_events"] += 1

        if (day_i + 1) % 10 == 0:
            print(f"  day {day_i + 1}/{a.days}  shipments so far: {ship_n:,}")

    for wtr in (ship_w, ev_w, cp_w):
        wtr.close_all()

    names = {h[0]: h[1] for h in HUBS}
    key = {
        "note": "Answer key for validating your pipeline. Synthetic data.",
        "problem_hubs": {h: names[h] for h in sorted(BAD_HUBS)},
        "planted": {
            "problem_hubs": "35% of shipments gain 12-36h delay at the destination hub; failed-attempt rate +7 points",
            "monsoon": "12% of inter-city shipments in months 6-9 gain 10-30h delay",
            "sale_season": "final 30 days: volume x1.5, 20% of shipments gain 4-16h delay",
            "duplicates": "~2% of events repeated with the same event_id, arriving 1-48h later",
            "late_arrivals": "~3% of events ingested 1-7 days after they happened",
            "missing_event_ts": "~0.4% of non-order events",
            "impossible_event_ts": "~0.3% (before the order time)",
            "missing_hub_id": "~0.5% of events",
            "orphans": "~0.2% extra events for shipments that do not exist",
            "rider_transfers": "8% of riders move hubs once (see rider_changes.csv)",
        },
        "generator_counts": stats,
        "late_rate_by_destination_hub": {
            h: round(hub_late[h] / hub_deliv[h], 4) for h in hub_ids if hub_deliv[h]},
    }
    with open(os.path.join(a.out, "planted_patterns.json"), "w") as f:
        json.dump(key, f, indent=2)
    print("Done.", json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()
