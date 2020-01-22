library(dplyr)

arg_cor_func <- c("pearson", "spearman", "bicor")
arg_network_type = c("unsigned", "signed", "signed hybrid")
fake_mat <-  runif(n = 10*45, max = 100) %>%  matrix(ncol = 45)
fake_cor_mat <- cor(fake_mat)
df_expr <- list(df_microarray = kuehne_expr[, 5000:7000],
                df_rnaseq = gtex_expr[, 5000:7000])


# ==== .cor_func_match ====

test_that("badly formatted cor_func throw an error", {
  # cor_func should be one of the string allowed to design the correlation function
  lapply(arg_cor_func, function(arg){
    expect_error(.cor_func_match(cor_func = arg), NA)
    expect_error(.cor_func_match(cor_func = 42))
    expect_error(.cor_func_match(cor_func = "this is not a function available"))
  })
})
test_that("output format is ok", {
  # Return a data.frame
  lapply(arg_cor_func, function(arg) {
    expect_true(is.function(.cor_func_match(cor_func = arg)))
  })
})


# ==== .check_data_expr ====

test_that("Rightly formated data_expr throw no error", {
  expect_error(.check_data_expr(data_expr = df_expr$df_microarray), NA)
  expect_error(.check_data_expr(data_expr = df_expr$df_microarray %>% as.matrix), NA)
})
test_that("data_expr should be either a matrix or data frame", {
  expect_error(.check_data_expr(data_expr = 42))
  expect_error(.check_data_expr(data_expr = 1:42))
  expect_error(.check_data_expr(data_expr = "this is not a data.frame nor a matrix"))
  expect_error(.check_data_expr(data_expr = list("this is not a data.frame nor a matrix", "this shouldn't work")))
})
test_that("data_expr should have values >= 0", {
  expect_error(.check_data_expr(data_expr = cbind(df_expr$df_rnaseq, -10:(nrow(df_expr$df_rnaseq) - 11))))
})
test_that("data_expr should have genes as columns and samples as rows", {
  expect_warning(.check_data_expr(data_expr = df_expr$df_microarray %>% t))
})


# ==== get_fit.cor ====

test_that("cor_mat should be a matrix of correlations", {
  # expect_error(get_fit.cor(cor_mat = cor(df_expr$df_microarray)), NA) # dopar warning
  # Type is matrix
  expect_error(get_fit.cor(cor_mat = 42))
  expect_error(get_fit.cor(cor_mat = "this is not a correlation matrix"))
  expect_error(get_fit.cor(cor_mat = fake_cor_mat %>% as.data.frame()))
  # Is a squared matrix
  expect_error(get_fit.cor(cor_mat = fake_cor_mat[, -1]))
  # Values in [0;1]
  expect_error(get_fit.cor(cor_mat = cbind(fake_cor_mat[, -1], 1:nrow(fake_cor_mat))))
  # Contains no NA (need to be checked with a symetric matrix)
  fake_cor_mat_na <- fake_cor_mat
  fake_cor_mat_na[c(2,4), c(2,4)] <- NA
  expect_warning(get_fit.cor(cor_mat = fake_cor_mat_na))
})
test_that("fit_cut_off should be a number in ]0;1[", {
  expect_error(get_fit.cor(cor_mat = fake_cor_mat, fit_cut_off = -1))
  expect_error(get_fit.cor(cor_mat = fake_cor_mat, fit_cut_off = 42))
  expect_error(get_fit.cor(cor_mat = fake_cor_mat, fit_cut_off = c(0.1, 0.5, 0.9)))
  expect_error(get_fit.cor(cor_mat = fake_cor_mat, fit_cut_off = "this is not a numeric value"))
})
test_that("network_type should be one of the string allowed to design the correlation function", {
  lapply(arg_network_type, function(arg){
    # expect_error(get_fit.cor(cor_mat = cor(df_expr$df_microarray), network_type = arg), NA)
    expect_error(get_fit.cor(cor_mat = cor(df_expr$df_microarray), network_type = 42))
    expect_error(get_fit.cor(cor_mat = cor(df_expr$df_microarray), network_type = "this is not a network available"))
  })
})
test_that("random data cannot be fit by a power law (no scale-free property)", {
  expect_warning(get_fit.cor(cor_mat = fake_cor_mat), "No fitting power could be found")
})
test_that("output format is ok", {
  # Return a list with expected elements formated correctly
  res <- get_fit.cor(cor_mat = cor(df_expr$df_microarray))
  expect_true(is.list(res))
  expect_true(all(names(res) == c("power_value", "fit_table", "fit_above_cut_off", "metadata")))
  expect_true(all(names(res$metadata) == c("network_type")))
  expect_true(is.numeric(res$power_value) && length(res$power_value) == 1)
  expect_true(is.data.frame(res$fit_table) && colnames(res$fit_table) == c("Power", "SFT.R.sq", "slope", "truncated.R.sq", "mean.k.", "median.k.", "max.k."))
})


