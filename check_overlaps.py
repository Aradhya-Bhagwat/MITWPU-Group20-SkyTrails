
import json

def check_overlaps():
    with open("SkyTrails/SkyTrails/Identification/Model/bird_database.json", "r") as f:
        data = json.load(f)

    belly_variants = set()
    chest_variants = set()
    overlap_birds = []

    # Get variants
    for fm in data["reference_data"]["field_marks"]:
        if fm["area"] == "Belly":
            belly_variants = set(fm["variants"])
        elif fm["area"] == "Chest":
            chest_variants = set(fm["variants"])

    print(f"Belly Variants: {belly_variants}")
    print(f"Chest Variants: {chest_variants}")
    
    combined_variants = belly_variants.union(chest_variants)
    print(f"Combined Variants: {combined_variants}")

    # Check birds
    for bird in data["birds"]:
        areas = [fm["area"] for fm in bird["field_marks"]]
        if "Belly" in areas and "Chest" in areas:
            overlap_birds.append(bird["common_name"])
            print(f"Overlap: {bird['common_name']}")
            for fm in bird["field_marks"]:
                if fm["area"] in ["Belly", "Chest"]:
                    print(f"  - {fm['area']}: {fm['variant']}")

    if not overlap_birds:
        print("No birds have both Belly and Chest defined.")

if __name__ == "__main__":
    check_overlaps()
