# Kia and Hyundai Vehicle Theft Early Warning Analysis

A reproducible R visual story about historical reported theft counts and reporting completeness. Author: Violetta Kalinicheva.

## Question and decision

What do consistently reported city-month counts show about the escalation of Kia and Hyundai thefts from 2019 through 2022? The work supports a municipal monitoring proposal. It is not a validated predictive alert system, a causal study of social media, or a current theft-risk assessment.

## Verified results

All eight R notebook code cells ran in a new R kernel on October 28, 2026, with no errors. [validation.json](validation.json) records actual metrics, source hashes, and package versions.

- Milwaukee's 48 monthly records show **207** Kia and Hyundai thefts in 2019, **5.93%** of all reported vehicle thefts, versus **6,971**, **66.53%**, in 2021.
- Of 13 cities in the multicity file, **nine** have all 48 monthly observations. Within that fixed panel, thefts rise from **2,315 in 2021 to 12,592 in 2022**, a **443.93% increase**. All nine increase. Chicago contributes **58.88%** of the combined increase.
- The wide VICE workbook becomes **3,150 location-months across 70 locations**. Sixty-nine lack both counts, one total is zero, and **42 source percentages are inconsistent with their displayed counts**, all in Los Angeles. Recalculated shares retain the reported counts and source percentage separately.
- Among **64** VICE locations with complete 2022 counts, 27 have Kia and Hyundai shares of at least 10%, and eleven exceed 20%.
- The separate all-vehicle agency extract contains **556** paired agency rows. Of those, 444 increase from 2019 to 2022; the median agency percentage change is **38.80%**. This is not a national aggregate or a brand-specific effect.

## Methods and cleaning

The code audits all four sources separately, verifies city-month and location-month keys, reconciles rounded percentages, parses dash placeholders as missing rather than zero, and uses count-based shares. It requires complete and identical reporting windows for city comparisons. Partially reported cities remain in the coverage table. Overlapping jurisdictions, sources, and different grains are never stacked or joined into a supposed national total. Every chart states the reporting population, period, and denominator.

## Data

The original four extracts were supplied for earlier work. USAFacts compiled underlying police and agency information in [Car thefts are rising](https://usafacts.org/articles/car-thefts/), published May 26, 2023. The VICE workbook is a separate collection. Source documentation and [NHTSA's official campaign announcement](https://www.nhtsa.gov/press-releases/hyundai-kia-campaign-prevent-vehicle-theft) were checked October 28, 2026. The acquisition inputs are:

- [KiaHyundaiMilwaukeeData.csv](https://content.bellevue.edu/cst/dsc/640/2024Update/Datasets/KiaHyundaiMilwaukeeData.csv), SHA-256 `290ddf0526eafb7f1a965f44fa4d532ca54a639374b8fa2c5697ced1339d26ed`.
- [kiaHyundaiThefts.csv](https://content.bellevue.edu/cst/dsc/640/2024Update/Datasets/kiaHyundaiThefts.csv), SHA-256 `c353f8e542427e49b34b763d9e0bab0f4813ae3b980f8f4eda38cd387284bdc6`.
- [carTheftsMap.csv](https://content.bellevue.edu/cst/dsc/640/2024Update/Datasets/carTheftsMap.csv), SHA-256 `ff9491969cab437c0b205f70cd18685d8e5cc820b5e7eefe1605fb903592a1f9`.
- [VICE publisher's XLSX export](https://docs.google.com/spreadsheets/d/1-6614t_Ata5k7oESrm-HAdF1uOe8aPGRaQECl44GYeE/export?format=xlsx), saved as `Motherboard VICE News Kia Hyundai Theft Data.xlsx`. The supplied workbook's SHA-256 is `ae1c634bc53e31de81f3bdbae9ed8e7e2cfc4ffa8f420732fcdc0758557c91d3`; Google exports can have different ZIP-container hashes, so the recorded fresh-download hash is retained separately in `validation.json`.

Direct retrieval confirmed the three CSV files with byte-identical hashes. The fresh VICE export's entire 47-by-211 Data sheet matched the supplied workbook. The complete four-source workflow was then rerun using these fresh downloads. The obsolete course XLSX URL returned HTML and is not used by the downloader. **No raw data are redistributed.**

## Reproduce

The language remains R, matching the original project. Tested with **R 4.5.2**, `readxl 1.4.5`, `jsonlite 2.0.0`, `digest 0.6.39`, `ggplot2 4.0.1`, and `IRkernel 1.3.2`. [renv.lock](renv.lock) pins these packages and their tested dependency versions.

From this folder in R:

```r
install.packages("renv")
renv::activate()
renv::restore(prompt = FALSE)
```

For a clean R-process analysis that downloads the four publicly available source files locally and exports figures:

```sh
Rscript run.R --download
```

Existing files are preserved. The download verifies the three CSV hashes and validates the Excel container before import. Alternatively, place the four files in `data/`, or set `PROJECT_DATA_DIR` to their directory:

```sh
PROJECT_DATA_DIR=/path/to/local/data Rscript run.R
```

For the notebook, install Jupyter, register the restored R kernel with `IRkernel::installspec(name="ir45", displayname="R 4.5.2")`, open [vehicle_theft_early_warning.ipynb](vehicle_theft_early_warning.ipynb), choose that kernel, and restart/run all cells. The release's new-kernel execution is recorded separately from package installation: restoring the renv environment on another operating system was not independently tested. Do not use a Python kernel for R cells.

## Files and limitations

[analysis.R](analysis.R) contains data audits, calculations, and five figures. The notebook contains the full story and embedded charts. `run.R` performs a separate clean R-process run and writes ignored local PNGs to `outputs/`.

Reported theft proportions do not measure per-vehicle risk. Registered vehicles, model-year mix, exposure, reporting practices, and agency boundaries are unavailable or inconsistent. Reporting agencies are not a national random sample; some jurisdictions overlap. Timing does not identify a social-media effect, and these pre-2023 data do not estimate the effectiveness of later security updates. A prospective early-warning system needs validated thresholds, exposure denominators, and independent evaluation before use. Check current official prevention guidance separately. Original code and writing use [MIT](LICENSE); third-party data retain their own terms.
