#' Compute graticules and their parameters
#' 
#' Compute graticules and their parameters
#'
#' @section Use of graticules:
#'  In cartographic visualization, the use of graticules is not advised, unless
#'  the graphical output will be used for measurement or navigation, or the
#'  direction of North is important for the interpretation of the content, or
#'  the content is intended to display distortions and artefacts created by 
#'  projection. Unnecessary use of graticules only adds visual clutter but 
#'  little relevant information. Use of coastlines, administrative boundaries
#'  or place names permits most viewers of the output to orient themselves
#'  better than a graticule.
#'
#' @export
#' @param x object of class \code{sf}, \code{sfc} or \code{sfg} or numeric vector with bounding box (minx,miny,maxx,maxy).
#' @param crs object of class \code{crs}, with the display coordinate reference system
#' @param datum object of class \code{crs}, with the coordinate reference system for the graticules
#' @param lon numeric; degrees east for the meridians
#' @param lat numeric; degrees north for the parallels
#' @param ndiscr integer; number of points to discretize a parallel or meridian
#' @param ... ignored
#' @return an object of class \code{sf} with additional attributes describing the type 
#' (E: meridian, N: parallel) degree value, label, start and end coordinates and angle;
#' see example.
#' @examples 
#' library(sf)
#' library(maps)
#' 
#' usa = st_as_sf(map('usa', plot = FALSE, fill = TRUE))
#' laea = st_crs("+proj=laea +lat_0=30 +lon_0=-95") # Lambert equal area
#' usa <- st_transform(usa, laea)
#' 
#' bb = st_bbox(usa)
#' bbox = st_linestring(rbind(c( bb[1],bb[2]),c( bb[3],bb[2]),
#'    c( bb[3],bb[4]),c( bb[1],bb[4]),c( bb[1],bb[2])))
#' 
#' g = st_graticule(usa)
#' plot(usa, xlim = 1.2 * c(-2450853.4, 2186391.9))
#' plot(g[1], add = TRUE, col = 'grey')
#' plot(bbox, add = TRUE)
#' points(g$x_start, g$y_start, col = 'red')
#' points(g$x_end, g$y_end, col = 'blue')
#' 
#' invisible(lapply(seq_len(nrow(g)), function(i) {
#'	if (g$type[i] == "N" && g$x_start[i] - min(g$x_start) < 1000)
#'		text(g[i,"x_start"], g[i,"y_start"], labels = parse(text = g[i,"degree_label"]), 
#'			srt = g$angle_start[i], pos = 2, cex = .7)
#'	if (g$type[i] == "E" && g$y_start[i] - min(g$y_start) < 1000)
#'		text(g[i,"x_start"], g[i,"y_start"], labels = parse(text = g[i,"degree_label"]), 
#'			srt = g$angle_start[i] - 90, pos = 1, cex = .7)
#'	if (g$type[i] == "N" && g$x_end[i] - max(g$x_end) > -1000)
#'		text(g[i,"x_end"], g[i,"y_end"], labels = parse(text = g[i,"degree_label"]), 
#'			srt = g$angle_end[i], pos = 4, cex = .7)
#'	if (g$type[i] == "E" && g$y_end[i] - max(g$y_end) > -1000)
#'		text(g[i,"x_end"], g[i,"y_end"], labels = parse(text = g[i,"degree_label"]), 
#'			srt = g$angle_end[i] - 90, pos = 3, cex = .7)
#' }))
#' plot(usa, graticule = st_crs(4326), axes = TRUE, lon = seq(-60,-130,by=-10))
st_graticule = function(x = c(-180,-90,180,90), crs = st_crs(x), 
	datum = st_crs(4326), ..., lon = NULL, lat = NULL, ndiscr = 100)
{
	if (missing(x)) {
		crs = datum
		if (is.null(lon))
			lon = seq(-180, 180, by = 20)
		if (is.null(lat))
			lat = seq(-80, 80, by = 20)
	}

	# Get the bounding box of the plotting space, in crs
	bb = if (inherits(x, "sf") || inherits(x, "sfc") || inherits(x, "sfg"))
		st_bbox(x)
	else
		x
	stopifnot(is.numeric(bb) && length(bb) == 4)

	ls = st_linestring(rbind(c(bb[1],bb[2]), c(bb[3],bb[2]), c(bb[3],bb[4]), 
		c(bb[1],bb[4]), c(bb[1],bb[2])))
	box = st_sfc(ls, crs = crs)

	box = st_segmentize(box, st_length(ls) / 400, warn = FALSE)

	# Now we're moving to long/lat:
	if (!is.na(crs))
		box = st_transform(box, datum)

	if (is.null(lon))
		lon = pretty(st_bbox(box)[c(1,3)])
	if (is.null(lat))
		lat = pretty(st_bbox(box)[c(2,4)])
	# sanity:
	lon = lon[lon >= -180 & lon <= 180]
	lat = lat[lat > -90 & lat < 90]

	bb = st_bbox(box)
	# widen bb if pretty() created values outside the box:
	bb = c(min(bb[1], min(lon)), min(bb[2],min(lat)), max(bb[3], max(lon)), max(bb[4], max(lat)))

	long_list <- vector(mode="list", length=length(lon))
	for (i in seq_along(long_list))
		long_list[[i]] <- st_linestring(cbind(rep(lon[i], ndiscr), seq(bb[2], bb[4], length.out=ndiscr)))

	lat_list <- vector(mode="list", length=length(lat))
	for (i in seq_along(lat_list))
		lat_list[[i]] <- st_linestring(cbind(seq(bb[1], bb[3], length.out=ndiscr), rep(lat[i], ndiscr)))
	
	df = data.frame(degree = c(lon, lat))
	df$type = c(rep("E", length(lon)), rep("N", length(lat)))
	df$degree_label = c(degreeLabelsEW(lon), degreeLabelsNS(lat)) 

	geom = st_sfc(c(long_list, lat_list), crs = datum)

	# Now we're moving the straight lines back to curves in crs:
	if (!is.na(crs))
		geom = st_transform(geom, crs)

	st_geometry(df) = geom
	st_agr(df) = "constant"

	if (!missing(x)) { # cut out box:
		if (! is.na(crs))
			box = st_transform(box, crs)
		df = st_intersection(df, st_polygonize(box))
	}
	graticule_attributes(st_cast(df, "MULTILINESTRING"))
}

