library(survival)
aeq <- function(x, y, ...) all.equal(as.vector(x), as.vector(y), ...)

# Check that estimates from a multi-state model agree with single state models
#  Use a simplified version of the myeloid data set
tdata <- tmerge(myeloid[,1:3], myeloid, id=id, death=event(futime,death),
                priortx = tdc(txtime), sct= event(txtime))
tdata$event <- factor(with(tdata, sct + 2*death), 0:2,
                      c("censor", "sct", "death"))
fit <- coxph(Surv(tstart, tstop, event) ~ trt + sex, tdata, id=id,
             iter=4, x=TRUE)

fit12 <- coxph(Surv(tstart, tstop, event=='sct') ~ trt + sex, tdata,
               subset=(priortx==0), iter=4, x=TRUE)
fit13 <- coxph(Surv(tstart, tstop, event=='death') ~ trt + sex, tdata,
               subset=(priortx==0), iter=4, x=TRUE)
fit23 <- coxph(Surv(tstart, tstop, event=='death') ~ trt + sex, tdata,
               subset=(priortx==1), iter=4, x=TRUE)
aeq(coef(fit), c(coef(fit12), coef(fit13), coef(fit23))) 
aeq(fit$loglik, fit12$loglik + fit13$loglik + fit23$loglik)
temp <- matrix(0, 6,6)
temp[1:2, 1:2] <- fit12$var
temp[3:4, 3:4] <- fit13$var
temp[5:6, 5:6] <- fit23$var
aeq(fit$var, temp)

ii <- fit$strata==1
tfit <- coxph(fit$y[ii,] ~ fit$x[ii,])
aeq(tfit$loglik, fit12$loglik)   # check that x, y, strata are correct
ii <- fit$strata==2
tfit <- coxph(fit$y[ii,] ~ fit$x[ii,])
aeq(tfit$loglik, fit13$loglik)   # check that x, y, strata are correct
ii <- fit$strata==3
tfit <- coxph(fit$y[ii,] ~ fit$x[ii,])
aeq(tfit$loglik, fit23$loglik)   # check that x, y, strata are correct

# check out model.frame
fita <- coxph(Surv(tstart, tstop, event) ~ trt, tdata, id=id)
fitb <- coxph(Surv(tstart, tstop, event) ~ trt, tdata, id=id, model=TRUE)
all.equal(model.frame(fita), fitb$model)

#check residuals
aeq(residuals(fit), c(residuals(fit12), residuals(fit13), residuals(fit23)))
aeq(residuals(fit, type='deviance'),
    c(residuals(fit12, type='deviance'), residuals(fit13, type='deviance'),
      residuals(fit23, type='deviance')))

# score residuals
indx1 <- 1:fit12$n
indx2 <- 1:fit13$n + fit12$n
indx3 <- 1:fit23$n + (fit12$n + fit13$n)
temp <- residuals(fit, type='score')
aeq(temp[indx1, 1:2], residuals(fit12, type='score'))
aeq(temp[indx2, 3:4], residuals(fit13, type='score'))
aeq(temp[indx3, 5:6], residuals(fit23, type='score'))

all(temp[indx1, 3:6] ==0)
all(temp[indx2, c(1,2,5,6)] ==0)
all(temp[indx3, 1:4]==0)

temp <- residuals(fit, type="dfbeta")
all(temp[indx1, 3:6] ==0)
all(temp[indx2, c(1,2,5,6)] ==0)
all(temp[indx3, 1:4]==0)
aeq(temp[indx1, 1:2], residuals(fit12, type='dfbeta'))
aeq(temp[indx2, 3:4], residuals(fit13, type='dfbeta'))
aeq(temp[indx3, 5:6], residuals(fit23, type='dfbeta'))

temp <- residuals(fit, type="dfbetas")
all(temp[indx1, 3:6] ==0)
all(temp[indx2, c(1,2,5,6)] ==0)
all(temp[indx3, 1:4]==0)
aeq(temp[indx1, 1:2], residuals(fit12, type='dfbetas'))
aeq(temp[indx2, 3:4], residuals(fit13, type='dfbetas'))
aeq(temp[indx3, 5:6], residuals(fit23, type='dfbetas'))

# Schoenfeld and scaled shoenfeld have one row per event
ecount <- table(fit$strata[fit$y[,3]==1])
temp <- rep(1:3, ecount)
sindx1 <- which(temp==1)
sindx2 <- which(temp==2)
sindx3 <- which(temp==3)
temp <- residuals(fit, type="schoenfeld")
all(temp[sindx1, 3:6] ==0)
all(temp[sindx2, c(1,2,5,6)] ==0)
all(temp[sindx3, 1:4]==0)
aeq(temp[sindx1, 1:2], residuals(fit12, type='schoenfeld'))
aeq(temp[sindx2, 3:4], residuals(fit13, type='schoenfeld'))
aeq(temp[sindx3, 5:6], residuals(fit23, type='schoenfeld'))


