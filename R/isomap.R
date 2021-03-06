#' Isomap Embedding
#'
#' `step_isomap` creates a *specification* of a recipe
#'  step that will convert numeric data into one or more new
#'  dimensions.
#'
#' @inheritParams step_center
#' @inherit step_center return
#' @param ... One or more selector functions to choose which
#'  variables will be used to compute the dimensions. See
#'  [selections()] for more details.
#' @param role For model terms created by this step, what analysis
#'  role should they be assigned?. By default, the function assumes
#'  that the new dimension columns created by the original variables
#'  will be used as predictors in a model.
#' @param num_terms The number of isomap dimensions to retain as new
#'  predictors. If `num_terms` is greater than the number of columns
#'  or the number of possible dimensions, a smaller value will be
#'  used.
#' @param neighbors The number of neighbors.
#' @param options A list of options to [dimRed::Isomap()].
#' @param res The [dimRed::Isomap()] object is stored
#'  here once this preprocessing step has be trained by
#'  [prep.recipe()].
#' @param prefix A character string that will be the prefix to the
#'  resulting new variables. See notes below.
#' @param keep_original_cols A logical to keep the original variables in the
#'  output. Defaults to `FALSE`.
#' @return An updated version of `recipe` with the new step
#'  added to the sequence of existing steps (if any).
#' @keywords datagen
#' @concept preprocessing
#' @concept isomap
#' @concept projection_methods
#' @export
#' @details Isomap is a form of multidimensional scaling (MDS).
#'  MDS methods try to find a reduced set of dimensions such that
#'  the geometric distances between the original data points are
#'  preserved. This version of MDS uses nearest neighbors in the
#'  data as a method for increasing the fidelity of the new
#'  dimensions to the original data values.
#'
#' This step requires the \pkg{dimRed}, \pkg{RSpectra},
#'  \pkg{igraph}, and \pkg{RANN} packages. If not installed, the
#'  step will stop with a note about installing these packages.
#'
#'
#' It is advisable to center and scale the variables prior to
#'  running Isomap (`step_center` and `step_scale` can be
#'  used for this purpose).
#'
#' The argument `num_terms` controls the number of components that
#'  will be retained (the original variables that are used to derive
#'  the components are removed from the data). The new components
#'  will have names that begin with `prefix` and a sequence of
#'  numbers. The variable names are padded with zeros. For example,
#'  if `num_terms < 10`, their names will be `Isomap1` -
#'  `Isomap9`. If `num_terms = 101`, the names would be
#'  `Isomap001` - `Isomap101`.
#'
#' When you [`tidy()`] this step, a tibble with column `terms` (the
#'  selectors or variables selected) is returned.
#'
#' @references De Silva, V., and Tenenbaum, J. B. (2003). Global
#'  versus local methods in nonlinear dimensionality reduction.
#'  *Advances in Neural Information Processing Systems*.
#'  721-728.
#'
#' \pkg{dimRed}, a framework for dimensionality reduction,
#'   https://github.com/gdkrmr
#'
#' @examples
#' \donttest{
#' library(modeldata)
#' data(biomass)
#'
#' biomass_tr <- biomass[biomass$dataset == "Training",]
#' biomass_te <- biomass[biomass$dataset == "Testing",]
#'
#' rec <- recipe(HHV ~ carbon + hydrogen + oxygen + nitrogen + sulfur,
#'               data = biomass_tr)
#'
#' im_trans <- rec %>%
#'   step_YeoJohnson(all_numeric_predictors()) %>%
#'   step_normalize(all_numeric_predictors()) %>%
#'   step_isomap(all_numeric_predictors(), neighbors = 100, num_terms = 2)
#'
#' if (require(dimRed) & require(RSpectra)) {
#'   im_estimates <- prep(im_trans, training = biomass_tr)
#'
#'   im_te <- bake(im_estimates, biomass_te)
#'
#'   rng <- extendrange(c(im_te$Isomap1, im_te$Isomap2))
#'   plot(im_te$Isomap1, im_te$Isomap2,
#'        xlim = rng, ylim = rng)
#'
#'   tidy(im_trans, number = 3)
#'   tidy(im_estimates, number = 3)
#' }
#' }
#' @seealso [step_pca()] [step_kpca()]
#'   [step_ica()] [recipe()] [prep.recipe()]
#'   [bake.recipe()]

