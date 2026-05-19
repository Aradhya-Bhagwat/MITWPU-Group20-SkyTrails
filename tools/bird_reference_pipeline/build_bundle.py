import gzip
import json
from pathlib import Path

# -- Config ------------------------------------------------
INPUT_FILE = "output/birds_reference_short.jsonl"
OUTPUT_JSON = "output/bird_reference_info.json"
OUTPUT_GZIP = "output/bird_reference_info.json.gz"
# ---------------------------------------------------------


def load_latest_successful_records() -> list[dict]:
    latest = {}
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            if record.get("status") != "ok":
                continue
            latest[record["species_code"]] = record

    records = list(latest.values())
    records.sort(key=lambda item: item["species_code"])
    return records


def compact_record(record: dict) -> dict:
    return {
        "species_code": record.get("species_code"),
        "common_name": record.get("common_name"),
        "scientific_name": record.get("scientific_name"),
        "wiki_title": record.get("wiki_title"),
        "source_url": record.get("source_url"),
        "field_marks": record.get("field_marks"),
        "size": record.get("size"),
        "weight": record.get("weight"),
        "habitat": record.get("habitat"),
        "behavior": record.get("behavior"),
        "similar_species": record.get("similar_species"),
        "family": record.get("family"),
        "order": record.get("order"),
        "genus": record.get("genus"),
        "notes": record.get("notes"),
    }


def main():
    Path("output").mkdir(exist_ok=True)

    records = [compact_record(record) for record in load_latest_successful_records()]
    payload = {
        "version": 1,
        "record_count": len(records),
        "records": records,
    }

    raw_json = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")

    with open(OUTPUT_JSON, "wb") as f:
        f.write(raw_json)

    with gzip.open(OUTPUT_GZIP, "wb", compresslevel=9) as f:
        f.write(raw_json)

    raw_size = Path(OUTPUT_JSON).stat().st_size
    gzip_size = Path(OUTPUT_GZIP).stat().st_size
    ratio = gzip_size / raw_size if raw_size else 0

    print(f"Records: {len(records)}")
    print(f"JSON: {OUTPUT_JSON} ({raw_size:,} bytes)")
    print(f"Gzip: {OUTPUT_GZIP} ({gzip_size:,} bytes)")
    print(f"Compressed ratio: {ratio:.2%}")


if __name__ == "__main__":
    main()