#The scaled Schoenfeld don't agree, due to the use of a robust
#  variance in fit, regular variance in fit12, fit13 and fit23
#Along with being scaled by different event counts
xfit <- fit
xfit$var <- xfit$naive.var
if (FALSE) {
    xfit <- fit
    xfit$var <- xfit$naive.var  # fixes the first issue
    temp <- residuals(xfit, type="scaledsch")
    aeq(d1* temp[sindx1, 1:2], residuals(fit12, type='scaledsch'))
    aeq(temp[sindx2, 3:4], residuals(fit13, type='scaledsch'))
    aeq(temp[sindx3, 5:6], residuals(fit23, type='scaledsch'))
}


# predicted values differ because of different centering
c0 <-  sum(fit$mean * coef(fit))
c12 <- sum(fit12$mean * coef(fit12))
c13 <- sum(fit13$mean* coef(fit13))
c23 <- sum(fit23$mean * coef(fit23))

aeq(predict(fit)+c0, c(predict(fit12)+c12, predict(fit13)+c13, 
                       predict(fit23)+c23))
aeq(exp(predict(fit)), predict(fit, type='risk'))

# expected survival is independent of centering
aeq(predict(fit, type="expected"), c(predict(fit12, type="expected"),
                                     predict(fit13, type="expected"),
                                     predict(fit23, type="expected")))

# predict(type='terms') is a matrix, centering changes as well
temp <- predict(fit, type='terms')
if (FALSE) {
    all(temp[indx1, 3:6] ==0)
    all(temp[indx2, c(1,2,5,6)] ==0)
    all(temp[indx3, 1:4]==0)
    aeq(temp[indx1, 1:2], predict(fit12, type='terms'))
    aeq(temp[indx2, 3:4], predict(fit13, type='terms'))
    aeq(temp[indx3, 5:6], predict(fit23, type='terms'))
}

# The global and per strata zph tests will differ for the KM or rank
#  transform, because the overall and subset will have a different list
#  of event times, which changes the transformed value for all of them.
# But identity and log are testable.
test_a <- cox.zph(fit, transform="log",global=FALSE)
test_a12 <- cox.zph(fit12, transform="log",global=FALSE)
test_a13 <- cox.zph(fit13, transform="log", global=FALSE)
test_a23 <-  cox.zph(fit23, transform="log", global=FALSE)
aeq(test_a$y[test_a$strata==1, 1:2], test_a12$y)

aeq(test_a$table[1:2,], test_a12$table)
aeq(test_a$table[3:4,], test_a13$table)
aeq(test_a$table[5:6,], test_a23$table)

# check cox.zph fit - transform = 'identity'
test_b <- cox.zph(fit, transform="identity",global=FALSE)
test_b12 <- cox.zph(fit12, transform="identity",global=FALSE)
test_b13 <- cox.zph(fit13, transform="identity", global=FALSE)
test_b23 <-  cox.zph(fit23, transform="identity", global=FALSE)

aeq(test_b$table[1:2,], test_b12$table)
aeq(test_b$table[3:4,], test_b13$table)
aeq(test_b$table[5:6,], test_b23$table)

# check out subscripting of a multi-state zph
cname <- c("table", "x", "time", "y", "var")
sapply(cname, function(x) aeq(test_b[1:2]$x, test_b12$x))
sapply(cname, function(x) aeq(test_b[3:4]$x, test_b13$x))
sapply(cname, function(x) aeq(test_b[5:6]$x, test_b23$x))

# check model.matrix
mat1 <- model.matrix(fit)
mat2 <- model.matrix(fit12)
mat3 <- model.matrix(fit13)
mat4 <- model.matrix(fit23)

test.matrix1 <- matrix(0, nrow=dim(mat2),ncol=2,dimnames=c())
test.matrix2 <- matrix(0, nrow=dim(mat3),ncol=2,dimnames=c())
test.matrix3 <- matrix(0, nrow=dim(mat4),ncol=2,dimnames=c())

com1 <- cbind(mat2,test.matrix1, test.matrix1)
com2 <- cbind(test.matrix2, mat3, test.matrix2)
com3 <- cbind(test.matrix3, test.matrix3, mat4)
combined.matrix <- do.call(rbind,list(com1,com2,com3)) #create combined matrix to compare to model matrix from 'fit' model

final <- rbind(com1,com2,com3)

aeq(mat1,combined.matrix) #GOOD

