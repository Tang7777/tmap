#' Save tmap
#' 
#' Save tmap to a file, such as png, jpg, or pdf.
#'
#' @param tm tmap object
#' @param filename filename including extension, and optionally the path. The extensions pdf, eps, svg, wmf (Windows only), png, jpg, bmp, or tiff are supported. If the extension is missing, the file will be saved as png image
#' @param width width. Units are set with the argument \code{units}. If set to \code{NA} and \code{height} is specified, it will be \code{height} * aspect ratio. If both \code{width} and \code{height} are not specified, then the width of the current plotting window will be taken.
#' @param height height. Units are set with the argument \code{units}. If set to \code{NA} and \code{width} is specified, it will be \code{width} / aspect ratio. If both \code{width} and \code{height} are not specified, then the height of the current plotting window will be taken.
#' @param units units for width and height (\code{"in"}, \code{"cm"}, or \code{"mm"}). By default, pixels (\code{"px"}) are used if either width or height is set to a value greater than 50. Else, the units are inches (\code{"in"})
#' @param dpi dots per inch. Only applicable for raster graphics.
#' @param outer.margins overrides the outer.margins argument of \code{\link{tm_layout}} (unless set to \code{NA})
#' @param asp if specified, it overrides the asp argument of \code{\link{tm_layout}}. Tip: set to \code{0} if map frame should be placed on the edges of the image.
#' @param scale overrides the scale argument of \code{\link{tm_layout}} (unless set to \code{NA})
#' @param insets_tm tmap object of an inset map, or a list of tmap objects of multiple inset maps. The number of tmap objects should be equal to the number of viewports specified with \code{insets_vp}.
#' @param insets_vp \code{\link[grid:viewport]{viewport}} of an inset map, or a list of \code{\link[grid:viewport]{viewport}}s of multiple inset maps. The number of viewports should be equal to the number of tmap objects specified with \code{insets_tm}.
#' @param verbose Deprecated. It is now controlled by the tmap option \code{show.messages} (see \code{\link{tmap_options}})
#' @param ... arguments passed on to device functions or to \code{\link[htmlwidgets:saveWidget]{saveWidget}}
#' @importFrom htmlwidgets saveWidget
#' @import tmaptools
#' @example ./examples/tmap_save.R
#' @export
tmap_save <- function(tm=NULL, filename=NULL, width=NA, height=NA, units = NA,
					  dpi=300, outer.margins=NA, asp=NULL, scale=NA, insets_tm=NULL, insets_vp=NULL, verbose = NULL, ...) {
	if (!missing(verbose)) warning("The argument verbose is deprecated. Please use the option show.messages of tmap_options instead.")
	verbose <- get(".tmapOptions", envir = .TMAP_CACHE)$show.messages
	
	lastcall <- x <- get(".last_map", envir = .TMAP_CACHE)
	
	if (missing(tm)) {
		tm <- suppressWarnings(last_map())
		if (is.null(tm)) stop("A map has not been created yet")
		is.arrange <- FALSE
	} else if (inherits(tm, "tmap")) {
		is.arrange <- FALSE
	} else if (inherits(tm, "tmap_arrange")) {
		is.arrange <- TRUE
	} else {
		stop("Unknown format. tm should be either a tmap output, or a list of tmap outputs")
	}
	
	tmap.mode <- getOption("tmap.mode")
	default_ext <- ifelse(tmap.mode == "plot", "png", "html")
	
	if (!is.arrange) {
		shp_name <- function(tm) {
			paste0(tm[[1]]$shp_name, ".", default_ext)
		}
		if (missing(filename)) {
			filename <- shp_name(tm)
		}
	} else if (missing(filename)) {
		filename <- paste0("map.", default_ext)
	}
	
	on.exit({
		assign(".last_map", lastcall, envir = .TMAP_CACHE)
	})
	
	
	
	get_ext <- function(filename, default_ext) {
		pieces <- strsplit(filename, "\\.")[[1]]
		if (length(pieces)==1) return(default_ext)
		tolower(pieces[length(pieces)])
	}
	
	convert_to_inches <- function(x, units) {
		x <- switch(units, px = x/dpi, `in` = x, cm = x/2.54, mm = x/2.54/10)
	}
	convert_to_pixels <- function(x, units) {
		x <- switch(units, px = x, `in` = dpi*x, cm = dpi*x/2.54, mm = dpi*x/2.54/10)
	}
	
	ext <- get_ext(filename, default_ext)
	
	interactive <- (ext=="html")
	
	options(tmap.mode=ifelse(interactive, "view", "plot"))
	
	if (interactive) {
		if (is.arrange) {
			lf <- tm
		} else {
			lf <- tmap_leaflet(tm)
		}
			
		saveWidget(lf, file=filename, ...)
		options(tmap.mode=tmap.mode)
		if (verbose) {
			message("Interactive map saved to ", suppressWarnings(normalizePath(filename)))
		}
		return(invisible())
	}

	## impute missing w or h
	if (is.na(width) && is.na(height)) {
		width <- par("din")[1]
		height <- par("din")[2]
		if (is.na(units)) units <- "in"
	} else if (is.na(width) || is.na(height)) {
		if (!is.na(width)) {
			if (is.na(units)) units <- ifelse(width>50, "px", "in")
			
			temp_size <- convert_to_pixels(width, units)
		} else {
			if (is.na(units)) units <- ifelse(height>50, "px", "in")
			temp_size <- convert_to_pixels(height, units)
		}
		
		if (is.arrange) {
			sasp <- 1
		} else {
			show.messages <- tmap_options(show.messages = FALSE)
			on.exit(tmap_options(show.messages))
			sasp <- get_asp_ratio(tm, width = temp_size, height = temp_size, res = dpi)	
			tmap_options(show.messages)
		} 
		if (is.na(width)) {
			width <- height * sasp
		} else if (is.na(height)) {
			height <- width / sasp
		}
	} else {
		if (is.na(units)) units <- ifelse(width > 50 || height > 50, "px", "in")
	}
	units_target <- ifelse(units=="px" && ext %in% c("png", "jpg", "jpeg", "bmp", "tiff"), "px", "in")
	
		
	eps <- ps <- function(..., width, height) grDevices::postscript(..., 
																	width = width, height = height, onefile = FALSE, horizontal = FALSE, 
																	paper = "special")
	tex <- function(..., width, height) grDevices::pictex(..., 
														  width = width, height = height)
	pdf <- function(..., version = "1.4") grDevices::pdf(..., 
														 version = version)
	svg <- function(...) grDevices::svg(...)
	wmf <- function(..., width, height) grDevices::win.metafile(..., 
																width = width, height = height)
	emf <- function(..., width, height) grDevices::win.metafile(..., 
																width = width, height = height)
	png <- function(..., width, height) grDevices::png(..., width = width, 
													   height = height, res = dpi, units = units_target)
	jpg <- jpeg <- function(..., width, height) grDevices::jpeg(..., 
																width = width, height = height, res = dpi, units = units_target)
	bmp <- function(..., width, height) grDevices::bmp(..., width = width, 
													   height = height, res = dpi, units = units_target)
	tiff <- function(..., width, height) grDevices::tiff(..., 
														 width = width, height = height, res = dpi, units = units_target)


	
	if (units_target=="in") {
	  width <- convert_to_inches(width, units)
	  height <- convert_to_inches(height, units)
	  
	  if (ext=="pdf") {
	    round_to_1_72 <- function(x) x %/% (1/72) / 72
	    width <- round_to_1_72(width)
	    height <- round_to_1_72(height)
	  }
	} else {
		width <- convert_to_pixels(width, units)
		height <- convert_to_pixels(height, units)
	}
	
	do.call(ext, args = c(list(file = filename, width = width, height = height), list(...)))
	on.exit(capture.output(dev.off()), add = TRUE)
	
	if (is.arrange) {
		if (is.na(outer.margins[1])) {
			do.call(tmap_arrange, tm)
		} else {
			do.call(tmap_arrange, c(tm, list(outer.margins = outer.margins)))
		}
	} else {
		args <- list()
		if (!is.na(outer.margins[1])) args$outer.margins <- outer.margins
		if (!missing(asp)) args$asp <- asp
		if (!is.na(scale)) args$scale <- scale
		print(tm + do.call("tm_layout", args))
	}
	
	
	if (!is.arrange && !missing(insets_tm) && !missing(insets_vp)) {
	  args_inset <- if (!is.na(scale)) list(scale = scale) else list()
	  if (class(insets_tm)=="list" && class(insets_vp)=="list") {
	    if (length(insets_tm) != length(insets_vp)) stop("Number of insets unequal to number of viewports")
	    mapply(function(tm_i, vp_i) {
	      print(tm_i + do.call("tm_layout", args_inset), vp=vp_i)
	    }, insets_tm, insets_vp)
	  } else if (inherits(insets_tm, "tmap") && inherits(insets_vp, "viewport")) {
	    print(insets_tm + do.call("tm_layout", args_inset), insets_vp)
	  } else {
	    stop("Insets and/or its viewports not in the correct format")
	  }
	}
	
	if (verbose) {
		message("Map saved to ", suppressWarnings(normalizePath(filename)))
		if (ext %in% c("png", "jpg", "jpeg", "bmp", "tiff")) {
			if (units_target == "px") {
				wp <- format(width)
				hp <- format(height)
				wi <- format(convert_to_inches(width, "px"))
				hi <- format(convert_to_inches(height, "px"))
			} else {
				wi <- format(width)
				hi <- format(height)
				wp <- format(convert_to_pixels(width, "in"))
				hp <- format(convert_to_pixels(height, "in"))
			}
			message("Resolution: ", format(wp), " by ", format(hp), " pixels") 
			message("Size: ", wi, " by ", hi, " inches (", format(dpi), " dpi)") 
		} else {
			wi <- format(width)
			hi <- format(height)
			message("Size: ", wi, " by ", hi, " inches") 
		}
	}
	
	options(tmap.mode=tmap.mode)
	invisible()
}
