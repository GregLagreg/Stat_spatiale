# File : my_fonctions.R

# Upload the necessary packages
library(dplyr)
library(tidyr)
library(leaflet)
library(sf)
library(gstat)
library(ggplot2)

#Function for statistics

summary_statistics <- function(dataset) {
  dataset %>%
    select(where(is.numeric)) %>%
    pivot_longer(cols = everything(), names_to = "Variable", values_to = "valeur") %>%
    group_by(Variable) %>%
    summarise(
      Minimum = min(valeur, na.rm = TRUE),
      Q1      = quantile(valeur, 0.25, na.rm = TRUE),
      Mediane = median(valeur, na.rm = TRUE),
      Moyenne = mean(valeur, na.rm = TRUE),
      Q3      = quantile(valeur, 0.75, na.rm = TRUE),
      Maximum = max(valeur, na.rm = TRUE)
    )
}




#Function which allows to create a new dataset with the value targeted
filter_target <- function(dataset, variable, target) {
  dataset |>
    filter(.data[[variable]] == target)
}


double_graphic <- function(dataset, var_y, var_x, titre) {
  
  ggplot(data = dataset, aes(x = .data[[var_x]], y = .data[[var_y]])) +

    geom_point(color = "#2c3e50", size = 2, alpha = 0.6) +
    geom_smooth(method = "lm", color = "#e74c3c", se = TRUE) +
    
    labs(
      title = titre,
      x = var_x,
      y = var_y
    ) +
    

    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", size = 14)
    )
}

map_observations <- function(dataset, var_lon, var_lat) {

  leaflet(data = dataset) |>
    # addTiles() adds the map (OpenStreetMap)
    addTiles() |>
    # addCircleMarkers adds a point for each observation
    addCircleMarkers(
      lng = dataset[[var_lon]],   
      lat = dataset[[var_lat]],   
      radius = 5,                 # size of points
      color = "#FF5733",          # Color
      stroke = FALSE,             # no border
      fillOpacity = 0.7,          # Opacity
      # bonus : interactive map
      popup = paste("Lon:", dataset[[var_lon]], "<br>Lat:", dataset[[var_lat]])
    )
}




#Function to create the variogramm of the output variable
variogramm <- function(dataset, var_x, var_y, var_output, code_epsg) {
  
  # 1. Spatial transformation (in meters using UTM)
  dataset_sf <- st_as_sf(dataset, coords = c(var_x, var_y), crs = code_epsg)
  
  # 2. Dynamic formula creation (e.g., "My_Output ~ 1")
  # "~ 1" means we are studying the raw variable, without external trend
  formule <- as.formula(paste(var_output, "~ 1"))
  
  # 3. Calculation of the experimental variogram
  # gstat automatically calculates distances and groups points into bins
  vario_exp <- variogram(formule, data = dataset_sf)
  
  # 4. Graph creation with ggplot2
  ggplot(vario_exp, aes(x = dist, y = gamma)) +
    geom_point(color = "#2c3e50", size = 3) +
    geom_line(color = "#3498db", linetype = "dashed", alpha = 0.6) +
    labs(
      title = "Variogramm",
      subtitle = paste("Evolution of the spatial variance for :", var_output),
      x = "Distance",
      y = "Semi-variance (Gamma)"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )
}




