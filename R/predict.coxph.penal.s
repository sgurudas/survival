# SCCS @(#)predict.coxph.penal.s	5.3 11/25/98
predict.coxph.penal <- function(object,  newdata, 
				type=c("lp", "risk", "expected", "terms"),
				se.fit=FALSE, terms=names(object$assign), 
				collapse, safe=FALSE, ...) {
 
    type <- match.arg(type)
    n <- object$n
    Terms <- object$terms
    pterms <- object$pterms
    # If there are no sparse terms
    if (!any(pterms==2) || type=='expected' || 
	(missing(newdata) && se.fit==F && type!='terms')) NextMethod('predict',object,...)
    else {
	# treat the sparse term as an offset term
	#  It gets picked up in the linear predictor, so all I need to
	#  do is "X" it out of the model so that it doesn't get picked up
	#  as a part of the X matrix and etc.
	# I know that the sparse term is a single column BTW
	#
	termname <- names(object$pterms)
	sparsename <- termname[object$pterms==2]
	nvar <- length(termname)
	na.action <- object$na.action
	object$na.action <- NULL

	if (missing(newdata) && (se.fit || type=='terms')) {
	    # I need the X matrix
	    x <- object$x
	    if (is.null(x)) {
		temp <- coxph.getdata(object, y=TRUE, x=TRUE, strata=TRUE)
		if (is.null(object$y)) object$y <- temp$y
		if (is.null(object$strata)) object$strata <- temp$strata
		x <- temp$x
		}
	    xvar <- match(sparsename, dimnames(x)[[2]])
	    indx <- as.numeric(as.factor(x[,xvar]))
	    object$x <- x[, -xvar, drop=F]
	    }
	
	if (nvar==1) {
	    # Only the sparse term!
	    if (!missing(newdata)) {
		n <- nrow(as.data.frame(newdata))
		pred <- rep(0,n)
		}
	    se <- sqrt(object$fvar[indx])
	    pred <- object$linear.predictor
	    if (type=='risk') pred <- exp(pred)
	    }
	else {
	    temp <- attr(object$terms, 'term.labels')
	    object$terms <- object$terms[-match(sparsename, temp)]
            temp<-match(sparsename,terms)
            oldTerms<-terms
            if (!is.na(temp)) terms<-terms[-temp]
	    pred <- NextMethod('predict',object,terms=terms,...)
            terms<-oldTerms
	    if (se.fit) {
		se <- pred$se.fit
		pred <- pred$fit
		}

	    if (type=='terms' && missing(newdata)) {
		# In this case (only) I add the sparse term back in
		spterm <- object$frail[indx]
		spstd  <- sqrt(object$fvar[indx])
		if (nvar==2) {
		    if (xvar==2) {
			pred <- cbind(pred, spterm)
			if (se.fit) se <- cbind(se, spstd)
			}
		    else {
			pred <- cbind(spterm, pred)
			if (se.fit) se <- cbind(spstd, se)
			}
		    }
		else {
		    first <- if (xvar==1) 0 else 1:(xvar-1)
		    secnd <- if (xvar==nvar) 0 else  (xvar+1):nvar
		    pred  <- cbind(pred[,first], spterm, pred[,secnd])
		    if (se.fit)
			    se <- cbind(se[,first], spstd, se[,secnd])
		    }
		dimnames(pred) <- list(dimnames(x)[[1]], termname)
		if (se.fit) dimnames(se) <- dimnames(pred)
		}
	    }

	#Expand out the missing values in the result
	# But only if operating on the original dataset
	if (missing(newdata) && !is.null(na.action)) {
	    pred <- naresid(na.action, pred)
	    if (is.matrix(pred)) n <- nrow(pred)
	    else                 n <- length(pred)
	    if(se.fit) se <- naresid(na.action, se)
	    }

	# Collapse over subjects, if requested
	if (!missing(collapse)) {
	    if (length(collapse) != n) 
		    stop("Collapse vector is the wrong length")
	    pred <- rowsum(pred, collapse)
	    if (se.fit) se <- sqrt(rowsum(se^2, collapse))
	    }

	if (se.fit) list(fit=pred, se.fit=se)
	else pred
	}
    }
		