# ==== get_fit.expr ====

test_that("data_expr should be a data.frame or a matrix of values >= 0", {
  expect_error(get_fit.expr(data_expr = cbind(df_expr$df_rnaseq, -10:(nrow(df_expr$df_rnaseq) - 11))))
})
test_that("data_expr should be either a matrix or data frame of intensities or counts", {
  expect_error(get_fit.expr(data_expr = df_expr$df_microarray), NA)
  expect_error(get_fit.expr(data_expr = df_expr$df_microarray %>% as.matrix), NA)
  expect_error(get_fit.expr(data_expr = "this is not a data.frame nor a matrix"))
  expect_error(get_fit.expr(data_expr = list("this is not a data.frame nor a matrix", "this shouldn't work")))
  expect_warning(get_fit.expr(data_expr = df_expr$df_microarray %>% t))
})
test_that("your_func is checked to returns correlation values ([-1;1])", {
  fake_bad_func <- function(df) { matrix(sample(-10:10, nrow(df)*ncol(df), replace = TRUE), ncol = ncol(df)) }
  lapply(df_expr, function(df) {
    expect_error(get_fit.expr(data_expr = df, cor_func = "other", your_func = fake_bad_func))
  })
})
test_that("output format is ok", {
  res <- get_fit.expr(data_expr = df_expr$df_microarray)
  expect_true(is.list(res))
  expect_true(all(names(res) == c("power_value", "fit_table", "fit_above_cut_off", "metadata")))
  expect_true(all(names(res$metadata) == c("network_type", "cor_func")))
  expect_true(is.numeric(res$power_value) && length(res$power_value) == 1)
  expect_true(is.data.frame(res$fit_table) && colnames(res$fit_table) == c("Power", "SFT.R.sq", "slope", "truncated.R.sq", "mean.k.", "median.k.", "max.k."))
})


# ==== build_net ====

res_net <- build_net(data_expr = df_expr$df_microarray)
test_that("genes interactions strength is in [0;1]", {
  expect_gte(min(res_net$network %>% c), 0)
  expect_lte(max(res_net$network %>% c), 1)
})
test_that("output format is ok", {
  expect_true(is.list(res_net))
  expect_true(all(names(res_net) == c("network", "metadata")))
  expect_true(all(names(res_net$metadata) == c("cor_func", "network_type", "tom_type", "power", "fit_power_table")))
})

# ==== detect_modules ====

test_that("net is a matrix or data.frame", {
  expect_error(detect_modules(df_expr$df_microarray, 42))
  expect_error(detect_modules(df_expr$df_microarray, "this is not a data.frame or matrix"))
  expect_error(detect_modules(df_expr$df_microarray, 1:42))
  expect_error(detect_modules(df_expr$df_microarray, list("this is not a data.frame", "this is not a matrix")))
})
test_that("net should be squarred", {
  expect_error(detect_modules(data_expr = df_expr$df_microarray, net = res_net$network[, -1]))
})
test_that("all colnames in rownames", {
  expect_error(detect_modules(data_expr = df_expr$df_microarray, net = res_net$network[-1, -10]))
})
test_that("output format is ok (detailled)", {
  res_modules <- detect_modules(data_expr = df_expr$df_microarray, net = res_net$network)
  expect_true(all(names(res_modules) == c("modules", "modules_premerge", "modules_eigengenes", "dendrograms")))
  expect_true(is.vector(res_modules$modules, "numeric"))
  expect_true(is.vector(res_modules$modules_premerge, "numeric"))
  expect_true(is.data.frame(res_modules$modules_eigengenes) && ncol(res_modules$modules_eigengenes) == length(table(res_modules$modules)))
  expect_true(class(res_modules$dendrograms) == "hclust")
})
test_that("output format is ok (not detailled)", {
  res_modules <- detect_modules(data_expr = df_expr$df_microarray, net = res_net$network, detailled_result = FALSE)
  expect_true(all(names(res_modules) == c("modules", "modules_eigengenes")))
  expect_true(is.vector(res_modules$modules, "numeric"))
  expect_true(is.data.frame(res_modules$modules_eigengenes) && ncol(res_modules$modules_eigengenes) == length(table(res_modules$modules)))
})