step_isomap <-
  function(recipe,
           ...,
           role = "predictor",
           trained = FALSE,
           num_terms  = 5,
           neighbors = 50,
           options = list(.mute = c("message", "output")),
           res = NULL,
           prefix = "Isomap",
           keep_original_cols = FALSE,
           skip = FALSE,
           id = rand_id("isomap")) {

    recipes_pkg_check(required_pkgs.step_isomap())

    add_step(
      recipe,
      step_isomap_new(
        terms = ellipse_check(...),
        role = role,
        trained = trained,
        num_terms = num_terms,
        neighbors = neighbors,
        options = options,
        res = res,
        prefix = prefix,
        keep_original_cols = keep_original_cols,
        skip = skip,
        id = id
      )
    )
  }

step_isomap_new <-
  function(terms, role, trained, num_terms, neighbors, options, res,
           prefix, keep_original_cols, skip, id) {
    step(
      subclass = "isomap",
      terms = terms,
      role = role,
      trained = trained,
      num_terms = num_terms,
      neighbors = neighbors,
      options = options,
      res = res,
      prefix = prefix,
      keep_original_cols = keep_original_cols,
      skip = skip,
      id = id
    )
  }

#' @export
prep.step_isomap <- function(x, training, info = NULL, ...) {
  col_names <- eval_select_recipes(x$terms, training, info)

  check_type(training[, col_names])

  if (x$num_terms > 0) {
    x$num_terms <- min(x$num_terms, ncol(training))
    x$neighbors <- min(x$neighbors, nrow(training))

    iso_map <-
      try(
        dimRed::embed(
          dimRed::dimRedData(as.data.frame(training[, col_names, drop = FALSE])),
          "Isomap",
          knn = x$neighbors,
          ndim = x$num_terms,
          .mute = x$options$.mute
        ),
        silent = TRUE)
    if (inherits(iso_map, "try-error")) {
      rlang::abort(paste0("`step_isomap` failed with error:\n", as.character(iso_map)))
    }

  } else {
    iso_map <- list(x_vars = col_names)
  }

  step_isomap_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    num_terms = x$num_terms,
    neighbors = x$neighbors,
    options = x$options,
    res = iso_map,
    prefix = x$prefix,
    keep_original_cols = get_keep_original_cols(x),
    skip = x$skip,
    id = x$id
  )
}

#' @export
bake.step_isomap <- function(object, new_data, ...) {
  if (object$num_terms > 0) {
    isomap_vars <- colnames(environment(object$res@apply)$indata)
    comps <-
      object$res@apply(
        dimRed::dimRedData(as.data.frame(new_data[, isomap_vars, drop = FALSE]))
      )@data
    comps <- comps[, 1:object$num_terms, drop = FALSE]
    comps <- check_name(comps, new_data, object)
    new_data <- bind_cols(new_data, as_tibble(comps))
    keep_original_cols <- get_keep_original_cols(object)
    if (!keep_original_cols) {
      new_data <- new_data[, !(colnames(new_data) %in% isomap_vars), drop = FALSE]
    }
    if (!is_tibble(new_data))
      new_data <- as_tibble(new_data)
  }
  new_data
}


print.step_isomap <- function(x, width = max(20, options()$width - 35), ...) {
  if (x$num_terms == 0) {
    cat("Isomap was not conducted.\n")
  } else {
    cat("Isomap approximation with ")
    printer(colnames(x$res@org.data), x$terms, x$trained, width = width)
  }
    invisible(x)
  }


#' @rdname tidy.recipe
#' @param x A `step_isomap` object
#' @export
tidy.step_isomap <- function(x, ...) {
  if (is_trained(x)) {
    if (x$num_terms > 0) {
      res <- tibble(terms = colnames(x$res@org.data))
    } else {
      res <- tibble(terms = x$res$x_vars)
    }
  } else {
    term_names <- sel2char(x$terms)
    res <- tibble(terms = term_names)
  }
  res$id <- x$id
  res
}



#' @rdname tunable.step
#' @export
tunable.step_isomap <- function(x, ...) {
  tibble::tibble(
    name = c("num_terms", "neighbors"),
    call_info = list(
      list(pkg = "dials", fun = "num_terms", range = c(1L, 4L)),
      list(pkg = "dials", fun = "neighbors", range = c(20L, 80L))
    ),
    source = "recipe",
    component = "step_isomap",
    component_id = x$id
  )
}

#' @rdname required_pkgs.step
#' @export
required_pkgs.step_isomap <- function(x, ...) {
  c("dimRed", "RSpectra", "igraph", "RANN")
}

