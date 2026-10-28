# Kia and Hyundai theft monitoring with separate reporting populations.
project_root <- normalizePath(getwd())
data_dir <- Sys.getenv("PROJECT_DATA_DIR", unset = file.path(project_root, "data"))
required_packages <- c("readxl", "jsonlite", "digest", "ggplot2")
for (p in required_packages) {
  if (!requireNamespace(p, quietly = TRUE)) stop(paste("Install the required package:", p))
}

download_inputs <- function() {
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  files <- c("KiaHyundaiMilwaukeeData.csv", "kiaHyundaiThefts.csv", "carTheftsMap.csv",
             "Motherboard VICE News Kia Hyundai Theft Data.xlsx")
  urls <- c(paste0("https://content.bellevue.edu/cst/dsc/640/2024Update/Datasets/", files[1:3]),
    "https://docs.google.com/spreadsheets/d/1-6614t_Ata5k7oESrm-HAdF1uOe8aPGRaQECl44GYeE/export?format=xlsx")
  expected <- c("290ddf0526eafb7f1a965f44fa4d532ca54a639374b8fa2c5697ced1339d26ed",
    "c353f8e542427e49b34b763d9e0bab0f4813ae3b980f8f4eda38cd387284bdc6",
    "ff9491969cab437c0b205f70cd18685d8e5cc820b5e7eefe1605fb903592a1f9")
  options(timeout = 120)
  for (i in seq_along(files)) {
    destination <- file.path(data_dir, files[i])
    if (file.exists(destination)) { cat("Preserving existing", files[i], "\n"); next }
    temporary <- tempfile(fileext = if (i == 4) ".xlsx" else ".csv")
    download.file(urls[i], temporary, mode = "wb", quiet = TRUE)
    if (i < 4) stopifnot(digest::digest(temporary, algo = "sha256", file = TRUE) == expected[i])
    if (i == 4) stopifnot(identical(readBin(temporary, what = "raw", n = 2), as.raw(c(80,75))))
    stopifnot(file.copy(temporary, destination, overwrite = FALSE))
    unlink(temporary)
    cat("Downloaded", files[i], "\n")
  }
}

parse_counts <- function(x) {
  text <- trimws(as.character(x))
  text[text %in% c("", "-", "NA", "N/A", "NaN")] <- NA_character_
  parsed <- suppressWarnings(as.numeric(gsub(",", "", text, fixed = TRUE)))
  stopifnot(!any(!is.na(text) & is.na(parsed)))
  parsed
}