graticule_attributes = function(df) {
	object = st_geometry(df)
	xy = cbind(
		do.call(rbind, lapply(object, function(x) { y = x[[1]]; y[1,] } )),
		do.call(rbind, lapply(object, function(x) { y = x[[length(x)]]; y[nrow(y),] } ))
	)
	df$x_start = xy[,1]
	df$y_start = xy[,2]
	df$x_end   = xy[,3]
	df$y_end   = xy[,4]
	dxdy = do.call(rbind, lapply(object, function(x) { y = x[[1]]; apply(y[1:2,], 2, diff) } ))
	df$angle_start = apply(dxdy, 1, function(x) atan2(x[2], x[1])*180/pi)
	dxdy = do.call(rbind, lapply(object, 
		function(x) { y = x[[length(x)]]; n = nrow(y); apply(y[(n-1):n,], 2, diff) } ))
	df$angle_end = apply(dxdy, 1, function(x) atan2(x[2], x[1])*180/pi)
	df
}

# copied from sp:
degreeLabelsNS = function(x) {
	pos = sign(x) + 2
	dir = c("*S", "", "*N")
	paste0(abs(x), "*degree", dir[pos])
}
degreeLabelsEW = function(x) {
	x <- ifelse(x > 180, x - 360, x)
	pos = sign(x) + 2
	if (any(x == -180))
		pos[x == -180] = 2
	if (any(x == 180))
		pos[x == 180] = 2
	dir = c("*W", "", "*E")
	paste0(abs(x), "*degree", dir[pos])
}
