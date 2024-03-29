#' @title Lassoed boost function
#'
#' @description This function computes the lassoed boosting estimates in a
#'   linear regression. It is build on the glmnet package and the mboost
#'   package. We use the acronym FGP if a parameter is from the glmnet
#'   package.
#'
#' @param x An n by p matrix of variables with n observations and p variables,
#'   either a matrix type or a data frame.
#' @param y A n by 1 vector of dependent variable.
#' @param family FGP. A character string equal to "gaussian" and no other
#'   character string is accepted.
#' @param weights FGP. Weights for each observation. Defaults to a vector of
#'   ones.
#' @param alpha FGP. The elasticnet mixing parameter and \eqn{0 \le \alpha \le 1}.
#' @param nlambda FGP. The number of lambda values. Defaults to 100.
#' @param lambda.min.ratio FGP. Smallest value for \code{lambda} as a fraction
#'   the maximum value of \code{lambda}, \code{lambda.max}.
#' @param lambda FGP. A sequence of penalty parameter values. If the value is
#'   \code{NULL}, a sequnce of log-scaled values are generated, similar to those
#'   in the original \code{glmnet} package. A user can also supply a preferred
#'   \code{lambda} sequence. Defaults to \code{NULL} with 100 values.
#' @param standardize FGP. Logical value for whether to standardize \code{x} prior
#'   to model fitting. Defaults to \code{TRUE}.
#' @param intercept FGP. A logical value for whether to report the intercept in the
#'   \code{coef.lboost} function. Defaults to \code{TRUE}. The estimation always
#'   include an intercept.
#' @param thresh FGP. Convergence criterion for coordinate descent. Defaults to \code{1e-7}.
#' @param nu The learning rate in boosting and \eqn{0 < \nu < 1}. Defaults to 0.1.
#' @param bstop The initial boosting iteration number. This number should be large enough
#'   so that it is larger than the usual stopping criterion in boosting or a multiple of
#'   the stopping criterion. Examples include \code{1000}, \code{5000} or more. Choosing
#'   a very large number will increase the computation cost. This number should also
#'   be increased if one uses a smaller learning rate such as \code{0.01} or \code{0.001}.
#' @param nb The number of equally spaced boosting steps on the sequence from \code{1}
#'   to \code{bstop}. There are \code{nb} selected LS-boost estimates (vectors) for each
#'   active set of variables determined by lasso in the first stage.The product,
#'   \code{nlambda} \eqn{*} \code{nb}, is the number of columns of the coefficient matrix
#'   in the output of this function.
#' @param lf Lower factor. When multiplied by the AIC-based stopping creterion, the product
#'   determines the first of the \code{nb} selected LS-boost steps . Defaults to \code{0}.
#' @param uf Upper factor. When multiplied by the AIC-based stopping criterion, the product
#'   determins the last of the \code{nb} selected LS-boost steps. Defaults to \code{1}.
#'   \code{lf} and \code{uf}, when multiplied by the AIC-based stopping criterion, define
#'   an interval of boosting steps, on which we sample \code{nb} equally-spaced steps. Some
#'   examples of \code{lf} and \code{uf} include \eqn{(0,1), (0,2), (0.2, 1.5),} etc.
#'
#' @details This is the main function of the package and it returns the parameter estimates
#'  of lassoed boosting for a linear regression. This is a two-stage procedure. In the first
#'  stage, lasso returns \code{nlambda} subsets of variables, some of which may be the same
#'  and may include all variables. In the second step, least-squares boosting (LS-boost) is
#'  use to spawn coefficient solution path for each subset of variables. The function reports
#'  \code{nb} solution vectors for each subset of variables.
#'
#'  \code{nlambda}, \code{nu}, \code{nb} are all tuning parameters. In addition, \code{lf} and
#'  \code{uf} can also be changed.
#'
#'  The estimation always includes an intercept. When \code{intercept = FALSE}, the
#'  \code{coef.lboost} function will skip returning the intercept estimates and
#'  \code{predict.lbbost} function will exclude the intercept when computing predictions.
#'
#' @return \code{lboost} returns a S3 class "lboost" with the following components:
#'   \item{call}{the function call} \item{beta}{A matrix of coefficient estimates, the first
#'   row of which are the intercept estimates.} \item{x}{the \code{x} data} \item{y}{the \code{y}
#'   data} \item{intercept}{the logical value for \code{intercept}} \item{nlambda}{the value
#'   of \code{nlambda}} \item{stop.num}{a sequnce of AIC-based criteria for LS-boost on each
#'   subset of variables generated by lasso. These numbers will help determine if the choices
#'   of \code{bstop}, \code{lf}, and \code{uf} are approriate.}
#'
#' @export
#'
#' @usage lboost(x, y, family = "gaussian", weights = NULL, alpha = 1, nlambda = 100,
#'   lambda.min.ratio = ifelse(nobs < nvar, 0.01, 1e-04), lambda = NULL,
#'   standardize = TRUE, intercept = TRUE, thresh = 1e-07, nu = 0.1, bstop = 1000,
#'   nb = 50, lf = 0, uf = 1)
#'
#' @examples
#' \dontrun{
#' # An example of using the bodyfat data in R.
#'library(lboost)
#'data("bodyfat", package = "TH.data")
#'x = bodyfat[,!colnames(bodyfat) %in% c("DEXfat")]
#'y = bodyfat[,c("DEXfat")]
#'output = lboost(x,y,
#'                nlambda = 100,
#'                lf = 0,
#'                uf = 2,
#'                nu = 0.1,
#'                bstop = 100,
#'                nb = 5)
#' }
lboost <- function(x,
                   y,
                   family = "gaussian",
                   weights = NULL,
                   alpha  = 1,
                   nlambda = 100,
                   lambda.min.ratio = ifelse(nobs < nvar, 0.01, 1e-04),
                   lambda = NULL,
                   standardize = TRUE,
                   intercept = TRUE,
                   thresh = 1e-07,
                   nu = 0.1,
                   bstop = 1000,
                   nb = 50,
                   lf = 0,
                   uf = 1) {

  lboost.call = match.call()

  n = nobs = nrow(x)
  p = nvar = ncol(x)

  one = rep(1, n)
  mux = drop(one %*% as.matrix(x)) / n
  muy = mean(y)

  # Check column names
  if(is.null(colnames(x))) {
    var.names = NULL
  } else {
    var.names = colnames(x)
  }

  # Remove variable names.
  names(x) = NULL

  # Compute weights.
  if (is.null(weights)) {
    weights = rep(1,n)
  } else if (length(weights) != n) {
    stop("The length of weights need to be the same as the number of observations.")
  }

  # Compute the lambda sequence if it is NULL.
  y.dem = drop(scale(y, center = TRUE, scale = FALSE))
  x.std = scale(x, center = TRUE, scale = TRUE)
  lambda.max = max(abs(colSums(y.dem * x.std) / n))

  if (is.null(lambda)) {
    lambda = exp(seq(log(lambda.max), log(lambda.max * lambda.min.ratio),
                     length.out = nlambda))
  } else if (length(lambda) != nlambda) {
    stop("Length of the supplied lambda is not equal to nlambda.")
  }

  output.lasso = glmnet::glmnet(x = as.matrix(x),
                                y = as.numeric(y),
                                family = family,
                                weights = weights,
                                offset = NULL,
                                alpha  = alpha,
                                nlambda = nlambda,
                                lambda.min.ratio = lambda.min.ratio,
                                lambda = lambda,
                                standardize = standardize,
                                intercept = intercept,
                                thresh = thresh)

 beta.lasso = output.lasso$beta
 beta.pos   = apply(beta.lasso, 2, function(x) which(x != 0))
 beta.mat   = matrix(0, nrow = (p + 1), ncol = nlambda * nb)  # Matrix to store beta estimates.
 pos.old    = c()   # zero length
 stop.num   = rep(0, nlambda)

 # Start "nlambda" rounds of boosting.
 for (i in 1:nlambda) {
   pos     = beta.pos[[i]]
   len.pos = length(pos)
   len.pos.old = length(pos.old)
   if (len.pos == 0) {
     len.pos.old = len.pos
     next
   }
   if (len.pos > 0) {
     x.mat = as.matrix(x[,pos])

     # Skip LS-boost if we have the same set of regressors as before.
     if (len.pos == len.pos.old) {
       beta.mat[,((i-1)*nb + 1) :((i-1)*nb + nb)] = beta.mat[,((i-2)*nb + 1) :((i-2)*nb + nb)]
       stop.num[i] = stop.num[i-1]
       next
     }

     output.boost = mboost::glmboost(x.mat, y, control = mboost::boost_control(mstop = bstop, nu = nu))
     aic = AIC(output.boost, method = "corrected")
     boost.num = mboost::mstop(aic)
     stop.num[i] = boost.num

     # Extract "nb" iteration steps that are equally spaced on the interval [lf*boost.num, uf*boost.num].
     boost.seq = as.integer(seq(lf * boost.num, uf * boost.num, length = nb))
     if (min(boost.seq) == 0) {boost.seq = boost.seq + 1}

     for (j in 1:nb) {
       b.vec  = rep(0, length(pos))
       b.coef = coef(output.boost[boost.seq[j]])
       b.name = names(b.coef)
       bstpos = as.numeric(unlist(lapply(b.name,function(x){gsub("V","",x)})))
       a      = muy - mux[pos][bstpos] %*% b.coef
       b.vec[bstpos] = b.coef
       beta.mat[,((i-1)*nb+j)][1] = a              # Save the intercept.
       beta.mat[,((i-1)*nb+j)][pos + 1] = b.vec    # Save other estimates.
     }
   }
   pos.old = pos
 }

 # Add row names to the beta matrix.
 if (!is.null(var.names)) {
   rownames(beta.mat) = c("intercept", var.names)
 }

 out = list()
 out$beta = Matrix::Matrix(beta.mat, sparse = TRUE)
 out$call = lboost.call
 out$intercept = intercept
 out$x = x
 out$y = y
 out$nlambda = nlambda
 out$stop.num = stop.num
 class(out) = "lboost"
 return(out)
}

#' Coef function for lassoed boosting object.
#' @export coef.lboost
#' @export

coef.lboost = function(object) {

  beta.lboost = object$beta
 if (object$intercept) return(beta.lboost)
  else return(beta.lboost[-1,])

}

#' Predict function for lassoed boosting object.
#' @export predict.lboost
#' @export

predict.lboost = function(object, newx) {
  if (missing(newx)) newx = object$x
  if (object$intercept) newx = cbind(rep(1,nrow(newx)),newx)
  return(newx %*% coef.lboost(object))
}
