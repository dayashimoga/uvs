from pathlib import Path

def main():
    lcov_path = Path("apps/flutter_app/coverage/lcov.info")
    if not lcov_path.exists():
        print("lcov.info not found")
        return

    lines = lcov_path.read_text(encoding="utf-8").splitlines()
    curr_sf = None
    file_stats = {}
    for line in lines:
        if line.startswith("SF:"):
            curr_sf = line.split(":", 1)[1]
            file_stats[curr_sf] = {"lf": 0, "lh": 0}
        elif line.startswith("LF:"):
            file_stats[curr_sf]["lf"] = int(line.split(":")[1])
        elif line.startswith("LH:"):
            file_stats[curr_sf]["lh"] = int(line.split(":")[1])

    total_lf = sum(s["lf"] for s in file_stats.values())
    total_lh = sum(s["lh"] for s in file_stats.values())

    print(f"Total Lines: {total_lh}/{total_lf} ({total_lh/max(total_lf,1)*100:.2f}%)")
    print("-" * 65)
    for f, st in sorted(file_stats.items(), key=lambda x: x[1]["lh"] / max(x[1]["lf"], 1)):
        pct = st["lh"] / max(st["lf"], 1) * 100
        print(f"{f:50} {st['lh']:4}/{st['lf']:4} ({pct:5.1f}%)")

if __name__ == "__main__":
    main()
