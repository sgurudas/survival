# SCCS @(#)pspline.s	1.4 02/24/99
#
# the p-spline function for a Cox model
#
pspline <- function(x, df=4, theta, nterm=2.5*df, degree=3, eps=0.1, 
		    method, ...) {
    ##require(splines)
    if (!missing(theta)) {
	method <- 'fixed'
	if (theta <=0 || theta >=1) stop("Invalid value for theta")
	}
    else if (df ==0 || (!missing(method) && method=='aic')) {
	method <- 'aic'
	nterm <- 15    #will be ok for up to 6-8 df
	if (missing(eps)) eps <- 1e-5
	}
    else {
	method <- 'df'
	if (df <=1) stop ('Too few degrees of freedom')
	}

    xname <- deparse(substitute(x))
    keepx <- !is.na(x)
    rx <- range(x[keepx])
    nterm <- round(nterm)
    if (nterm < 3) stop("Too few basis functions")
    dx <- (rx[2] - rx[1])/nterm
    knots <- c(rx[1] + dx*((-degree):(nterm-1)), rx[2]+ dx*(0:degree))
    if (all(keepx)) newx <- spline.des(knots, x, degree+1)$design
    else {
	temp <- spline.des(knots, x[keepx], degree+1)$design
	newx <- matrix(NA, length(x), ncol(temp))
	newx[keepx,] <- temp
        }
    newx <- newx[,-1]              #redundant coefficient with lambda_0
    class(newx) <- 'coxph.penalty'
    nvar <- 1 + ncol(newx)   #should be nterm + degree
    dmat <- diag(nvar)
    dmat <- apply(dmat, 2, diff, 1, 2) 
    dmat <- t(dmat) %*% dmat
    dmat <- dmat[-1,-1]                  # rows corresponding to the 0 coef
    xnames <-paste('ps(', xname, ')', 2:nvar, sep='')

    pfun <- function(coef, theta, n, dmat) {
	if (theta >=1) list(penalty= 100*(1-theta), flag=TRUE)
	else {
	    if (theta <= 0) lambda <- 0 
	    else lambda <- theta / (1-theta)
	    list(penalty= c(coef %*% dmat %*% coef) * lambda/2,
		 first  = c(dmat %*% coef) * lambda ,
		 second = c(dmat * lambda),
		 flag=FALSE
		 )
	    }
        }	

    printfun <- function(coef, var, var2, df, history) {
	test1 <- coxph.wtest(var, coef)$test
	# cbase contains the centers of the basis functions
	#   do a weighted regression of these on the coefs to get a slope
	xmat <- cbind(1, cbase)
	xsig <- coxph.wtest(var, xmat)$solve   # V X , where V = g-inverse(var)
	# [X' V X]^{-1} X' V
	cmat <- coxph.wtest(t(xmat)%*% xsig, t(xsig))$solve[2,]  
        linear <- sum(cmat * coef)
	lvar1  <- c(cmat %*% var %*% cmat)
	lvar2  <- c(cmat %*% var2%*% cmat)
	test2 <- linear^2 / lvar1
	# the "max(.5, df-1)" below stops silly (small) p-values for a
	#  chisq of 0 on 0 df, when using AIC gives theta near 1
	cmat <- rbind(c(linear, sqrt(lvar1), sqrt(lvar2), 
			test2, 1, 1-pchisq(test2, 1)),
		      c(NA, NA, NA, test1-test2, df-1, 
			1-pchisq(test1-test2, max(.5,df-1))))
	dimnames(cmat) <- list(c("linear", "nonlin"), NULL)
	nn <- nrow(history$thetas)
	if (length(nn)) theta <- history$thetas[nn,1]
	else  theta <- history$theta
	list(coef=cmat, history=paste("Theta=", format(theta)))
	}
    # Line 2 below is a real sneaky thing, see notes.
    ## We don't need to be sneaky. We have lexical scope :)
    ## printfun[[6]] <- knots[2:nvar] + (rx[1] - knots[1])
    cbase<-knots[2:nvar] + (rx[1] - knots[1])	       
    if (method=='fixed') {
	temp <- list(pfun=pfun,
		     printfun=printfun,
		     pparm=dmat,
		     diag =FALSE,
		     cparm=list(theta=theta),
		     varname=xnames,
		     cfun = function(parms, iter, old)
			         list(theta=parms$theta, done=TRUE))
	}
    else if (method=='df') {
	temp <- list(pfun=pfun,
		     printfun=printfun,
		     diag =FALSE,
		     cargs=('df'),
		     cparm=list(df=df, eps=eps, thetas=c(1,0),
		                dfs=c(1, nterm), guess=1 - df/nterm, ...),
		     pparm= dmat,
		     varname=xnames,
		     cfun = frailty.controldf)
	}

    else { # use AIC
	temp <- list(pfun=pfun,
		     printfun=printfun,
		     pparm=dmat,
		     diag =FALSE,
		     cargs = c('neff', 'df', 'plik'),
		     cparm=list(eps=eps, init=c(.5, .95), 
		                lower=0, upper=1, ...),
		     varname=xnames,
		     cfun = frailty.controlaic)
	}
    
    attributes(newx) <- c(attributes(newx), temp)
    newx
    }
