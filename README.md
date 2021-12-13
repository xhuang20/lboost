
<!-- README.md is generated from README.Rmd. Please edit that file -->
# lboost: An R package for lassoed boosting in linear regression

<!-- badges: start -->
<!-- badges: end -->
This package implements lassoed boosting in Huang (2021) for linear regression. The method uses the lasso in the first stage to screen variables and the least-squares boosting (LS-boost) in the second stage to build coefficient paths on each subset of variables selected by the lasso. We use the R package [*glmnet*](https://cran.r-project.org/web/packages/glmnet/index.html) for the lasso part and the R package [*mboost*](https://cran.r-project.org/web/packages/mboost/index.html) for the LS-boost part.

## Installation

You can install **lboost** from [GitHub](https://github.com/xhuang20/lboost.git) with:

``` r
devtools::install_github("xhuang20/lboost")
```

## Example

We give an example in the following.

``` r
library(lboost)
# Use the body fat dataset as an example.
data("bodyfat", package = "TH.data")
x = bodyfat[,!colnames(bodyfat) %in% c("DEXfat")]
y = bodyfat[,c("DEXfat")]

out = lboost(x,y,
             intercept = TRUE,
             nlambda = 100,      # number of lasso penalty parameters
             lf = 0,             # lower factor
             uf = 2,             # upper factor
             nu = 0.1,           # the learning rate
             bstop = 100,        # the initial boosting iteration number
             nb = 5)             # the number of selected boosting solutions
```

There will be a warning message from the *mboost* package about no intercept estimate. The interecept is calculated separately.

To reproduce the simulation results in Huang (2021), we can add the following line to the simulation code of the *bestsubset* package that can be found [here](https://github.com/ryantibs/best-subset/tree/master/sims).

``` r
# Use the random seed 0 in the original simulation program.
reg.funs[["lboost"]] = function(x,y) lboost(x, y, 
                                            nlambda = 50,       # This number can also be 100 in other settings.
                                            intercept = FALSE,
                                            nu = 0.01,
                                            bstop = 20000,
                                            nb = 50,
                                            lf = 0,
                                            uf = 2)
```

One of the values the *lboost* function returns is a *beta* matrix that can be used for validation and test purposes. The *beta* matrix always includes an estimate for the intercept. The output of the *coef.lboost* and *predict.lboost* functions depends on the *intercept* parameter in the *lboost* function.
