# Devoir géostatistique – Partie 1 : dépendance spatiale des données Wolfcamp


**Données** : 85 sites (`x`, `y`) avec la charge piézométrique `z` de l'aquifère Wolfcamp (Texas), jeu `wolfcamp` du paquet `geoR`.

## 1. Comment construire un bon (ou mauvais) prompt

Un prompt est bon quand l'agent n'a rien à deviner pour produire une analyse correcte et vérifiable.

| Élément | Mauvais prompt | Bon prompt |
|---|---|---|
| Contexte | aucun | cours de géostatistique, niveau attendu |
| Données | « the wolfcamp data » | 85 sites, colonnes `x`, `y`, `z`, comment les charger, unités |
| Hypothèses | non dites | H0 et H1 écrites, seuil α fixé |
| Méthode | laissée au choix de l'agent | outils imposés, réglages, pièges à gérer (la tendance) |
  | Critères de réussite | aucun | décision explicite, reproductibilité, vérifications croisées |
  | Format de sortie | libre | script commenté, figures légendées, interprétation courte, limites |
  
  Consignes utiles en plus : « ne pas inventer de résultats », « signaler toute ambiguïté », « exécuter le code et vérifier qu'il tourne ».

**Protocole de comparaison** : deux conversations vierges, même agent, mêmes données, un prompt dans chacune. Évaluer avec la même grille : exactitude, validité de la méthode, gestion de la non-stationnarité, reproductibilité, qualité de l'interprétation, absence d'invention.

## 2. Les deux prompts

### Mauvais prompt

> Is the wolfcamp data spatially dependent? Check it in R.

Pas de contexte, pas de méthode, pas de critère de décision, pas de format de réponse.

### Bon prompt

> I am a student in a spatial statistics course (geostatistics). I want to test whether the Wolfcamp aquifer data are spatially dependent.
>
> **Data:** 85 sites with coordinates `x`, `y` and piezometric head `z`. Load them with `data(wolfcamp, package="geoR")` (list with `$coords` and `$data`), or from `wolfcamp.csv` (columns x, y, z) if geoR is not installed.
>
> **Hypotheses:** H0: the values are exchangeable across sites (no spatial dependence). H1: nearby sites are more alike than distant sites. Use α = 0.05.
>
> **Method (R, packages gstat and sp only):**
> 1. Compute the empirical semivariogram (cutoff = half the maximum distance, 12 bins) and a Monte Carlo envelope under H0 by permuting the values (999 simulations, fixed seed). Add one global test statistic with a p-value.
> 2. Compute Moran's I by distance class (correlogram) and with a short-range neighbourhood fixed in advance, with permutation p-values. Correct for multiple classes (Bonferroni).
> 3. The data probably contain a large-scale trend (non-stationarity). Run all tests on the raw data and on the residuals of a first-order polynomial trend in the coordinates, and explain the difference.
> 4. Cross-check your Moran's I against `spdep`.
>
> **Output:** one commented, reproducible R script; figures with legends; a short interpretation (decision, what dependence is detected at which distances, limitations). Run the code and check it works. Do not invent results; tell me if anything is ambiguous.

## 3. Code R

Le script complet est en annexe (`test_dependance_spatiale.R`). Principe :

1. **Variogramme empirique** (`gstat::variogram`, coupure = moitié de la distance maximale, 12 classes) et **enveloppe de Monte Carlo à 95 %** obtenue en permutant les valeurs entre sites (999 simulations).
2. **Statistique globale** : T = (semi-variance moyenne des 3 premiers lags) / variance. T ≈ 1 sous indépendance, T ≪ 1 si dépendance positive. p-valeur par permutation.
3. **Moran's I par classe de distance** (corrélogramme) avec p-valeurs par permutation et seuil de Bonferroni α/6, plus un Moran « voisinage court » (distance ≤ cutoff/3) fixé à l'avance. Contrôle croisé de la statistique avec `spdep::moran`.
4. Tout est fait sur **z brut** et sur les **résidus d'une tendance d'ordre 1** (`lm(z ~ x + y)`, R² = 0,891).

