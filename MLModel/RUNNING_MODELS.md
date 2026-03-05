# How to Run BirdFlow Models: Step-by-Step

Generating a new BirdFlow model is a two-stage process. 

1. **Preprocessing (R)**: Downloads the weekly abundance maps from eBird and formats them into an HDF5 template.
2. **Model Fitting (Python)**: Uses a JAX/Haiku neural network architecture to compute the movement transition matrices and saves the final fitted model.

Below is a step-by-step example for creating a model for the **Amur Falcon** (`amufal1`).

---

## Prerequisites

1. **eBird API Key**: You must have an eBird API key tied to your eBird account. In R, run `ebirdst::set_ebirdst_access_key("YOUR_KEY")` once to store it.
2. **R Environment**: `BirdFlowR` and `ebirdst` packages installed.
3. **Python Environment**: `BirdFlowPy` dependencies installed (usually in a virtual environment `venv` with `jax`, `haiku`, `optax`, etc.).

---

## Step 1: Preprocess the Data in R

Open an R console or run an R script to build the template HDF5 file. This step calculates the geographical grid and masks out areas with zero abundance.

```r
library(BirdFlowR)

# Define target species code and output directory
species_code <- "amufal1"
out_dir <- "training_data"

# Create the preprocessed HDF5 template
# NOTE: 'gpu_ram = 12' is the default limit which attempts to pick an 
# optimal resolution that will fit in 12GB of GPU RAM.
bf <- preprocess_species(
  species = species_code,
  out_dir = out_dir,
  overwrite = TRUE
)

# You can check the resolution it chose (in km)
res_km <- round(res(bf)[1] / 1000)
year <- bf$metadata$ebird_version_year
cat("Preprocessed template saved at:", 
    sprintf("%s/%s_%s_%skm.hdf5", out_dir, species_code, year, res_km))
```

*Expected Output*: A file named something like `training_data/amufal1_2023_27km.hdf5` is generated. It lacks the transition matrices but contains all the geography.

---

## Step 2: Fit the Transition Matrices in Python

Now switch to the terminal. We will use the `update_hdf.py` script provided by `BirdFlowPy` to train the model.

Activate your Python environment first:
```bash
source venv/bin/activate
```

Run the training script, pointing it to the directory, the species code, and the specific resolution (e.g., `27` km) that R generated in Step 1.

```bash
# General syntax:
# python BirdFlowPy/update_hdf.py <root_dir> <species_code> <resolution> [hyperparameters...]

python BirdFlowPy/update_hdf.py training_data amufal1 27 \
  --obs_weight=1.0 \
  --dist_weight=0.01 \
  --ent_weight=0.0001 \
  --dist_pow=0.4 \
  --ebirdst_year=2023
```

### Hyperparameters explained:
* `--obs_weight`: Weight of the observation (abundance) map matching.
* `--dist_weight`: Penalty for traveling long distances. Higher values mean birds take shorter hops.
* `--ent_weight`: Entropy weight. Adds randomness/spread to the routes so birds don't strictly take a single narrow path.
* `--dist_pow`: Exponent applied to distances.

*(Note: If you run this on a Mac with Apple Silicon (M1/M2/M3) and get an XLA/Metal error, prefix the command with `JAX_PLATFORMS=cpu` to force standard CPU execution.)*

*Expected Output*: A new, fully trained model will be generated alongside your template: 
`training_data/amufal1_2023_27km_obs1.0_ent0.0001_dist0.01_pow0.4.hdf5`.

---

## Step 3: Use the Fitted Model in R

Once the python script completes, the new HDF5 file contains the fully trained Markov chain transition matrices. You can now use it in R to predict routes!

```r
library(BirdFlowR)

# Load the newly trained model
model_path <- "training_data/amufal1_2023_27km_obs1.0_ent0.0001_dist0.01_pow0.4.hdf5"
bf <- import_birdflow(model_path)

# Print basic statistics
print(bf)

# Generate 10 synthetic migration routes starting in week 40
routes <- route_migration(bf, n = 10, start = 40)

# Animate the routes (Requires gganimate)
animate_routes(routes, bf)
```

## Batch Processing
If you want to do this for many species at once without manual intervention, you can wrap Steps 1 and 2 inside an R `tryCatch` loop using the `system2("python", ...)` command. An example of this is located in the `process_birdflow.R` script in the root directory.