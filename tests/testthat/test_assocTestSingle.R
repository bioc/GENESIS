context("single variant tests")
library(SeqVarTools)

BPPARAM <- BiocParallel::SerialParam()
#BPPARAM <- BiocParallel::MulticoreParam()

test_that("assocTestSingle", {
    svd <- .testData()
    iterator <- SeqVarBlockIterator(svd, variantBlock=500, verbose=FALSE)
    nullmod <- fitNullModel(iterator, outcome="outcome", covars=c("sex", "age"), verbose=FALSE)
    assoc <- assocTestSingle(iterator, nullmod, BPPARAM=BPPARAM, verbose=FALSE)
    seqResetFilter(svd, verbose=FALSE)
    freq <- alleleFrequency(svd)
    keep <- freq > 0 & freq < 1
    expect_equal(unique(assoc$variant.id), seqGetData(svd, "variant.id")[keep])
    seqClose(svd)
})

test_that("assocTestSingle - binary", {
    svd <- .testData()
    iterator <- SeqVarBlockIterator(svd, variantBlock=500, verbose=FALSE)
    nullmod <- fitNullModel(iterator, outcome="status", covars=c("sex", "age"), family="binomial", verbose=FALSE)
    assoc <- assocTestSingle(iterator, nullmod, BPPARAM=BPPARAM, verbose=FALSE)
    seqResetFilter(svd, verbose=FALSE)
    freq <- alleleFrequency(svd)
    keep <- freq > 0 & freq < 1
    expect_equal(unique(assoc$variant.id), seqGetData(svd, "variant.id")[keep])
    seqClose(svd)
})

test_that("assocTestSingle - SPA", {
    svd <- .testData()
    grm <- .testGRM(svd)
    iterator <- SeqVarBlockIterator(svd, variantBlock=500, verbose=FALSE)
    nullmod <- fitNullModel(iterator, outcome="status", covars=c("sex", "age"), cov.mat=grm, family="binomial", verbose=FALSE)
    assoc <- assocTestSingle(iterator, nullmod, test="Score", BPPARAM=BPPARAM, verbose=FALSE)
    resetIterator(iterator, verbose=FALSE)
    assoc2 <- assocTestSingle(iterator, nullmod, test="Score.SPA", BPPARAM=BPPARAM, verbose=FALSE)
    nospa <- is.na(assoc2$SPA.converged)
    expect_equal(assoc$Score.pval[nospa], assoc2$SPA.pval[nospa])
    expect_true(max(assoc$Score.pval - assoc2$SPA.pval) < 0.02)
    seqClose(svd)
})

test_that("assocTestSingle - sample selection", {
    svd <- .testData()
    grm <- .testGRM(svd)
    set.seed(50); samp <- sampleData(svd)$sample.id[sample(1:nrow(sampleData(svd)), 50)]
    iterator <- SeqVarBlockIterator(svd, variantBlock=500, verbose=FALSE)
    nullmod <- fitNullModel(iterator, outcome="outcome", covars=c("sex", "age"), cov.mat=grm, sample.id=samp, verbose=FALSE)
    expect_equal(nrow(nullmod$model.matrix), 50)
    assoc <- assocTestSingle(iterator, nullmod, BPPARAM=BPPARAM, verbose=FALSE)
    expect_equal(max(assoc$n.obs), 50)
    seqClose(svd)
})

test_that("assocTestSingle - reorder samples", {
    svd <- .testData()
    set.seed(51); samp <- sample(sampleData(svd)$sample.id, 50)
    grm <- .testGRM(svd)
    iterator <- SeqVarBlockIterator(svd, variantBlock=500, verbose=FALSE)
    nullmod <- fitNullModel(iterator, outcome="outcome", covars=c("sex", "age"), cov.mat=grm[samp,samp], sample.id=samp, verbose=FALSE)
    expect_equal(nrow(nullmod$model.matrix), 50)
    expect_equal(nullmod$fit$sample.id, samp)
    assoc <- assocTestSingle(iterator, nullmod, BPPARAM=BPPARAM, verbose=FALSE)
    expect_equal(max(assoc$n.obs), 50)

    # check that we get same assoc results with samples in different order
    samp.sort <- sort(samp)
    nullmod2 <- fitNullModel(iterator, outcome="outcome", covars=c("sex", "age"), cov.mat=grm[samp.sort,samp.sort], sample.id=samp, verbose=FALSE)
    expect_equal(nullmod2$fit$sample.id, samp.sort)
    resetIterator(iterator, verbose=FALSE)
    assoc2 <- assocTestSingle(iterator, nullmod2, BPPARAM=BPPARAM, verbose=FALSE)
    # this test may not be reliable - see test_nullModel.R
    expect_equal(assoc, assoc2)
    #expect_equal(assoc[,1:6], assoc2[,1:6])

    seqClose(svd)
})


## test the lines of code that reorder the genotypes
test_that("reorder genotypes", {
    svd <- .testData()
    grm <- .testGRM(svd)
    set.seed(52); samp <- sample(sampleData(svd)$sample.id, 50)
    nullmod <- fitNullModel(svd, outcome="outcome", covars=c("sex", "age"), cov.mat=grm[samp,samp], sample.id=samp, verbose=FALSE)
    sample.index <- .setFilterNullModel(svd, nullmod, verbose=FALSE)
    geno <- expandedAltDosage(svd, use.names=TRUE, sparse=TRUE)[sample.index,,drop=FALSE]
    expect_equal(rownames(geno), samp)

    seqClose(svd)
})


