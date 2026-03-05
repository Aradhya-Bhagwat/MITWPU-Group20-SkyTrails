# How to Find Available Species for BirdFlow Models

BirdFlow relies on the **eBird Status and Trends (S&T)** data products to learn bird movement. Therefore, a BirdFlow model can be generated for *any species that has a published eBird S&T abundance model*.

Here is how you can find the complete list of available species, check their migration status, and extract them for your own use.

## 1. Using the `ebirdst` R Package

The official way to check for available species is through the `ebirdst` R package, which is maintained by the Cornell Lab of Ornithology. 

When you load the package, it provides a built-in dataset called `ebirdst_runs`. This dataframe contains metadata for every species currently modeled by eBird.

### R Code: Extracting All Species
```r
library(ebirdst)

# ebirdst_runs is a built-in dataframe containing all modeled species
all_species <- ebirdst_runs

# View the first few rows and key columns
head(all_species[, c("species_code", "common_name", "scientific_name", "is_migrant")])
```

## 2. Filtering for Migratory Species

BirdFlow is primarily designed to model **migratory** birds. Resident birds (which do not migrate) are usually not modeled in BirdFlow since their distributions stay relatively static year-round.

You can easily filter the eBird list to only show migratory birds:

```r
library(ebirdst)
library(dplyr)

# Filter for species marked as migratory
migrants <- ebirdst_runs %>%
  filter(is_migrant == TRUE) %>%
  select(species_code, common_name, scientific_name)

# Save this list to a CSV file for your batch processing scripts
write.csv(migrants, "available_migrants_list.csv", row.names = FALSE)

cat("Found", nrow(migrants), "migratory species available for BirdFlow!\n")
```

## 3. Existing CSV Lists

For convenience, this repository already contains pre-generated lists:
* `available_ebird_species.csv` - The complete list of all species with S&T data.
* `available_migrants_list.csv` - The filtered list containing only migratory birds (over 1,000 species) suitable for BirdFlow modeling.

When picking a species to model, simply look up its **6-letter or 7-letter `species_code`** (e.g., `amufal1` for Amur Falcon) from these files. This code is required for the BirdFlow preprocessing pipeline.