Décision : on rejette H0 si le test du variogramme et le Moran à voisinage court ont tous deux p < 0,05.

## 4. Résultats

| | Réponse type au mauvais prompt | Bon prompt, z brut | Bon prompt, résidus de tendance |
|---|---|---|---|
| Test | Moran, 4 voisins, p-valeur analytique | variogramme + Moran par permutation | idem |
| Moran I (courte distance) | 0,84 | 0,80 | 0,21 |
| T (variogramme) | – | 0,064 | 0,556 |
| p-valeur | < 2,2e-16 | 0,001 | 0,001 |
| Classes significatives (Bonferroni) | – | (0,36] à (109,145] | (0,36] et (36,73] |
| Décision | « dépendant » | dépendance jusqu'à ~145 | dépendance résiduelle jusqu'à ~73 |

La « réponse type au mauvais prompt » (`mauvais_prompt_reponse_type.R`) est écrite à la main pour illustrer ; ce n'est pas la sortie réelle d'un agent. Pour le devoir, il faut produire les vraies réponses avec l'agent choisi.

## 5. Discussion

- **Les deux approches concluent à la dépendance, mais pas pour la même raison.** Sur les valeurs brutes la dépendance est massive parce que la charge piézométrique suit un fort gradient régional. La réponse naïve s'arrête là, sans voir que ce résultat est dominé par la tendance (non-stationnarité).
- **Le bon prompt va plus loin.** Après retrait de la tendance, il reste une dépendance à courte distance (jusqu'à ~73 unités) : T = 0,56 au lieu de 1 sous indépendance. C'est cohérent avec le poly, qui retient la tendance d'ordre 1 et un variogramme avec nugget d'environ 1600 pour un palier d'environ 4000.
- **Faiblesses de la réponse naïve** : k = 4 voisins choisi sans justification, p-valeur analytique qui suppose la normalité, une seule statistique, aucune vérification croisée, aucune limite énoncée.
- **Corrélations négatives à 73–182 sur les résidus** : elles sont en partie un artefact du retrait de la tendance. C'est pourquoi la décision repose sur le voisinage court plutôt que sur un Moran global en 1/d, qui mélange corrélations positives proches et négatives lointaines.
- **Limites** : la permutation suppose l'échangeabilité sous H0, ce qui est approché pour les résidus (la tendance est estimée) ; le seuil de voisinage court (≤ 73) est un choix fixé à l'avance ; avec 85 sites, la puissance est limitée aux grandes distances.

Figure : `fig_dependance.png` (variogrammes avec enveloppe et corrélogrammes, brut et résidus).

## Annexe A – `test_dependance_spatiale.R`

```r
###############################################################################
# Wolfcamp : la charge piézométrique est-elle spatialement dépendante ?
# Version "bon prompt" : H0/H1 explicites, tests de permutation, gestion de la
# tendance (non-stationnarité), contrôles croisés, décision à alpha = 0.05.
#
# H0 : les valeurs z(s_i) sont échangeables entre sites (indépendance spatiale)
# H1 : des sites proches ont des valeurs plus semblables que des sites éloignés
###############################################################################
suppressPackageStartupMessages({ library(gstat); library(sp) })
set.seed(123)
nsim <- 999; alpha <- 0.05

## ---- 1. Données ------------------------------------------------------------
if (requireNamespace("geoR", quietly = TRUE)) {
  data(wolfcamp, package = "geoR")
  df <- data.frame(x = wolfcamp$coords[, 1], y = wolfcamp$coords[, 2], z = wolfcamp$data)
} else df <- read.csv("wolfcamp.csv")
n <- nrow(df); stopifnot(n == 85, !anyNA(df))
cat("n =", n, "| z : min", round(min(df$z)), "max", round(max(df$z)), "\n")

D <- as.matrix(dist(df[, c("x", "y")]))
dmax <- max(D); cutoff <- dmax / 2          # on ne regarde que la moitié de l'étendue
nb <- 12; width <- cutoff / nb

## ---- 2. Deux variables à tester -------------------------------------------
# (a) z brut  : contient une forte tendance grande échelle (cf. poly)
# (b) résidus d'une tendance polynomiale d'ordre 1 : dépendance "résiduelle"
fit1 <- lm(z ~ x + y, data = df)
cat(sprintf("Tendance ordre 1 : R2 = %.3f\n", summary(fit1)$r.squared))
vars <- list(brut = df$z, residus_ordre1 = residuals(fit1))

## ---- 3. Variogramme empirique + enveloppe de permutation -------------------
emp_vario <- function(v) {
  d <- data.frame(df[, c("x", "y")], v = v)
  variogram(v ~ 1, locations = ~x + y, data = d, cutoff = cutoff, width = width)
}
# statistique globale : semi-variance moyenne des 3 premiers lags / variance
#   ~ 1 sous indépendance ; << 1 si dépendance positive
T_stat <- function(v) { g <- emp_vario(v); mean(g$gamma[1:3]) / var(v) }

mc_vario <- function(v) {
  g0 <- emp_vario(v)
  sims <- replicate(nsim, emp_vario(sample(v))$gamma)         # matrice nbins x nsim
  env <- t(apply(sims, 1, quantile, c(alpha / 2, 1 - alpha / 2)))
  Tobs <- mean(g0$gamma[1:3]) / var(v)
  Tsim <- apply(sims[1:3, ], 2, mean) / var(v)
  list(g = g0, env = env, Tobs = Tobs, p = (1 + sum(Tsim <= Tobs)) / (nsim + 1))
}
res_vario <- lapply(vars, mc_vario)

## ---- 4. Moran's I par classe de distance (corrélogramme) -------------------
moran_band <- function(v, lo, hi) {
  W <- (D > lo & D <= hi) * 1
  zc <- v - mean(v); S0 <- sum(W)
  stat <- function(zc) (length(zc) / S0) * as.numeric(t(zc) %*% W %*% zc) / sum(zc^2)
  I0 <- stat(zc); Isim <- replicate(nsim, stat(sample(zc)))
  c(I = I0, E = -1 / (length(v) - 1), p = (1 + sum(Isim >= I0)) / (nsim + 1),
    lo95 = unname(quantile(Isim, alpha / 2)), hi95 = unname(quantile(Isim, 1 - alpha / 2)))
}
brk <- seq(0, cutoff, length.out = 7)
res_moran <- lapply(vars, function(v)
  data.frame(band = sprintf("(%.0f,%.0f]", brk[-7], brk[-1]),
             t(sapply(1:6, function(k) moran_band(v, brk[k], brk[k + 1])))))

# Moran "global" : voisinage court FIXE a priori (distance <= cutoff/3).
# (Un Moran en 1/d mélangerait corrélations positives proches et négatives lointaines,
#  ces dernières étant en partie un artefact du retrait de la tendance.)
res_glob <- lapply(vars, function(v) moran_band(v, 0, cutoff / 3)[c("I", "p")])

# contrôle croisé : spdep::moran() calcule la même statistique (mêmes poids binaires)
if (requireNamespace("spdep", quietly = TRUE)) {
  nbs <- spdep::dnearneigh(as.matrix(df[, c("x", "y")]), 0, brk[2])
  lw  <- spdep::nb2listw(nbs, style = "B", zero.policy = TRUE)
  Ichk <- spdep::moran(vars$brut, lw, n, spdep::Szero(lw), zero.policy = TRUE)$I
  stopifnot(abs(Ichk - res_moran$brut$I[1]) < 1e-8)
  cat(sprintf("Contrôle spdep::moran (1re classe, brut) : %.4f = mon code %.4f\n", Ichk, res_moran$brut$I[1]))
}

## ---- 5. Figures -------------------------------------------------------------
png("fig_dependance.png", 1500, 900, res = 130)
par(mfrow = c(2, 2), mar = c(4, 4.2, 3, 1))
for (nm in names(vars)) {
  r <- res_vario[[nm]]
  plot(r$g$dist, r$g$gamma, type = "n", ylim = range(r$g$gamma, r$env), xlab = "distance",
       ylab = "semi-variance", main = paste("Variogramme -", nm))
  polygon(c(r$g$dist, rev(r$g$dist)), c(r$env[, 1], rev(r$env[, 2])), col = "grey85", border = NA)
  abline(h = var(vars[[nm]]), lty = 3)
  points(r$g$dist, r$g$gamma, pch = 16); lines(r$g$dist, r$g$gamma)
  legend("bottomright", bty = "n", cex = .8,
         legend = c("enveloppe 95% (permutations)", sprintf("p(MC) = %.3f", r$p)))
}
for (nm in names(vars)) {
  m <- res_moran[[nm]]
  plot(seq_len(6), m$I, type = "b", pch = 16, ylim = range(m$I, m$lo95, m$hi95), xaxt = "n",
       xlab = "classe de distance", ylab = "Moran's I", main = paste("Correlogramme -", nm))
  axis(1, 1:6, m$band, cex.axis = .7)
  polygon(c(1:6, 6:1), c(m$lo95, rev(m$hi95)), col = "grey85", border = NA)
  lines(1:6, m$I, type = "b", pch = 16); abline(h = m$E[1], lty = 3)
  points(which(m$p < alpha / 6), m$I[m$p < alpha / 6], pch = 21, bg = "red", cex = 1.4)
}
dev.off()

## ---- 6. Résultats et décision ----------------------------------------------
cat("\n================ RESULTATS ================\n")
for (nm in names(vars)) {
  cat("\n---", nm, "---\n")
  cat(sprintf("Variogramme : T = gamma(3 premiers lags)/var = %.3f (1 = indépendance) ; p(MC) = %.4f\n",
              res_vario[[nm]]$Tobs, res_vario[[nm]]$p))
  cat(sprintf("Moran voisinage court (d <= %.0f) : I = %.4f ; p(MC) = %.4f\n", cutoff / 3, res_glob[[nm]]["I"], res_glob[[nm]]["p"]))
  cat(sprintf("Corrélogramme : classes significatives après Bonferroni (p < %.4f) : %s\n", alpha / 6,
              paste(res_moran[[nm]]$band[res_moran[[nm]]$p < alpha / 6], collapse = " ") ))
  print(transform(res_moran[[nm]], I = round(I, 3), E = round(E, 3), p = round(p, 4),
                  lo95 = round(lo95, 3), hi95 = round(hi95, 3)), row.names = FALSE)
  cat("Décision (alpha = 0.05) :",
      if (res_vario[[nm]]$p < alpha && res_glob[[nm]]["p"] < alpha) "REJET de H0 -> dépendance spatiale\n"
      else "H0 non rejetée\n")
}
cat("\nLimites : permutation = échangeabilité sous H0 ; pour les résidus, elle est approchée",
    "\n(la tendance est estimée) ; 85 sites -> puissance limitée aux grandes distances.\n")
```

## Annexe B – `mauvais_prompt_reponse_type.R` (illustratif)

```r
# Réponse TYPIQUE à un mauvais prompt ("Is the wolfcamp data spatially dependent? Check it in R.")
# Une seule statistique, réglages arbitraires, p-valeur asymptotique, aucune vérification.
library(spdep)
df  <- read.csv("wolfcamp.csv")
nb  <- knn2nb(knearneigh(as.matrix(df[, c("x", "y")]), k = 4))   # k = 4 : choisi sans justification
lw  <- nb2listw(nb)
print(moran.test(df$z, lw))   # p-valeur analytique (hypothèse de normalité), données brutes
# -> "p < 0.05 : les données sont spatialement dépendantes." (fin de l'analyse)
```

