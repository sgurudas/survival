# SCCS @(#)survexp.s	5.2 02/19/99

survexp <- function(formula=formula(data), data=parent.frame(),
	weights, subset, na.action,
	times,  cohort=TRUE,  conditional=FALSE,
	ratetable=survexp.us, scale=1, npoints, se.fit,
	model=FALSE, x=FALSE, y=FALSE) {

    call <- match.call()
    m <- match.call(expand=FALSE)
    m$ratetable <- m$model <- m$x <- m$y <- m$scale<- m$cohort <- NULL
    m$times <- m$conditional <- m$npoints <- m$se.fit <- NULL

    Terms <- if(missing(data)) terms(formula, 'ratetable')
	     else              terms(formula, 'ratetable',data=data)

    rate <- attr(Terms, "specials")$ratetable
    if(length(rate) > 1)
	    stop("Can have only 1 ratetable() call in a formula")
    if(length(rate) == 0) {
	# add a 'ratetable' call to the internal formula
        # The dummy function stops an annoying warning message "Looking for
        #  'formula' of mode function, ignored one of mode ..."
	xx <- function(x) formula(x)
    
	if(is.ratetable(ratetable))   varlist <- attr(ratetable, "dimid")
	else if(inherits(ratetable, "coxph")) {
	    varlist <- names(ratetable$coef)
	    # Now remove "log" and such things, using terms.inner
	    temp <- terms.inner(xx(paste("~", paste(varlist, collapse='+'))))
	    varlist <- attr(temp, 'term.labels')
            }
	else stop("Invalid rate table")

	ftemp <- deparse(substitute(formula))
	formula <- xx( paste( ftemp, "+ ratetable(",
			  paste( varlist, "=", varlist, collapse = ","), ")"))
	Terms <- if (missing(data)) terms(formula, "ratetable")
	         else               terms(formula, "ratetable", data = data)
	rate <- attr(Terms, "specials")$ratetable
	}

    m$formula <- Terms
    m[[1]] <- as.name("model.frame")
    m <- eval(m, parent.frame())
    n <- nrow(m)

    if (any(attr(Terms, 'order') >1))
	    stop("Survexp cannot have interaction terms")
    if (!missing(times)) {
	if (any(times<0)) stop("Invalid time point requested")
	if (length(times) >1 )
	    if (any(diff(times)<0)) stop("Times must be in increasing order")
	}

    Y <- model.extract(m, 'response')
    no.Y <- is.null(Y)
    if (!no.Y) {
	if (is.matrix(Y)) {
	    if (is.Surv(Y) && attr(Y, 'type')=='right') Y <- Y[,1]
	    else stop("Illegal response value")
	    }
	if (any(Y<0)) stop ("Negative follow up time")
	if (missing(npoints)) temp <- unique(Y)
	else                  temp <- seq(min(Y), max(Y), length=npoints)
	if (missing(times)) newtime <- sort(temp)
	else  newtime <- sort(unique(c(times, temp[temp<max(times)])))
	}
    else conditional <- FALSE
    weights <- model.extract(m, 'weights')
    if (!is.null(weights)) warning("Weights ignored")

    if (no.Y) ovars <- attr(Terms, 'term.labels')[-rate]
    else      ovars <- attr(Terms, 'term.labels')[-(rate-1)]
	
    if (is.ratetable(ratetable)) {
	israte <- TRUE
	if (no.Y) {
	    if (missing(times))
	       stop("There is no times argument, and no follow-up times are given in the formula")
	    else newtime <- sort(unique(times))
	    Y <- rep(max(times), n)
	    }
	se.fit <- FALSE
	rtemp <- match.ratetable(m[,rate], ratetable)
	R <- rtemp$R
	if (!is.null(rtemp$call)) {  #need to dop some dimensions from ratetable
	    ratetable <- eval(parse(text=rtemp$call))
	    }
       }
    else if (inherits(ratetable, 'coxph')) {
	israte <- FALSE
	Terms <- ratetable$terms
	if (!inherits(Terms, 'terms'))
		stop("invalid terms component of fit")
	if (!is.null(attr(Terms, 'offset')))
	    stop("Cannot deal with models that contain an offset")
	m2 <- data.frame(unclass(m[,rate]))
	strats <- attr(Terms, "specials")$strata
	if (length(strats))
	    stop("survexp cannot handle stratified Cox models")
	R <- model.matrix(delete.response(Terms), m2)[,-1,drop=FALSE]
	if (any(dimnames(R)[[2]] != names(ratetable$coef)))
	    stop("Unable to match new data to old formula")
	if (no.Y) {
	    if (missing(se.fit)) se.fit <- TRUE
	    }
	else se.fit <- FALSE
	}
    else stop("Invalid ratetable argument")

    if (cohort) {
	# Now process the other (non-ratetable) variables
	if (length(ovars)==0)  X <- rep(1,n)  #no categories
	else {
	    odim <- length(ovars)
	    for (i in 1:odim) {
		temp <- m[[ovars[i]]]
		ctemp <- class(temp)
		if (!is.null(ctemp) && ctemp=='tcut')
		    stop("Can't use tcut variables in expected survival")
		}
	    X <- strata(m[ovars])
	    }

	#do the work
	if (israte)
	    temp <- survexp.fit(cbind(as.numeric(X),R), Y, newtime,
			       conditional, ratetable)
	else {
	    temp <- survexp.cfit(cbind(as.numeric(X),R), Y, conditional, FALSE,
			       ratetable, se.fit=se.fit)
	    newtime <- temp$times
	    }
	#package the results
	if (missing(times)) {
	    n.risk <- temp$n
	    surv <- temp$surv
	    if (se.fit) err <- temp$se
	    }
	else {
	    if (israte) keep <- match(times, newtime)
	    else {
		# taken straight out of summary.survfit....
		n <- length(temp$times)
		temp2 <- .C("survindex2", as.integer(n),
					  as.double(temp$times),
					  as.integer(rep(1,n)),
					  as.integer(length(times)),
					  as.double(times),
					  as.integer(1),
					  indx = integer(length(times)),
					  indx2= integer(length(times)),
                            PACKAGE="survival")
		keep <- temp2$indx[temp2$indx>0]
		}

	    if (is.matrix(temp$surv)) {
		surv <- temp$surv[keep,,drop=FALSE]
		n.risk <- temp$n[keep,,drop=FALSE]
		if (se.fit) err <- temp$se[keep,,drop=FALSE]
		}
	    else {
		surv <- temp$surv[keep]
		n.risk <- temp$n[keep]
		if (se.fit) err <- temp$se[keep]
		}
	    newtime <- times
	    }
	newtime <- newtime/scale
	if (length(ovars)) {    #matrix output
	    if (no.Y && israte){ # n's are all the same, so just send a vector
		dimnames(surv) <- list(NULL, levels(X))
		out <- list(call=call, surv=surv, n.risk=c(n.risk[,1]),
			    time=newtime)
		}
	    else {
		#Need a matrix of n's, and a strata component
		out <- list(call=call, surv=surv, n.risk=n.risk,
				time = newtime)
		tstrat <- rep(nrow(surv), ncol(surv))
		names(tstrat) <- levels(X)
		out$strata <- tstrat
		}
	    if (se.fit) out$std.err <- err
	    }
	else {
	     out <- list(call=call, surv=c(surv), n.risk=c(n.risk),
			   time=newtime)
	     if (se.fit) out$std.err <- c(err)
	     }

	na.action <- attr(m, "na.action")
	if (length(na.action))  out$na.action <- na.action
	if (model) out$model <- m
	else {
	    if (x) out$x <- structure(cbind(X, R),
		dimnames=list(row.names(m), c("group", dimid)))
	    if (y) out$y <- Y
	    }
	if (israte && !is.null(rtemp$summ)) out$summ <- rtemp$summ
	if (no.Y) out$method <- 'exact'
	else if (conditional) out$method <- 'conditional'
	else                  out$method <- 'cohort'
	class(out) <- c('survexp', 'survfit')
	out
	}

    else { #individual survival
	if (no.Y) stop("For non-cohort, an observation time must be given")
	if (israte)
	    temp <- survexp.fit (cbind(1:n,R), Y, max(Y), TRUE, ratetable)
	else temp<- survexp.cfit(cbind(1:n,R), Y, FALSE, TRUE, ratetable, FALSE)
	xx <- temp$surv
	names(xx) <- row.names(m)
	na.action <- attr(m, "na.action")
	if (length(na.action)) naresid(na.action, xx)
	else xx
	}
    }