load_and_audit <- function() {
  files <- c("KiaHyundaiMilwaukeeData.csv", "kiaHyundaiThefts.csv", "carTheftsMap.csv",
             "Motherboard VICE News Kia Hyundai Theft Data.xlsx")
  stopifnot(all(file.exists(file.path(data_dir, files))))
  milwaukee_raw <- read.csv(file.path(data_dir, files[1]), check.names = FALSE)
  cities_raw <- read.csv(file.path(data_dir, files[2]), check.names = FALSE)
  map_raw <- read.csv(file.path(data_dir, files[3]), check.names = FALSE, na.strings = c("", "NA", "-"))
  vice_raw <- suppressMessages(readxl::read_excel(file.path(data_dir, files[4]), sheet = "Data", col_names = FALSE))
  stopifnot(ncol(vice_raw) == 211, !anyDuplicated(milwaukee_raw), !anyDuplicated(cities_raw))
  prepare_monthly <- function(raw) {
    clean <- raw
    clean$date <- as.Date(sprintf("%04d-%02d-01", clean$year, match(clean$month, month.abb)))
    stopifnot(!anyNA(clean$date), !anyDuplicated(clean[c("city", "state", "date")]))
    stopifnot(all(clean$countKiaHyundaiThefts >= 0), all(clean$countOtherThefts >= 0))
    clean$total <- clean$countKiaHyundaiThefts + clean$countOtherThefts
    clean$share <- ifelse(clean$total > 0, clean$countKiaHyundaiThefts / clean$total, NA_real_)
    # I recalculate shares from counts and retain the source's rounded percentages.
    stopifnot(max(abs(clean$share - clean$percentKiaHyundai), na.rm = TRUE) <= 0.00050001)
    clean[order(clean$city, clean$date), ]
  }
  milwaukee <- prepare_monthly(milwaukee_raw)
  cities <- prepare_monthly(cities_raw)
  # I reshape the 70 workbook location groups without treating blank counts as zeros.
  vice <- do.call(rbind, lapply(seq(2, 211, 3), function(j) {
    rows <- 3:nrow(vice_raw)
    data.frame(date = as.Date(vice_raw[[1]][rows]),
      location = as.character(vice_raw[[j]][1]),
      kia_hyundai = parse_counts(vice_raw[[j]][rows]),
      total = parse_counts(vice_raw[[j + 1]][rows]),
      source_share = parse_counts(vice_raw[[j + 2]][rows]), stringsAsFactors = FALSE)
  }))
  stopifnot(nrow(vice) == 3150, length(unique(vice$location)) == 70,
            !anyNA(vice$date), !anyDuplicated(vice[c("location", "date")]))
  stopifnot(all(vice$kia_hyundai >= 0, na.rm = TRUE), all(vice$total >= 0, na.rm = TRUE))
  stopifnot(all(vice$kia_hyundai <= vice$total, na.rm = TRUE))
  vice$year <- as.integer(format(vice$date, "%Y"))
  vice$share <- ifelse(!is.na(vice$kia_hyundai) & !is.na(vice$total) & vice$total > 0,
                       vice$kia_hyundai / vice$total, NA_real_)
  vice$mismatch <- !is.na(vice$source_share) & !is.na(vice$share) & abs(vice$source_share - vice$share) > 1e-7
  # This agency file measures all vehicle thefts, not brand-specific thefts.
  agency <- map_raw
  for (col in paste0("countCarThefts", 2019:2022)) agency[[col]] <- parse_counts(agency[[col]])
  stopifnot(!anyDuplicated(agency), all(agency$countCarThefts2019 >= 0, na.rm = TRUE),
            all(agency$countCarThefts2022 >= 0, na.rm = TRUE))
  agency$change_pct <- ifelse(agency$countCarThefts2019 > 0 & !is.na(agency$countCarThefts2022),
                        100 * (agency$countCarThefts2022 / agency$countCarThefts2019 - 1), NA_real_)
  hashes <- setNames(lapply(file.path(data_dir, files), digest::digest, algo = "sha256", file = TRUE), files)
  audit <- list(source_sha256 = hashes,
    milwaukee_rows = nrow(milwaukee_raw), multicity_rows = nrow(cities_raw),
    multicity_cities = length(unique(cities_raw$city)), agency_rows = nrow(map_raw),
    vice_workbook_rows = nrow(vice_raw), vice_workbook_columns = ncol(vice_raw),
    vice_long_rows = nrow(vice), vice_locations = length(unique(vice$location)),
    vice_missing_both_counts = sum(is.na(vice$kia_hyundai) & is.na(vice$total)),
    vice_zero_totals = sum(vice$total == 0, na.rm = TRUE),
    vice_percentage_mismatches = sum(vice$mismatch),
    vice_percentage_mismatch_locations = as.list(table(vice$location[vice$mismatch])),
    agency_missing_2019 = sum(is.na(agency$countCarThefts2019)),
    agency_missing_2022 = sum(is.na(agency$countCarThefts2022)),
    monthly_exact_duplicates = 0, vice_location_month_duplicates = 0)
  list(milwaukee = milwaukee, cities = cities, vice = vice, agency = agency, audit = audit)
}

annual_totals <- function(d) {
  out <- aggregate(cbind(countKiaHyundaiThefts, countOtherThefts) ~ year, d, sum)
  out$total <- out$countKiaHyundaiThefts + out$countOtherThefts
  out$share_pct <- 100 * out$countKiaHyundaiThefts / out$total
  out
}

