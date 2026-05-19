import csv
import json
import time
import requests
from pathlib import Path

# -- Config ------------------------------------------------
TAXONOMY_CSV = "ebird_taxonomy.csv"
OUTPUT_FILE = "output/birds_raw.jsonl"
TEST_MODE = False
TEST_LIMIT = 10
TEST_EXTRA_COMMON_NAMES = [
    "Common Myna",
    "Black Drongo",
    "Asian Koel",
    "Black Kite",
]
DELAY = 1.0    # seconds between Wikipedia requests
MIN_EXTRACT_LENGTH = 80
# ---------------------------------------------------------

Path("output").mkdir(exist_ok=True)

HEADERS = {
    "User-Agent": "SkyTrailsBirdApp/1.0 (bird reference data pipeline; contact@skytrails.app)"
}

MANUAL_TITLE_ALIASES = {
    "dwacas1": ["Dwarf cassowary", "Bennett's cassowary"],
}


def wikipedia_extract(title: str) -> dict | None:
    """Fetch the extract text from Wikipedia for a given page title."""
    url = "https://en.wikipedia.org/w/api.php"
    params = {
        "action": "query",
        "titles": title,
        "prop": "extracts",
        "explaintext": True,       # plain text, no HTML
        "exsectionformat": "plain",
        "redirects": 1,
        "format": "json",
    }
    try:
        r = requests.get(url, params=params, timeout=10, headers=HEADERS)
        r.raise_for_status()
        pages = r.json()["query"]["pages"]
        page = next(iter(pages.values()))
        if "missing" in page:
            return None
        return {
            "title": page.get("title"),
            "extract": page.get("extract", ""),
        }
    except Exception as e:
        print(f"  ERROR fetching '{title}': {e}")
        return None


def wikipedia_search_title(query: str) -> str | None:
    """Search Wikipedia and return the best matching page title."""
    url = "https://en.wikipedia.org/w/api.php"
    params = {
        "action": "query",
        "list": "search",
        "srsearch": query,
        "srlimit": 1,
        "format": "json",
    }
    try:
        r = requests.get(url, params=params, timeout=10, headers=HEADERS)
        r.raise_for_status()
        results = r.json().get("query", {}).get("search", [])
        if not results:
            return None
        return results[0].get("title")
    except Exception as e:
        print(f"  ERROR searching '{query}': {e}")
        return None


def fetch_bird(species_code: str, scientific_name: str, common_name: str) -> dict:
    """Try scientific name first, fall back to common name."""

    candidates = [
        ("scientific_name", scientific_name),
        ("common_name", common_name),
        ("common_name_lowercase", common_name.lower()),
        ("common_name_sentence_case", common_name[:1].upper() + common_name[1:].lower()),
    ]
    candidates.extend(
        ("manual_alias", title) for title in MANUAL_TITLE_ALIASES.get(species_code, [])
    )

    seen_titles = set()
    attempts = []
    for source, title in candidates:
        if not title or title in seen_titles:
            continue
        seen_titles.add(title)

        result = wikipedia_extract(title)
        extract_length = len(result["extract"]) if result else 0
        attempts.append({
            "source": source,
            "title": title,
            "resolved_title": result["title"] if result else None,
            "extract_length": extract_length,
        })
        if result and len(result["extract"]) >= MIN_EXTRACT_LENGTH:
            return {
                "species_code": species_code,
                "scientific_name": scientific_name,
                "common_name": common_name,
                "wiki_title": result["title"],
                "wiki_text": result["extract"],
                "source": source,
                "status": "ok",
            }

        time.sleep(DELAY)

    for source, query in [
        ("scientific_name_search", scientific_name),
        ("common_name_search", common_name),
    ]:
        title = wikipedia_search_title(query)
        attempts.append({
            "source": source,
            "title": query,
            "resolved_title": title,
            "extract_length": 0,
        })
        if not title or title in seen_titles:
            continue
        seen_titles.add(title)

        time.sleep(DELAY)
        result = wikipedia_extract(title)
        extract_length = len(result["extract"]) if result else 0
        attempts.append({
            "source": f"{source}_extract",
            "title": title,
            "resolved_title": result["title"] if result else None,
            "extract_length": extract_length,
        })
        if result and len(result["extract"]) >= MIN_EXTRACT_LENGTH:
            return {
                "species_code": species_code,
                "scientific_name": scientific_name,
                "common_name": common_name,
                "wiki_title": result["title"],
                "wiki_text": result["extract"],
                "source": source,
                "status": "ok",
            }

        time.sleep(DELAY)

    # Both failed
    return {
        "species_code": species_code,
        "scientific_name": scientific_name,
        "common_name": common_name,
        "wiki_title": None,
        "wiki_text": "",
        "source": None,
        "status": "not_found",
        "attempts": attempts,
    }


def load_already_done() -> set:
    """Read output file and return species_codes with successful records."""
    done = set()
    if Path(OUTPUT_FILE).exists():
        with open(OUTPUT_FILE, "r") as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        record = json.loads(line)
                        if record.get("status") == "ok":
                            done.add(record["species_code"])
                    except Exception:
                        pass
    return done


def main():
    # Load taxonomy CSV
    with open(TAXONOMY_CSV, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    # Filter to species only (exclude subspecies, spuh, slash etc.)
    species_rows = [r for r in rows if r.get("CATEGORY", "").lower() == "species"]
    print(f"Total species in CSV: {len(species_rows)}")

    if TEST_MODE:
        base_rows = species_rows[:TEST_LIMIT]
        extra_names = {name.lower() for name in TEST_EXTRA_COMMON_NAMES}
        extra_rows = [
            row for row in species_rows
            if row["PRIMARY_COM_NAME"].lower() in extra_names
        ]

        species_by_code = {}
        for row in base_rows + extra_rows:
            species_by_code[row["SPECIES_CODE"]] = row

        found_extra_names = {
            row["PRIMARY_COM_NAME"].lower()
            for row in extra_rows
        }
        missing_extra_names = extra_names - found_extra_names
        species_rows = list(species_by_code.values())

        print(
            f"TEST MODE - processing first {TEST_LIMIT} birds "
            f"+ {len(extra_rows)} extra birds"
        )
        if missing_extra_names:
            missing = ", ".join(sorted(missing_extra_names))
            print(f"WARNING: could not find test extra birds in taxonomy: {missing}")

    # Resume support - skip already done
    done = load_already_done()
    print(f"Already processed: {len(done)} birds - skipping these")

    to_process = [r for r in species_rows if r["SPECIES_CODE"] not in done]
    print(f"Remaining to fetch: {len(to_process)}\n")

    # Fetch and write
    with open(OUTPUT_FILE, "a", encoding="utf-8") as out:
        for i, row in enumerate(to_process):
            species_code = row["SPECIES_CODE"]
            scientific_name = row["SCI_NAME"]
            common_name = row["PRIMARY_COM_NAME"]

            print(f"[{i+1}/{len(to_process)}] {common_name} ({scientific_name})")

            record = fetch_bird(species_code, scientific_name, common_name)
            print(f"  -> status: {record['status']}  source: {record['source']}")

            out.write(json.dumps(record) + "\n")
            out.flush()

            time.sleep(DELAY)

    print("\nDone. Output written to", OUTPUT_FILE)


if __name__ == "__main__":
    main()