test_that("assocTestSingle matches regression", {
    svd <- .testData()

    # multiallelic variants are handled differently
    snv <- isSNV(svd, biallelic=TRUE)
    seqSetFilter(svd, variant.sel=snv, verbose=FALSE)
    assoc1 <- regression(svd, outcome="outcome", covar=c("sex", "age"))
    assoc1 <- assoc1[assoc1$freq > 0 & assoc1$freq < 1,]

    nullmod <- fitNullModel(svd, outcome="outcome", covars=c("sex", "age"), verbose=FALSE)
    iterator <- SeqVarBlockIterator(svd, verbose=FALSE)
    assoc2 <- assocTestSingle(iterator, nullmod, BPPARAM=BPPARAM, verbose=FALSE)
    expect_equal(nrow(assoc1), nrow(assoc2))
    expect_equal(assoc1$variant.id, assoc2$variant.id)
    expect_equal(assoc1$n, assoc2$n.obs)
    expect_equal(assoc1$freq, 1-assoc2$freq)
    ## this won't match exactly, because missing data is handled differently
    ## assocTestSingle imputes to the mean, while regression drops missing data
    #expect_equal(assoc1$Est, -assoc2$Est)
    #expect_equal(assoc1$SE, assoc2$Est.SE)
    #expect_equal(assoc1$Wald.Stat, (assoc2$Wald.Stat)^2)
    #expect_equal(assoc1$Wald.Pval, assoc2$Wald.pval, tolerance=.1)

    seqClose(svd)
})

test_that("assocTestSingle - GxE", {
    svd <- .testData()
    tmp <- sampleData(svd)
    set.seed(54); tmp$env <- sample(letters[1:3], nrow(tmp), replace=TRUE)
    sampleData(svd) <- tmp
    iterator <- SeqVarBlockIterator(svd, variantBlock=1000, verbose=FALSE)
    nullmod <- fitNullModel(iterator, outcome="outcome", covars=c("sex", "age", "env"), verbose=FALSE)
    assoc <- assocTestSingle(iterator, nullmod, GxE="env", BPPARAM=BPPARAM, verbose=FALSE)
    expect_true(all(c("Est.G:envb", "SE.G:envb", "GxE.Stat") %in% names(assoc)))

    # multiple E vars
    resetIterator(iterator, verbose=FALSE)
    assoc <- assocTestSingle(iterator, nullmod, GxE=c("env", "sex"), BPPARAM=BPPARAM, verbose=FALSE)
    expect_true(all(c("Est.G:sexM", "SE.G:sexM", "Est.G:envb", "SE.G:envb", "GxE.Stat") %in% names(assoc)))
    seqClose(svd)
})

test_that("missing sample.id in null model", {
    svd <- .testData()
    seqSetFilterChrom(svd, include=1, verbose=FALSE)
    n <- 10
    seqSetFilter(svd, sample.sel=1:n, verbose=FALSE)
    iterator <- SeqVarBlockIterator(svd, verbose=FALSE)
    nullmod <- fitNullModel(pData(sampleData(svd)), outcome="outcome", covars=c("sex", "age"), verbose=FALSE)
    expect_false("sample.id" %in% names(nullmod$fit))
    expect_equal(length(nullmod$fit$outcome), n)
    assoc <- assocTestSingle(iterator, nullmod, BPPARAM=BPPARAM, verbose=FALSE)
    expect_equal(max(assoc$n.obs), n)
    seqClose(svd)
})

test_that("extra samples in null model", {
    svd <- .testData()

    # AnnotatedDataFrame
    samp <- sampleData(svd)
    sampx <- AnnotatedDataFrame(rbind(pData(samp),
                   data.frame(sample.id="x", sex="M", age=30, outcome=10, status=0)))
    nullmod <- fitNullModel(sampx, outcome="outcome", covars=c("sex", "age"), verbose=FALSE)

    seqSetFilterChrom(svd, include=1, verbose=FALSE)
    iterator <- SeqVarBlockIterator(svd, verbose=FALSE)
    expect_error(assocTestSingle(iterator, nullmod, BPPARAM=BPPARAM, verbose=FALSE),
                 "Some samples in null.model not present in gdsobj")

    # data.frame
    resetIterator(iterator, verbose=FALSE)
    nullmod <- fitNullModel(pData(sampx), outcome="outcome", covars=c("sex", "age"), verbose=FALSE)
    expect_error(assocTestSingle(iterator, nullmod, BPPARAM=BPPARAM, verbose=FALSE),
                 "Some samples in null.model not present in gdsobj")

    seqClose(svd)
})

test_that("BinomiRare", {
    svd <- .testData()
    iterator <- SeqVarBlockIterator(svd, verbose=FALSE)
    nullmod <- fitNullModel(iterator, outcome="status", family="binomial", verbose=FALSE)
    assoc <- assocTestSingle(iterator, nullmod, test="BinomiRare", BPPARAM=BPPARAM, verbose=FALSE)
    expect_true(all(assoc$freq <= 0.5))
    seqClose(svd)
})

test_that("dominant", {
    svd <- .testData()
    iterator <- SeqVarBlockIterator(svd, verbose=FALSE)
    nullmod <- fitNullModel(iterator, outcome="outcome", covars=c("sex", "age"), verbose=FALSE)
    assoc <- assocTestSingle(iterator, nullmod, geno.coding="dominant", BPPARAM=BPPARAM, verbose=FALSE)
    expect_true("n.any.eff" %in% names(assoc))
    seqClose(svd)
})
