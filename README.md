

The function `demean` is a basic implementation of the function `demean` in the [lfe R package](http://journal.r-project.org/archive/2013-2/gaure.pdf). It allows to estimate models with multiple high dimentional fixed effects.

The function `demean` accepts a dataframe, a set of columns to demean (an array of symbols), and a set of grouping variables (an array of an array of symbols). It returns a new data.frame with the demeaned version of columns.

For instance, the following command returns the residuals of the regression of Sales on State dummies and Year dummies.

```julia
using DataFrames
using RDatasets

df = dataset("plm", "Cigar")
result = FixedEffects.demean(df, :Sales, Vector{Symbol}[[:State],[:Year]])
```


If the dataframe contains missing values, new rows are set to missing

```julia
df[1:5, :Sales] = NA
result = FixedEffects.demean(df, [:Sales], Vector{Symbol}[[:State],[:Year]])
```


# Comparison

Julia
```julia
N = 1000000
K = 10000
df = DataFrame(
  v1 =  rand(1:N, N),
  v2 =  rand(1:K, N),
  v3 =  randn(N), 
  v4 =  randn(N) 
)
@time FixedEffects.demean(df, [:v3,:v4], Vector{Symbol}[[:v1]])
# elapsed time: 0.666773452 seconds (272412128 bytes allocated, 4.19% gc time)

@time FixedEffects.demean(df, [:v3,:v4], Vector{Symbol}[[:v1],[:v2]])
# elapsed time: 2.579359049 seconds (888593920 bytes allocated, 16.27% gc time)
```

R (lfe package, C)

```R
library(lfe)
N = 1000000
K = N/100
df = data_frame(
  v1 =  sample(N, N, replace = TRUE),
  v2 =  sample(K, N, replace = TRUE),
  v3 =  runif(N), 
  v4 =  runif(N) 
)
system.time(felm(v3+v4~1|v1, df))
#  user  system elapsed 
# 3.909   0.117   4.009 
system.time(felm(v3+v4~1|v1+v2, df))
#  user  system elapsed 
# 5.009   0.147   4.583 
```
