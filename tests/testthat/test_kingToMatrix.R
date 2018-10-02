context("kingToMatrix tests")

test_that("robust", {
	kinfile <- system.file("extdata", "MXL_ASW.kin", package="GENESIS")
	kin0file <- system.file("extdata", "MXL_ASW.kin0", package="GENESIS")
        kin <- read.table(kinfile, header=TRUE, as.is=TRUE)
        kin0 <- read.table(kin0file, header=TRUE, as.is=TRUE)
        samp <- unique(c(kin$ID1, kin$ID2, kin0$ID1, kin0$ID2))

	KINGmat <- kingToMatrix(file.king = c(kinfile, kin0file), verbose=FALSE)
        expect_true(setequal(rownames(KINGmat), samp))

        samp.include <- sample(samp, 100)
	KINGmat <- kingToMatrix(file.king = c(kinfile, kin0file), sample.include=samp.include, verbose=FALSE)
        expect_true(setequal(rownames(KINGmat), samp.include))
})

test_that("ibdseg", {
	kinfile <- system.file("extdata", "HapMap.seg", package="GENESIS")
        kin <- read.table(kinfile, header=TRUE, as.is=TRUE)
        samp <- unique(c(kin$ID1, kin$ID2))

	KINGmat <- kingToMatrix(file.king = kinfile, verbose=FALSE)
        expect_true(setequal(rownames(KINGmat), samp))
})

test_that("threshold", {
	kinfile <- system.file("extdata", "MXL_ASW.kin", package="GENESIS")
	kin0file <- system.file("extdata", "MXL_ASW.kin0", package="GENESIS")
        kin <- read.table(kinfile, header=TRUE, as.is=TRUE)
	KINGmat <- kingToMatrix(file.king = c(kinfile, kin0file), verbose=FALSE)
        rels <- sum(KINGmat > 0)
        
	KINGmat <- kingToMatrix(file.king = c(kinfile, kin0file), thresh=0.02, verbose=FALSE)
        rels2 <- sum(KINGmat > 0)
        expect_true(rels2 < rels)
})