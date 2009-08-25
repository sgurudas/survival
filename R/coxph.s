# $Id: coxph.S 11282 2009-05-21 11:00:22Z therneau $
if (!is.R())  setOldClass(c('coxph.penal', 'coxph'))

coxph <- function(formula, data, weights, subset, na.action,
	init, control, method= c("efron", "breslow", "exact"),
	singular.ok =TRUE, robust=FALSE,
	model=FALSE, x=FALSE, y=TRUE, ...) {

    method <- match.arg(method)
    Call <- match.call()

    # create a call to model.frame() that contains the formula (required)
    #  and any other of the relevant optional arguments
    # then evaluate it in the proper frame
    indx <- match(c("formula", "data", "weights", "subset", "na.action"),
                  names(Call), nomatch=0) 
    if (indx[1] ==0) stop("A formula argument is required")
    temp <- Call[c(1,indx)]  # only keep the arguments we wanted
    temp[[1]] <- as.name('model.frame')  # change the function called

    special <- c("strata", "cluster")
    temp$formula <- if(missing(data)) terms(formula, special)
                    else              terms(formula, special, data=data)
    if (is.R()) m <- eval(temp, parent.frame())
    else        m <- eval(temp, sys.parent())

    if (nrow(m) ==0) stop("No (non-missing) observations")
    Terms <- attr(m, 'terms')

    if (missing(control)) control <- coxph.control(...)
    Y <- model.extract(m, "response")
    if (!inherits(Y, "Surv")) stop("Response must be a survival object")
    weights <- model.weights(m)
    offset <- model.offset(m)
    if (is.null(offset) | all(offset==0)) offset <- rep(0., nrow(m))

    attr(Terms,"intercept")<- 1  #Cox model always has \Lambda_0
    strats <- attr(Terms, "specials")$strata
    cluster<- attr(Terms, "specials")$cluster
    dropx <- NULL
    if (length(cluster)) {
	if (missing(robust)) robust <- TRUE
	tempc <- untangle.specials(Terms, 'cluster', 1:10)
	ord <- attr(Terms, 'order')[tempc$terms]
	if (any(ord>1)) stop ("Cluster can not be used in an interaction")
	cluster <- strata(m[,tempc$vars], shortlabel=TRUE)  #allow multiples
	dropx <- tempc$terms
	}
    if (length(strats)) {
	temp <- untangle.specials(Terms, 'strata', 1)
	dropx <- c(dropx, temp$terms)
	if (length(temp$vars)==1) strata.keep <- m[[temp$vars]]
	else strata.keep <- strata(m[,temp$vars], shortlabel=TRUE)
	strats <- as.numeric(strata.keep)
	}

    if (length(dropx)) {
	# I need to keep the intercept in the model when creating the
	#   model matrix (so factors generate correct columns), then
	#   remove it.
	newTerms <- Terms[-dropx]
	X <- model.matrix(newTerms, m)
	}
    else {
	newTerms <- Terms
	X <- model.matrix(Terms, m)
	}

    # Attributes of X need to be saved away before the X <- X[,-1] line removes the
    #  intercept, since subscripting removes some of them!
    if (is.R()) {
	 assign <- lapply(attrassign(X, newTerms)[-1], function(x) x-1)
         xlevels <- .getXlevels(newTerms, m)
         contr.save <- attr(X, 'contrasts')
         }
    else {
        assign <- lapply(attr(X, 'assign')[-1], function(x) x -1)
        xvars <- as.character(attr(newTerms, 'variables'))
        xvars <- xvars[-attr(newTerms, 'response')]
        if (length(xvars) >0) {
                xlevels <- lapply(m[xvars], levels)
                xlevels <- xlevels[!unlist(lapply(xlevels, is.null))]
                if(length(xlevels) == 0)
                        xlevels <- NULL
                }
        else xlevels <- NULL
        contr.save <- attr(X, 'contrasts')
        }
        
    X <- X[,-1, drop=F]  #remove the intercept column

    type <- attr(Y, "type")
    if (type!='right' && type!='counting')
	stop(paste("Cox model doesn't support \"", type,
			  "\" survival data", sep=''))
    if (missing(init)) init <- NULL

    # Check for penalized terms
    pterms <- sapply(m, inherits, 'coxph.penalty')
    if (any(pterms)) {
	pattr <- lapply(m[pterms], attributes)
	# 
	# the 'order' attribute has the same components as 'term.labels'
	#   pterms always has 1 more (response), sometimes 2 (offset)
	# drop the extra parts from pterms
	temp <- c(attr(Terms, 'response'), attr(Terms, 'offset'))
	if (length(dropx)) temp <- c(temp, dropx+1)
	pterms <- pterms[-temp]
	temp <- match((names(pterms))[pterms], attr(Terms, 'term.labels'))
	ord <- attr(Terms, 'order')[temp]
	if (any(ord>1)) stop ('Penalty terms cannot be in an interaction')
	pcols <- assign[pterms]  
  
        fit <- coxpenal.fit(X, Y, strats, offset, init=init,
				control,
				weights=weights, method=method,
				row.names(m), pcols, pattr, assign)
	}
    else {
	if( method=="breslow" || method =="efron") {
	    if (type== 'right')  fitter <- get("coxph.fit")
	    else                 fitter <- get("agreg.fit")
	    }
	else if (method=='exact') fitter <- get("agexact.fit")
	else stop(paste ("Unknown method", method))

	fit <- fitter(X, Y, strats, offset, init, control, weights=weights,
			    method=method, row.names(m))
	}

    if (is.character(fit)) {
	fit <- list(fail=fit)
	if (is.R()) class(fit) <- 'coxph'
	else oldClass(fit) <- 'coxph'
	}
    else {
	if (!is.null(fit$coefficients) && any(is.na(fit$coefficients))) {
	   vars <- (1:length(fit$coefficients))[is.na(fit$coefficients)]
	   msg <-paste("X matrix deemed to be singular; variable",
			   paste(vars, collapse=" "))
	   if (singular.ok) warning(msg)
	   else             stop(msg)
	   }
	fit$n <- nrow(Y)
	fit$terms <- Terms
	fit$assign <- assign
        if (is.R()) class(fit) <- fit$method	
        else       oldClass(fit) <-  fit$method[1]
	if (robust) {
	    fit$naive.var <- fit$var
	    fit$method    <- method
	    # a little sneaky here: by calling resid before adding the
	    #   na.action method, I avoid having missings re-inserted
	    # I also make sure that it doesn't have to reconstruct X and Y
	    fit2 <- c(fit, list(x=X, y=Y, weights=weights))
	    if (length(strats)) fit2$strata <- strata.keep
	    if (length(cluster)) {
		temp <- residuals.coxph(fit2, type='dfbeta', collapse=cluster,
					  weighted=TRUE)
		# get score for null model
		if (is.null(init))
			fit2$linear.predictors <- 0*fit$linear.predictors
		else fit2$linear.predictors <- c(X %*% init)
		temp0 <- residuals.coxph(fit2, type='score', collapse=cluster,
					 weighted=TRUE)
		}
	    else {
		temp <- residuals.coxph(fit2, type='dfbeta', weighted=TRUE)
		fit2$linear.predictors <- 0*fit$linear.predictors
		temp0 <- residuals.coxph(fit2, type='score', weighted=TRUE)
	        }
	    fit$var <- t(temp) %*% temp
	    u <- apply(as.matrix(temp0), 2, sum)
	    fit$rscore <- coxph.wtest(t(temp0)%*%temp0, u, control$toler.chol)$test
	    }
	#Wald test
	if (length(fit$coefficients) && is.null(fit$wald.test)) {  
	    #not for intercept only models, or if test is already done
	    nabeta <- !is.na(fit$coefficients)
	    # The init vector might be longer than the betas, for a sparse term
	    if (is.null(init)) temp <- fit$coefficients[nabeta]
	    else temp <- (fit$coefficients - 
			  init[1:length(fit$coefficients)])[nabeta]
	    fit$wald.test <-  coxph.wtest(fit$var[nabeta,nabeta], temp,
					  control$toler.chol)$test
	    }
	na.action <- attr(m, "na.action")
	if (length(na.action)) fit$na.action <- na.action
	if (model) fit$model <- m
	if (x)  {
	    fit$x <- X
	    if (length(strats)) fit$strata <- strata.keep
	    }
	if (y)     fit$y <- Y
	}	
    if (!is.null(weights) && any(weights!=1)) fit$weights <- weights

    fit$formula <- formula(Terms)
    if (length(xlevels) >0) fit$xlevels <- xlevels
    fit$contrasts <- contr.save
    if (any(offset !=0)) fit$offset <- offset
    fit$call <- Call
    fit$method <- method
    fit
    }
