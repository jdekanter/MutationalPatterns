#' Plot the strands of variants to show lesion segregation
#'
#' The strands of variants in a GRanges object is plotted.
#' This way the presence of any lesion segregation is visualized.
#'
#' @param vcf GRanges object
#' @param per_chrom Boolean. Determines whether to create a separate plot per chromosome
#' @param sample_name Name of the sample
#'
#' @return ggplot2 object
#' @export
#' @seealso
#' \code{\link{calculate_lesion_segregation}}
#' @family Lesion_segregation
#' @examples
#'
#' ## See the 'read_vcfs_as_granges()' example for how we obtained the
#' ## following data:
#' grl <- readRDS(system.file("states/read_vcfs_as_granges_output.rds",
#'   package = "MutationalPatterns"
#' ))
#' ## Select a single GRanges object to plot.
#' gr <- grl[[1]]
#'
#' ## Plot lesion segregation
#' plot_lesion_segregation(gr, sample_name = "Colon1")
#'
#' ## Plot lesion segregation per chromosome
#' plot_lesion_segregation(gr, per_chrom = TRUE, sample_name = "Colon1")
plot_lesion_segregation <- function(vcf, per_chrom = FALSE, sample_name = NA) {

  # These variables use non standard evaluation.
  # To avoid R CMD check complaints we initialize them to NULL.
  max_pos <- start_mb <- notused <- NULL

  # Get strandedness
  vcf <- .get_strandedness_gr(vcf)
  
  #Genome is set to NULL to ensure seqlevels can be changed.
  GenomeInfoDb::genome(vcf) <- NA
  GenomeInfoDb::seqlevelsStyle(vcf) <- "NCBI" # This takes less space when plotting
  
  tb <- .get_strandedness_tb(vcf)

  # Ensures that the entire chromosomes are plotted, even when mutations don't span the entire chromosome.
  tb_limits <- GenomeInfoDb::seqlengths(vcf) %>%
    tibble::enframe(name = "seqnames", value = "max_pos") %>%
    dplyr::mutate(
      max_pos_mb = max_pos / 1000000,
      min_pos_mb = 1,
      seqnames = factor(seqnames, levels = levels(tb$seqnames))
    ) %>%
    dplyr::select(-max_pos) %>%
    tidyr::gather(key = "notused", value = "start_mb", -seqnames) %>%
    dplyr::mutate(
      start_mb = tidyr::replace_na(start_mb, 0), # NAs generated by unknown seqlevel lengths are replaced.
      y = ifelse(notused == "max_pos_mb", 1, 0)
    ) # Ensure there is always a 1 and a -1 in each chromosome.

  # Get x axis breaks
  if (nrow(tb)) {
    x_axis_breaks <- .lesion_get_x_axis_breaks(max(tb$start_mb), per_chrom = per_chrom)
  } else {
    x_axis_breaks <- 50
  }

  # Set point_sizes
  point_size <- 100 / length(vcf)
  if (per_chrom == TRUE) {
    point_size <- point_size * 5
  }
  if (point_size > 2) {
    point_size <- 2
  } else if (point_size < 0.02) {
    point_size <- 0.02
  }

  # Create plots
  if (per_chrom == FALSE) {
    fig <- .plot_lesion_segregation_gg(tb, tb_limits, x_axis_breaks, point_size, sample_name)
    return(fig)
  } else {
    tb_l <- split(tb, tb$seqnames)
    tb_limits_l <- split(tb_limits, tb_limits$seqnames)
    fig_l <- mapply(.plot_lesion_segregation_gg,
      tb_l, tb_limits_l,
      MoreArgs = list("x_axis_breaks" = x_axis_breaks, "point_size" = point_size, "sample_name" = sample_name),
      SIMPLIFY = FALSE
    )
    return(fig_l)
  }
}


#' Determine the x axis breaks of a lesion segregation plot
#'
#' The maximum x axis value is determined by the variant with the highest coordinate.
#' Additionally, there are more breaks when the plot is created per chromosome.
#'
#' @param max_coord Maximum coordinate value of a variant
#' @param per_chrom Boolean. Describing whether to create a separate plot per chromosome
#'
#' @return Numeric vector of x_axis_breaks
#' @noRd
#'
.lesion_get_x_axis_breaks <- function(max_coord, per_chrom) {

  # Set x-axis breaks
  if (per_chrom == TRUE) {
    x_axis_break_length <- 10
  } else {
    x_axis_break_length <- 50
  }

  if (max_coord < x_axis_break_length) {
    x_axis_breaks <- x_axis_break_length
  } else {
    x_axis_breaks <- seq(x_axis_break_length, max_coord, by = x_axis_break_length)
  }
  return(x_axis_breaks)
}


#' Plot the strands of variants to show lesion segregation
#'
#' This is a helper function for 'plot_lesion_segregation'.
#' It performs the actual plotting.
#'
#' @param tb A tibble with strand information of variants
#' @param tb_limits tibble describing the chromosome limits.
#' This ensures entire chromosomes are plotted,
#' instead of just the part with variants
#' @param x_axis_breaks x_axis_breaks
#' @param point_size Scalar describing the point size of the plot
#' @param sample_name Name of the sample
#'
#' @return ggplot2 object
#'
#' @import ggplot2
#' @noRd
#'
.plot_lesion_segregation_gg <- function(tb, tb_limits, x_axis_breaks, point_size, sample_name) {

  # These variables use non standard evaluation.
  # To avoid R CMD check complaints we initialize them to NULL.
  y <- start_mb <- NULL

  if (.is_na(sample_name)) {
    my_labs <- labs(y = "Strand", x = "Coordinate (mb)")
  } else {
    my_labs <- labs(y = "Strand", x = "Coordinate (mb)", title = sample_name)
  }


  # Plot strandedness
  fig <- ggplot(tb, aes(y = y, x = start_mb)) +
    geom_jitter(width = 0, height = 0.1, size = point_size) +
    facet_grid(. ~ seqnames, scales = "free_x", space = "free_x") +
    geom_blank(data = tb_limits) +
    scale_y_continuous(breaks = c(0, 1), labels = c("-", "+"), limits = c(-0.5, 1.5)) +
    scale_x_continuous(breaks = x_axis_breaks) +
    my_labs +
    theme_bw() +
    theme(
      text = element_text(size = 18),
      axis.text.x = element_text(size = 11, angle = 90, vjust = 0.5, hjust = 1),
      axis.text.y = element_text(size = 20),
      panel.grid.minor = element_blank()
    )

  return(fig)
}
