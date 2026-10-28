# Run from the repository directory with a fresh Rscript process.
source("analysis.R")
if ("--download" %in% commandArgs(trailingOnly = TRUE)) download_inputs()
d <- load_and_audit()
s <- summarize_thefts(d)
dir.create("outputs", showWarnings = FALSE)
for (i in 1:5) {
  ggplot2::ggsave(file.path("outputs", paste0("figure_", i, ".png")),
                 plot_story(d, s, i), width = 11, height = if (i == 4) 6.5 else 5,
                 dpi = 150, bg = "white")
}
save_validation(s$metrics)
cat(jsonlite::toJSON(s$metrics, pretty = TRUE, auto_unbox = TRUE, digits = NA), "\n")
