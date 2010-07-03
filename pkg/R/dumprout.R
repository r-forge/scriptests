dumprout <- function(res = .Last.value, output.suffix = ".Rout.tmp", verbose = TRUE, clobber = identical(output.suffix, ".Rout.tmp")) {
    if (!is.element("RtTestSetResultsList", class(res)))
        stop("supplied argument is not a return value of runtests()")
    if (length(output.suffix)!=1)
        stop("length(output.suffix)!=1")
    if (is.character(output.suffix) && output.suffix!="") {
        if (substring(output.suffix, 1, 1)!=".")
            output.suffix <- paste(".", output.suffix, sep="")
    } else {
        output.suffix <- ".Rout.tmp"
    }
    for (i in seq(along=res)) {
        outfile <- basename(names(res)[i])
        if (outfile != "") {
            outfile <- gsub("\\.Rt", output.suffix, outfile)
            if (file.exists(outfile) && !clobber) {
                warning("file ", outfile, " exists already, specify clobber=TRUE to overwrite")
            } else {
                if (verbose)
                    cat("* Writing transcript of actual output to ", outfile, "\n", sep="")
                sink(outfile)
                on.exit(sink())
                print(res[[i]], transcript=TRUE)
                sink()
                on.exit()
            }
        }
    }
}

