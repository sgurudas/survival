# SCCS @(#)residuals.coxph.penal.s	1.2 10/31/98
residuals.coxph.penal <- function(object, 
            type=c("martingale", "deviance", "score", "schoenfeld",
			  "dfbeta", "dfbetas", "scaledsch","partial"),
	    collapse=FALSE, weighted=FALSE, ...) {
      
    type <- match.arg(type)
    # Are there any sparse terms, and if so do I need the X matrix?
    if (any(object$pterms==2) && !(type=='martingale' || type=='deviance')){
	# treat the sparse term as an offset term
	#  It gets picked up in the linear predictor, so all I need to
	#  do is "X" it out of the model so that it doesn't get picked up
	#  as a part of the X matrix and etc.
	# I know that the sparse term is a single column BTW
	#
	sparsename <- (names(object$pterms))[object$pterms==2]
	x <- object$x
	if (is.null(x)) {
	    temp <- coxph.getdata(object, y=TRUE, x=TRUE, strata=TRUE)
	    if (is.null(object$y)) object$y <- temp$y
	    if (is.null(object$strata)) object$strata <- temp$strata
	    x <- temp$x
	    }
	object$x <- x[, -match(sparsename, dimnames(x)[[2]]), drop=FALSE]
    
	temp <- attr(object$terms, 'term.labels')
	object$terms <- object$terms[-match(sparsename, temp)]
	}
    NextMethod('residuals')
    }