summarize_thefts <- function(d) {
  coverage <- aggregate(date ~ city + year, d$cities, function(x) length(unique(x)))
  names(coverage)[3] <- "months"
  complete <- tapply(coverage$months == 12, coverage$city, function(x) length(x) == 4 && all(x))
  complete_cities <- names(complete)[complete]
  cities <- d$cities[d$cities$city %in% complete_cities, ]
  stopifnot(nrow(cities) == length(complete_cities) * 48)
  milwaukee_annual <- annual_totals(d$milwaukee)
  multicity_annual <- annual_totals(cities)
  by_city <- aggregate(countKiaHyundaiThefts ~ city + year, cities, sum)
  changes <- merge(by_city[by_city$year == 2021, c("city", "countKiaHyundaiThefts")],
                   by_city[by_city$year == 2022, c("city", "countKiaHyundaiThefts")], by = "city", suffixes = c("_2021", "_2022"))
  changes$increase <- changes$countKiaHyundaiThefts_2022 - changes$countKiaHyundaiThefts_2021
  stopifnot(sum(changes$increase) == diff(multicity_annual$countKiaHyundaiThefts[multicity_annual$year %in% c(2021, 2022)]))
  v <- d$vice[d$vice$year == 2022 & !is.na(d$vice$kia_hyundai) & !is.na(d$vice$total), ]
  vcoverage <- table(v$location)
  v <- v[v$location %in% names(vcoverage)[vcoverage == 12], ]
  vice_annual <- aggregate(cbind(kia_hyundai, total) ~ location, v, sum)
  vice_annual$share_pct <- 100 * vice_annual$kia_hyundai / vice_annual$total
  vice_annual <- vice_annual[order(-vice_annual$share_pct), ]
  a <- d$agency[!is.na(d$agency$change_pct), ]
  start <- multicity_annual$countKiaHyundaiThefts[multicity_annual$year == 2021]
  finish <- multicity_annual$countKiaHyundaiThefts[multicity_annual$year == 2022]
  metrics <- c(d$audit, list(
    complete_cities = unname(complete_cities), complete_cities_n = length(complete_cities),
    complete_city_months = nrow(cities),
    milwaukee_2019_thefts = milwaukee_annual$countKiaHyundaiThefts[milwaukee_annual$year == 2019],
    milwaukee_2019_share_pct = milwaukee_annual$share_pct[milwaukee_annual$year == 2019],
    milwaukee_2021_thefts = milwaukee_annual$countKiaHyundaiThefts[milwaukee_annual$year == 2021],
    milwaukee_2021_share_pct = milwaukee_annual$share_pct[milwaukee_annual$year == 2021],
    complete_cities_2021_thefts = start, complete_cities_2022_thefts = finish,
    complete_cities_growth_pct = 100 * (finish / start - 1),
    cities_with_increase = sum(changes$increase > 0),
    chicago_contribution_pct = 100 * changes$increase[changes$city == "Chicago"] / sum(changes$increase),
    vice_complete_2022_locations = nrow(vice_annual), vice_locations_at_least_10pct = sum(vice_annual$share_pct >= 10),
    vice_locations_above_20pct = sum(vice_annual$share_pct > 20),
    agency_paired_positive_baseline_n = nrow(a), agency_increases_n = sum(a$change_pct > 0),
    agency_median_change_pct = median(a$change_pct)))
  list(coverage = coverage, cities = cities, milwaukee_annual = milwaukee_annual,
       multicity_annual = multicity_annual, changes = changes, vice_annual = vice_annual,
       agency = a, metrics = metrics)
}

