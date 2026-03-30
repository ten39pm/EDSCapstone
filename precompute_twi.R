# ═══════════════════════════════════════════════════════════════════════════════
# precompute_twi.R
#
# Run this ONCE locally before deploying to shinyapps.io.
# It creates data/twi_precomputed.tif so the app doesn't need WhiteBox.
#
# Usage:
#   setwd("C:/EDSCAPSTONE2/HBEF_TOPMODEL_App")
#   source("precompute_twi.R")
# ═══════════════════════════════════════════════════════════════════════════════

library(terra)
library(sf)
library(whitebox)

wbt_init()

DEM_F <- "data/dem_10m.tif"
SHP_F <- "data/Watershed3HB.shp"
OUT_F <- "data/twi_precomputed.tif"

TEMP_DIR <- file.path(tempdir(), "twi_precompute")
dir.create(TEMP_DIR, showWarnings = FALSE, recursive = TRUE)

message("Loading DEM and watershed ...")
dem <- rast(DEM_F)
ws  <- st_read(SHP_F, quiet = TRUE)
ws_v <- vect(st_transform(ws, crs(dem)))
dem_ws <- mask(crop(dem, ws_v), ws_v)

dem_clip_f <- file.path(TEMP_DIR, "dem_clip.tif")
breached_f <- file.path(TEMP_DIR, "dem_breached.tif")
sca_f      <- file.path(TEMP_DIR, "sca.tif")
slope_f    <- file.path(TEMP_DIR, "slope.tif")

writeRaster(dem_ws, dem_clip_f, overwrite = TRUE)

message("Breaching depressions ...")
wbt_breach_depressions_least_cost(
  dem = dem_clip_f, output = breached_f, dist = 10, fill = TRUE
)

message("FD8 flow accumulation ...")
wbt_fd8_flow_accumulation(
  dem = breached_f, output = sca_f, out_type = "specific contributing area"
)

message("Computing slope ...")
wbt_slope(dem = breached_f, output = slope_f, units = "degrees")

message("Computing TWI ...")
sca <- rast(sca_f)
slp <- rast(slope_f)
slp_rad <- slp * pi / 180
tan_b <- tan(slp_rad)
tan_b[tan_b < 0.001] <- 0.001
twi <- log(sca / tan_b)
twi <- mask(twi, dem_ws)

writeRaster(twi, OUT_F, overwrite = TRUE)
message("Done! Saved to: ", OUT_F)
message("You can now deploy to shinyapps.io without WhiteBox.")
