# NBA Player Development: Next-Season Shooting Efficiency

An R Markdown project that uses historical NBA player statistics to forecast **next-season points per field-goal attempt**.

**Project question:** Can historical player performance predict next-season shooting efficiency better than simply repeating the previous season?

The notebook is currently configured to forecast **Cason Wallace's 2026–27 efficiency**, using player-season data from **2009–10 through 2025–26**.

## Overview

The analysis builds consecutive player-season pairs, engineers shooting and usage features, and compares statistical and machine learning models against a simple no-change baseline. It then refits an elastic net model on the available historical sample to produce a selected player's forecast, an approximate uncertainty interval, and a chart.

The target measures points scored from field goals:

```text
Points per field-goal attempt = (2 × field goals made + three-pointers made)
                               / field-goal attempts
```

Free throws are excluded from the target, although free-throw percentage is included as a predictor.

## Modeling approach

### Data preparation

- Downloads regular-season player totals from [sportsdataverse-data](https://github.com/sportsdataverse/sportsdataverse-data/releases/tag/nba_stats_player_season_stats).
- Checks required columns, player-season uniqueness, and consistency of shooting totals.
- Matches each player's statistics to the immediately following season.
- Requires at least **200 current-season field-goal attempts** and an observed, finite next-season efficiency for the modeling sample.
- Replaces missing or nonfinite predictors with training-set medians and adds missing-value indicators.
- Removes features that have no variation in the training sample.

### Predictors

The model uses age, games played, field-goal attempts, current points per attempt, two-point percentage, three-point percentage, free-throw percentage, three-point attempt share, and per-game minutes, attempts, assists, rebounds, and turnovers.

### Models

| Model | Approach |
| --- | --- |
| Previous-season baseline | Predicts that next-season efficiency will equal the previous season's |
| Elastic net | Penalized linear regression, tuning ridge/lasso mixtures and penalty strengths |
| XGBoost | Gradient-boosted trees, comparing tree depths and boosting rounds |

Hyperparameters are ranked by validation **mean absolute error (MAE)**, with **root mean squared error (RMSE)** as a tie-breaker. Mean prediction bias is also reported.

### Time-based evaluation

Splits are defined by the season being predicted:

| Split | Outcome seasons |
| --- | --- |
| Training | Through 2022–23 |
| Validation | 2023–24 and 2024–25 |
| Final test | 2025–26 |

XGBoost is compared during validation. The final held-out evaluation and subsequent forecast use **elastic net**, with the previous-season baseline retained for comparison. Final-test predictions use the model trained on the original training split; the forecasting model is subsequently refitted on historical pairs with outcome years before 2027.

A paired bootstrap resamples final-test players **5,000 times** to estimate uncertainty in the elastic net versus baseline MAE difference.

## Results reported in the notebook

The notebook's written summary reports:

- Final-test MAE of **8.49 points per 100 attempts** for the previous-season baseline and **8.15** for elastic net.
- An elastic-net-minus-baseline MAE difference of **−0.34**, with a **95% paired bootstrap interval of −0.77 to +0.10** points per 100 attempts.

The estimated improvement is modest, and the interval includes zero.

For Cason Wallace, the written summary reports a 2026–27 forecast of approximately **1.04 points per field-goal attempt**, with an approximate historical-error interval of **0.81–1.29**. That range provides little basis to predict a clear improvement or decline.

These figures are recorded in the notebook's narrative. Rerun the analysis to regenerate results from the downloaded data; the written interpretations do not update automatically.

## Getting started

You will need R and an R Markdown environment such as RStudio. HTML rendering requires Pandoc, which is bundled with RStudio.

1. Clone or download this repository.
2. Open [PlayerDevelopment.Rmd](PlayerDevelopment.Rmd) in RStudio.
3. Install the required packages:

   ```r
   install.packages(c("rmarkdown", "knitr", "glmnet", "xgboost"))
   ```

4. Run the chunks in order or select **Knit** to create an HTML report.

Alternatively, run this from R with the repository as your working directory:

```r
rmarkdown::render("PlayerDevelopment.Rmd")
```

The first run requires internet access. Downloaded season CSVs are cached in `data/development_raw/`.

## Forecasting another player

Change the player settings near the top of the notebook:

```r
player_id <- 1641717L
player_name <- "Cason Wallace"

season_years <- 2010:2026
forecast_year <- 2027L
```

Player IDs must match the source dataset. The forecast uses the selected player's row from `forecast_year - 1` and requires at least 200 field-goal attempts in that season. The displayed forecast name comes from the source data.

Rerun the notebook after changing players and revise the player-specific written interpretations. To forecast a different season, also review the fixed latest-season inspection, time-split settings, and labels rather than changing only `forecast_year`.

## Generated outputs

Running the full notebook creates these files in `outputs/development/`:

| File | Contents |
| --- | --- |
| `player_<id>_forecast_<year>.csv` | Player forecast, predicted change, and approximate interval |
| `player_<id>_forecast_<year>.png` | Historical efficiency and forecast chart |
| `final_test_model_comparison.csv` | Baseline and elastic net test metrics |
| `final_test_mae_bootstrap.csv` | Paired bootstrap comparison |
| `efficiency_model_<year>.rds` | Fitted model, preprocessing information, settings, and residual limits |

The repository contains the source notebook and README; datasets and generated outputs are created locally when the analysis runs.

## Interpretation and limitations

This project forecasts one aspect of player development: field-goal scoring efficiency. It does not predict overall player value, playing time, availability, or the effects of a particular coaching intervention.

Historical training pairs require an observed next-season efficiency, so forecasts are conditional on next-season participation and field-goal attempts. There is no additional minimum next-season attempt threshold in the modeling sample.

The approximate forecast interval adds held-out residual quantiles to the refitted model's prediction and bounds the result between zero and three points per attempt. It summarizes historical prediction errors rather than guaranteeing 95% coverage for an individual player. Changes in role, injuries, team context, and future data coverage can affect forecast accuracy.

## Author

[Hunter Clark](https://github.com/Hclark36)
