#' Plot the bootstrapped signature contributions
#'
#' Plot the signature contributions retrieved with 'fit_to_signatures_bootstrapped'.
#' The function can plot both the absolute or the relative signature contribution.
#' The graph can be plotted as either a jitter plot or as a boxplot.
#'
#' @param contri_boots  matrix showing  signature contributions across bootstrap iterations.
#' @param mode Either "absolute" for absolute number of mutations, or
#' "relative" for relative contribution, default = "absolute"
#' @param plot_type Either "jitter" for a jitter plot, "boxplot" for a boxplot, or "dotplot" for a dotplot
#'
#' @return A ggplot2 graph
#' @export
#' @importFrom magrittr %>%
#' @import ggplot2
#' @examples
#' ## Get the bootstrapped signature contributions
#' ## See 'count_indel_contexts()' for more info on how to do this.
#' contri_boots <- readRDS(system.file("states/bootstrapped_snv_refit.rds",
#'   package = "MutationalPatterns"
#' ))
#'
#' ## Plot bootstrapped contribution
#' plot_bootstrapped_contribution(contri_boots)
#'
#' ## Plot bootstrapped contribution with relative contributions
#' plot_bootstrapped_contribution(contri_boots, mode = "relative")
#'
#' ## Plot bootstrapped contribution with a boxplot
#' plot_bootstrapped_contribution(contri_boots, plot_type = "boxplot")
#' 
#' ## Plot bootstrapped contribution with a dotplot
#' plot_bootstrapped_contribution(contri_boots, plot_type = "dotplot", mode = "absolute")
plot_bootstrapped_contribution <- function(contri_boots,
                                           mode = c("absolute", "relative"),
                                           plot_type = c("jitter", "boxplot", "dotplot")) {
  mode <- match.arg(mode)
  plot_type <- match.arg(plot_type)

  # These variables use non standard evaluation.
  # To avoid R CMD check complaints we initialize them to NULL.
  sig <- contri <- lower <- upper <- NULL

  # Change variables based on relative or absolute mode.
  if (mode == "relative") {
    contri_boots <- contri_boots / rowSums(contri_boots)
    ylab_text <- "Relative mutation contribution"
    jitter_height <- 0.02
  } else {
    ylab_text <- "Mean nr contributed mutations"
    jitter_height <- 0.2
  }

  # Convert contri_boots into a long format.
  contri_tb <- contri_boots %>%
    as.data.frame() %>%
    tibble::rownames_to_column("exp") %>%
    tidyr::gather(key = "sig", value = "contri", -exp) %>%
    dplyr::mutate(
      sample = gsub("_[^_]+$", "", exp),
      sample = factor(sample, levels = unique(sample)),
      sig = factor(sig, levels = unique(sig))
    )

  if (plot_type == "jitter") {
    # Create basis for jitter figure
    fig <- ggplot(contri_tb, aes(x = sig, y = contri, color = sig)) +
      geom_jitter(stat = "identity", height = jitter_height, size = 0.3) +
      scale_color_discrete(guide = FALSE) +
      facet_grid(sample ~ .)
  } else if (plot_type == "boxplot") {
    # Calculate values for boxplot
    contri_tb2 <- contri_tb %>%
      dplyr::group_by(sample, sig) %>%
      dplyr::summarise(
        mean = mean(contri),
        lower = quantile(contri, 0.025),
        upper = quantile(contri, 0.975)
      ) %>%
      dplyr::ungroup()
    # Create basis for boxplot figure
    fig <- ggplot(contri_tb2, aes(x = sig, y = mean, fill = sig)) +
      geom_bar(stat = "identity") +
      geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.2) +
      scale_fill_discrete(guide = FALSE) +
      facet_grid(sample ~ .)
  } else if (plot_type == "dotplot") {
    contri_tb3 <- contri_tb %>%
      dplyr::group_by(sample, sig) %>%
      dplyr::summarise(
        mean =  mean(contri[contri != 0]),
        percentage = sum(contri != 0)/dplyr::n()
      ) %>%
      dplyr::ungroup() %>%
      dplyr::filter(!is.na(mean))
    fig = ggplot(contri_tb3, aes(x = sig, y = sample)) +
      geom_point(aes(color = percentage, size = mean)) +
      scale_color_distiller(palette = "RdYlBu")
  }
  
  ## Add extra labels to figure for all types
  fig = fig +
    labs(x = "Signature", y = ylab_text) +
    theme_classic() +
    theme(
      axis.text.x = element_text(angle = 90, size = 10, hjust = 1, vjust = 0.5),
      text = element_text(size = 12),
      strip.text.y = element_text(size = 8)
    )
  if (plot_type == 'dotplot') {
    fig = fig + 
      theme(panel.grid.major = element_line(colour = "gray95"))
  }
  return(fig)
}