optimise_p_idw <- function(dataset, var_x, var_y, var_output, code_epsg) {
  
  # 1. Spatial conversion with dynamic variables
  dataset_sf <- st_as_sf(dataset, coords = c(var_x, var_y), crs = code_epsg)
  
  # 2. Dynamic formula creation (e.g., "niveau_eau ~ 1")
  formule <- as.formula(paste(var_output, "~ 1"))
  
  # 3. Parameter initialization
  p_values <- seq(0.5, 10.0, by = 0.25)
  # MODIFICATION : Changement du nom pour RMSE
  rmse_results <- numeric(length(p_values))
  
  # 4. Outer loop: Testing different power parameters
  for (i in seq_along(p_values)) {
    current_p <- p_values[i]
    squared_errors <- numeric(nrow(dataset_sf))
    
    # 5. Inner loop: Leave-One-Out Cross-Validation (LOOCV)
    for (j in 1:nrow(dataset_sf)) {
      train_data <- dataset_sf[-j, ]
      test_data  <- dataset_sf[j, ]
      
      idw_fit <- idw(
        formula = formule,
        locations = train_data,
        newdata = test_data,
        idp = current_p,
        debug.level = 0
      )
      
      # 6. Value extraction and error calculation
      predicted_val <- idw_fit$var1.pred
      
      # Using double brackets [[ ]] to extract 
      # the value of the test column via its text name
      actual_val <- test_data[[var_output]]
      
      squared_errors[j] <- (predicted_val - actual_val)^2
    }
    
    # MODIFICATION : Ajout de sqrt() pour calculer la Racine (Root)
    rmse_results[i] <- sqrt(mean(squared_errors))
  }
  
  # 7. Identification of the optimal value
  # On cherche bien la plus petite erreur (which.min)
  results_df <- data.frame(Power = p_values, RMSE = rmse_results)
  optimal_p <- results_df$Power[which.min(results_df$RMSE)]
  
  cat("\n The optimal parameter p", var_output, "is :", optimal_p, "\n")
  
  # 8. Display diagnostic plot (Noms des axes mis à jour)
  plot(results_df$Power, results_df$RMSE, type = "b", pch = 19, col = "blue",
       xlab = "Parameter p", 
       ylab = "RMSE",
       main = paste("Optimisation IDW :", var_output))
  abline(v = optimal_p, col = "red", lty = 2, lwd = 2)
  
}




grid_idw <- function(dataset, var_x, var_y, var_output, code_epsg, param_p, map) {
  
  # 1. Spatial conversion of your data
  dataset_sf <- st_as_sf(dataset, coords = c(var_x, var_y), crs = code_epsg)
  
  # 2. Creation of the raw grid (the large bounding box)
  grille_vierge <- st_make_grid(dataset_sf, n = c(100, 100), what = "centers")
  grille_sf <- st_sf(geometry = grille_vierge)
  
  # 3. THE SCISSOR CUT (Clipping)
  # First ensure the mask has the same EPSG code as your data
  map <- st_transform(map, crs = code_epsg)
  
  # Keep only the grid points that fall "inside" the mask
  grille_clippee <- st_intersection(grille_sf, map)
  
  # 4. IDW Calculation (Only on solid ground!)
  formule <- as.formula(paste(var_output, "~ 1"))
  idw_resultat <- idw(
    formula = formule,
    locations = dataset_sf,
    newdata = grille_clippee, # Using the clipped grid
    idp = param_p,
    debug.level = 0
  )
  
   bbox <- st_bbox(idw_resultat)
  
  # 5. Map creation with borders in the background
  ggplot() +
    # Background layer: The border polygon (drawn in light gray)
    geom_sf(data = map, fill = "gray95", color = "black") +
    
    # Interpolation layer: The predicted points
    geom_sf(data = idw_resultat, aes(color = var1.pred), size = 3, shape = 15) +
    
    # Data layer: Your actual observations
    geom_sf(data = dataset_sf, color = "black", shape = 21, fill = "white", size = 1.5) +
    
    coord_sf(
      xlim = c(bbox["xmin"], bbox["xmax"]),
      ylim = c(bbox["ymin"], bbox["ymax"]),
      expand = TRUE # TRUE ajoute une légère marge aérée autour des points
    ) +
    
    scale_color_viridis_c(name = paste(var_output), "Prediction\n") +
    labs(
      title = "Interpolation IDW",
      subtitle = "",
      x = "Longitude (UTM)",
      y = "Latitude (UTM)"
    ) +
    theme_minimal()
}




