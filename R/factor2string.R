#' Convert Factors to Strings
#'
#' `step_factor2string` will convert one or more factor
#'  vectors to strings.
#'
#' @inheritParams step_center
#' @inherit step_center return
#' @param ... One or more selector functions to choose which
#'  variables will be converted to strings. See [selections()]
#'  for more details.
#' @param role Not used by this step since no new variables are
#'  created.
#' @param columns A character string of variables that will be
#'  converted. This is `NULL` until computed by
#'  [prep.recipe()].
#' @return An updated version of `recipe` with the new step
#'  added to the sequence of existing steps (if any). For the
#'  `tidy` method, a tibble with columns `terms` (the
#'  columns that will be affected).
#' @keywords datagen
#' @concept preprocessing
#' @concept variable_encodings
#' @concept factors
#' @export
#' @details `prep` has an option `strings_as_factors` that
#'  defaults to `TRUE`. If this step is used with the default
#'  option, the string(s() produced by this step will be converted
#'  to factors after all of the steps have been prepped.
#' @seealso [step_string2factor()] [step_dummy()]
#' @examples
#' library(modeldata)
#' data(okc)
#'
#' rec <- recipe(~ diet + location, data = okc)
#'
#' rec <- rec %>%
#'   step_string2factor(diet)
#'
#' factor_test <- rec %>%
#'   prep(training = okc,
#'        strings_as_factors = FALSE) %>%
#'   juice
#' # diet is a
#' class(factor_test$diet)
#'
#' rec <- rec %>%
#'   step_factor2string(diet)
#'
#' string_test <- rec %>%
#'   prep(training = okc,
#'        strings_as_factors = FALSE) %>%
#'   juice
#' # diet is a
#' class(string_test$diet)
#'
#' tidy(rec, number = 1)
step_factor2string <-
  function(recipe,
           ...,
           role = NA,
           trained = FALSE,
           columns = FALSE,
           skip = FALSE,
           id = rand_id("factor2string")) {
    add_step(
      recipe,
      step_factor2string_new(
        terms = ellipse_check(...),
        role = role,
        trained = trained,
        columns = columns,
        skip = skip,
        id = id
      )
    )
  }

step_factor2string_new <-
  function(terms, role, trained, columns, skip, id) {
    step(
      subclass = "factor2string",
      terms = terms,
      role = role,
      trained = trained,
      columns = columns,
      skip = skip,
      id = id
    )
  }

#' @export
prep.step_factor2string <- function(x, training, info = NULL, ...) {
  col_names <- eval_select_recipes(x$terms, training, info)
  fac_check <-
    vapply(training[, col_names], is.factor, logical(1))
  if (any(!fac_check))
    rlang::abort(
      paste0(
      "The following variables are not factor vectors: ",
      paste0("`", names(fac_check)[!fac_check], "`", collapse = ", ")
      )
    )

  step_factor2string_new(
    terms = x$terms,
    role = x$role,
    trained = TRUE,
    columns = col_names,
    skip = x$skip,
    id = x$id
  )
}

#' @export
bake.step_factor2string <- function(object, new_data, ...) {
  new_data[, object$columns] <-
    map_df(new_data[, object$columns],
           as.character)

  if (!is_tibble(new_data))
    new_data <- as_tibble(new_data)
  new_data
}

print.step_factor2string <-
  function(x, width = max(20, options()$width - 30), ...) {
    cat("Character variables from ")
    printer(x$columns, x$terms, x$trained, width = width)
    invisible(x)
  }


#' @rdname tidy.recipe
#' @param x A `step_factor2string` object.
#' @export
tidy.step_factor2string <- function(x, ...) {
  res <- simple_terms(x, ...)
  res$id <- x$id
  res
}
