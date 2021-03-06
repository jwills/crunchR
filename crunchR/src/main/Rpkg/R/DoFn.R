
#' DoFn$initialize method
#' 
#' @param FUN_PROCESS the process method, R-serialized into raw
#' @param FUN_INITIALIZE optional initialize R function
#' @param FUN_CLEANUP optional cleanup R function
DoFn.initialize <- function ( FUN_PROCESS, FUN_INITIALIZE=NULL, FUN_CLEANUP=NULL,
		customizeEnv=F) {
	doFnRef <<- 0
	
	# prep call environment
	femit <- function(...) .self$rpipe$emit(...,doFn=.self)
	
	fcustEnv <- function(f) {
		if ( customizeEnv ) { 
			fenv <- new.env(parent=environment(f))
			fenv$emit<-femit
			environment(f)<-fenv
		} 
		f
	}
	
	stopifnot (!is.null(FUN_PROCESS))
	FUN_PROCESS <<- fcustEnv(FUN_PROCESS)
	if (!is.null(FUN_INITIALIZE)) FUN_INITIALIZE <<- fcustEnv(FUN_INITIALIZE)
	if (!is.null(FUN_CLEANUP)) FUN_CLEANUP <<- fcustEnv(FUN_CLEANUP)
	
	srtype <<- crunchR.RString$new()
	trtype <<- crunchR.RStrings$new()
	
}

DoFn.getSRType <- function () srtype

DoFn.getTRType <- function () trtype

DoFnRType.set <- function (value ) {
	stopifnot (is(value,crunchR.DoFn$className))
	
	doFn <- value 
	
	fnRef <- .setVarUint32(doFn$doFnRef)
	
	closures <- RRaw.set(serialize( list (doFn$FUN_PROCESS,doFn$FUN_INITIALIZE,doFn$FUN_CLEANUP),
					connection=NULL)); 
	
	rTypeState <- RTypeStateRType.set(doFn$srtype$getState())
	tTypeState <- RTypeStateRType.set(doFn$trtype$getState())
	
	# in R2Java serialization, we also attach java class names 
	# so that RType can be properly instantiated.
	c(fnRef, closures, rTypeState, tTypeState)
	
}

DoFnRType.get <- function (rawbuff,offset=1 ) {
	
	fnRef <- .getVarUint32(rawbuff,offset)
	offset <- offset + fnRef[2]
	
	closures <- RRaw.get(rawbuff,offset)
	offset <- closures$offset
	closures <- unserialize(closures$value)
	
	sTypeState <- RTypeStateRType.get(rawbuff,offset)
	offset <- sTypeState$offset
	sTypeState <- sTypeState$value
	
	tTypeState <- RTypeStateRType.get(rawbuff,offset)
	offset <- tTypeState$offset
	tTypeState <- tTypeState$value
	
	doFn <- crunchR.DoFn$new(closures[[1]],closures[[2]],
			closures[[3]],customizeEnv=T)
	doFn$doFnRef <- fnRef[1]
	doFn$rpipe <- rpipe
	
	# RType classes must have default constructor for generic DoFn'ss
	doFn$srtype <- getRefClass(sTypeState$rClassName)$new()
	doFn$srtype$setState(sTypeState)
	
	doFn$trtype <- getRefClass(tTypeState$rClassName)$new()
	doFn$trtype$setState(tTypeState)
	
	list(value=doFn,offset=offset)
}

DoFnRType.initialize <- function (rpipe) {
	rpipe <<- rpipe
}


