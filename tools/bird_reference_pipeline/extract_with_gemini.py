import json
import os
import time
from pathlib import Path

import requests

# -- Config ------------------------------------------------
INPUT_FILE = "output/birds_raw.jsonl"
OUTPUT_FILE = "output/birds_reference_short.jsonl"
MODEL = "gemini-2.5-flash-lite"
DELAY = 3.0
MAX_WIKI_CHARS = 12000
# ---------------------------------------------------------

API_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"


def require_api_key() -> str:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise SystemExit(
            "Missing GEMINI_API_KEY. Set it only in your local terminal:\n"
            'export GEMINI_API_KEY="your_key_here"'
        )
    return api_key


def load_latest_successful_raw_records() -> list[dict]:
    latest = {}
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            if record.get("status") == "ok":
                latest[record["species_code"]] = record
    return list(latest.values())


def load_already_done() -> set[str]:
    done = set()
    if Path(OUTPUT_FILE).exists():
        with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    record = json.loads(line)
                    if record.get("status") == "ok":
                        done.add(record["species_code"])
                except Exception:
                    pass
    return done


def build_prompt(record: dict) -> str:
    wiki_text = record.get("wiki_text", "")[:MAX_WIKI_CHARS]
    return f"""
You are extracting ultra-compact bird reference data for an offline birding app.

Return only valid minified JSON. Do not wrap it in Markdown.

Required JSON shape:
{{
  "field_marks": "2-4 bullet lines, or null",
  "size": "short phrase, or null",
  "weight": "short phrase, or null",
  "habitat": "1-2 bullet lines, or null",
  "behavior": "1-2 bullet lines, or null",
  "similar_species": "1-2 bullet lines, or null",
  "family": "biological family if present or inferable, or null",
  "order": "biological order if present or inferable, or null",
  "genus": "genus from scientific name",
  "notes": "1 short bullet line, or null"
}}

Rules:
- Use only the provided Wikipedia text and names.
- Do not invent measurements, similar species, family, or order if absent.
- Use plain ASCII hyphen bullets inside string values, like "- Glossy black body".
- Each bullet must be 12 words or fewer.
- field_marks must focus on visible ID marks only.
- habitat, behavior, similar_species, and notes must be short field-guide style pointers.
- Prefer null over weak filler.
- Avoid citations, links, and markdown.
- Total text across all non-taxonomy fields should stay under 90 words.

Bird:
species_code: {record["species_code"]}
common_name: {record["common_name"]}
scientific_name: {record["scientific_name"]}
wiki_title: {record.get("wiki_title")}

Wikipedia text:
{wiki_text}
""".strip()


def parse_json_response(text: str) -> dict:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = cleaned.removeprefix("```json").removeprefix("```").strip()
        cleaned = cleaned.removesuffix("```").strip()
    return json.loads(cleaned)


def safe_error_message(error: Exception) -> str:
    if isinstance(error, requests.HTTPError) and error.response is not None:
        message = f"HTTP {error.response.status_code}"
        try:
            error_json = error.response.json()
            api_message = error_json.get("error", {}).get("message")
            if api_message:
                message += f": {api_message}"
        except Exception:
            pass
        return message
    return error.__class__.__name__


def is_quota_error(error: Exception) -> bool:
    return (
        isinstance(error, requests.HTTPError)
        and error.response is not None
        and error.response.status_code == 429
    )


def is_auth_error(error: Exception) -> bool:
    if not isinstance(error, requests.HTTPError) or error.response is None:
        return False
    if error.response.status_code in {401, 403}:
        return True
    if error.response.status_code == 400:
        try:
            message = error.response.json().get("error", {}).get("message", "")
        except Exception:
            message = ""
        return "api key" in message.lower()
    return False


def extract_with_gemini(api_key: str, record: dict) -> dict:
    prompt = build_prompt(record)
    payload = {
        "contents": [
            {
                "parts": [
                    {"text": prompt}
                ]
            }
        ],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json",
        },
    }
    response = requests.post(
        API_URL,
        params={"key": api_key},
        json=payload,
        timeout=60,
    )
    response.raise_for_status()
    data = response.json()
    text = data["candidates"][0]["content"]["parts"][0]["text"]
    extracted = parse_json_response(text)

    return {
        "species_code": record["species_code"],
        "common_name": record["common_name"],
        "scientific_name": record["scientific_name"],
        "wiki_title": record.get("wiki_title"),
        "source_url": f"https://en.wikipedia.org/wiki/{record.get('wiki_title', '').replace(' ', '_')}",
        "status": "ok",
        **extracted,
    }


def main():
    api_key = require_api_key()
    Path("output").mkdir(exist_ok=True)

    raw_records = load_latest_successful_raw_records()
    done = load_already_done()
    to_process = [r for r in raw_records if r["species_code"] not in done]

    print(f"Raw successful records: {len(raw_records)}")
    print(f"Already extracted: {len(done)}")
    print(f"Remaining to extract: {len(to_process)}\n")

    with open(OUTPUT_FILE, "a", encoding="utf-8") as out:
        for i, record in enumerate(to_process, 1):
            species_code = record["species_code"]
            common_name = record["common_name"]
            print(f"[{i}/{len(to_process)}] {common_name} ({species_code})")

            try:
                extracted = extract_with_gemini(api_key, record)
                out.write(json.dumps(extracted, ensure_ascii=False) + "\n")
                out.flush()
                print("  -> ok")
            except Exception as e:
                error_message = safe_error_message(e)
                if is_quota_error(e):
                    print(f"  -> quota limit hit: {error_message}")
                    print("Stopping now. Wait for quota reset or use a billing-enabled project, then rerun.")
                    break
                if is_auth_error(e):
                    print(f"  -> auth/key error: {error_message}")
                    print("Stopping now. Check GEMINI_API_KEY, then rerun.")
                    break

                failed = {
                    "species_code": species_code,
                    "common_name": common_name,
                    "scientific_name": record["scientific_name"],
                    "status": "error",
                    "error": error_message,
                }
                out.write(json.dumps(failed, ensure_ascii=False) + "\n")
                out.flush()
                print(f"  -> error: {error_message}")

            time.sleep(DELAY)

    print("\nDone. Output written to", OUTPUT_FILE)


if __name__ == "__main__":
    main()