plot_story <- function(d, s, panel) {
  library(ggplot2)
  theme_set(theme_minimal(base_size = 12) + theme(panel.grid.minor = element_blank(),
            plot.title = element_text(face = "bold"), plot.caption = element_text(hjust = 0)))
  if (panel == 1) {
    q <- ggplot(d$milwaukee, aes(date, countKiaHyundaiThefts)) +
      geom_line(color = "#ba4d25", linewidth = 1) + geom_point(color = "#ba4d25", size = 1.5) +
      labs(title = "Milwaukee's brand-specific thefts escalated in 2021",
           subtitle = "Monthly reported Kia and Hyundai vehicle thefts, 2019–2022",
           x = NULL, y = "Reported thefts", caption = "Source: supplied USAFacts / police department extract. Counts are not per-vehicle risk.") +
      expand_limits(y = 0)
  } else if (panel == 2) {
    q <- ggplot(s$multicity_annual, aes(factor(year), countKiaHyundaiThefts)) +
      geom_col(fill = "#ba4d25", width = .65) +
      geom_text(aes(label = format(countKiaHyundaiThefts, big.mark = ",", trim = TRUE)), vjust = -.5) +
      scale_y_continuous(expand = expansion(mult = c(0, .15))) +
      labs(title = "Nine consistently reporting cities show a 2022 surge",
           subtitle = "Same nine cities, all 12 months of each year; Milwaukee is separate",
           x = "Year", y = "Reported Kia and Hyundai thefts",
           caption = "Source: supplied USAFacts extract. The sample is not a national estimate.")
  } else if (panel == 3) {
    q <- ggplot(s$changes, aes(increase, reorder(city, increase))) +
      geom_col(fill = "#176b87") + geom_text(aes(label = increase), hjust = -.15, size = 3.5) +
      scale_x_continuous(expand = expansion(mult = c(0, .18))) +
      labs(title = "Chicago accounts for most of the nine-city increase",
           subtitle = "2022 minus 2021, identical complete city reporting windows",
           x = "Additional reported Kia and Hyundai thefts", y = NULL,
           caption = "Source: supplied USAFacts extract. No registered-vehicle exposure denominator is available.")
  } else if (panel == 4) {
    top <- head(s$vice_annual, 12)
    q <- ggplot(top, aes(share_pct, reorder(location, share_pct))) +
      geom_col(fill = "#ba4d25") + geom_text(aes(label = sprintf("%.1f%%", share_pct)), hjust = -.15, size = 3.5) +
      scale_x_continuous(limits = c(0, 85), expand = expansion(mult = c(0, .02))) +
      labs(title = "The broader workbook also shows concentrated brand shares",
           subtitle = paste("Highest 12 of", nrow(s$vice_annual), "locations with complete 2022 counts"),
           x = "Kia and Hyundai share of all reported vehicle thefts (%)", y = NULL,
           caption = "Source: VICE workbook, shares recalculated from counts. Overlapping jurisdictions are not summed.")
  } else {
    q <- ggplot(s$agency, aes(change_pct)) + geom_histogram(bins = 35, fill = "#176b87", color = "white") +
      geom_vline(xintercept = 0, linetype = "dashed") +
      labs(title = "All-vehicle theft changes vary among reporting agencies",
           subtitle = paste(nrow(s$agency), "agencies with positive 2019 counts and observed 2022 counts"),
           x = "Change in all vehicle thefts, 2019–2022 (%)", y = "Reporting agency rows",
           caption = "Source: supplied agency extract. Not brand-specific; overlapping areas and reporting changes limit inference.")
  }
  q
}

save_validation <- function(metrics) {
  # I stop on a source revision that would invalidate the release's fixed prose.
  expected <- list(milwaukee_rows = 48, multicity_rows = 552, agency_rows = 556,
    vice_long_rows = 3150, vice_percentage_mismatches = 42,
    milwaukee_2019_thefts = 207, milwaukee_2021_thefts = 6971,
    complete_cities_n = 9, complete_cities_2021_thefts = 2315,
    complete_cities_2022_thefts = 12592, vice_complete_2022_locations = 64)
  for (key in names(expected)) {
    if (!isTRUE(all.equal(as.numeric(metrics[[key]]), as.numeric(expected[[key]]))))
      stop(paste("Source revision changed", key, "- review the narrative before release."))
  }
  package_versions <- setNames(lapply(required_packages, function(p) as.character(packageVersion(p))), required_packages)
  result <- list(status = "analysis_executed", validated_on = "2026-10-28", R = R.version.string,
    packages = package_versions, sources_retrieved_on = "2026-10-28",
    sources = c("https://usafacts.org/articles/car-thefts/",
      "https://www.nhtsa.gov/press-releases/hyundai-kia-campaign-prevent-vehicle-theft",
      "https://docs.google.com/spreadsheets/d/1-6614t_Ata5k7oESrm-HAdF1uOe8aPGRaQECl44GYeE/edit"),
    metrics = metrics)
  jsonlite::write_json(result, "validation.json", pretty = TRUE, auto_unbox = TRUE, na = "null", digits = NA)
}
