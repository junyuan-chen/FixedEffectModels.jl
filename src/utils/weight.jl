
##############################################################################
##
## Create light weight type
## 
##############################################################################

type Ones <: AbstractVector{Float64}
    length::Int
end
Base.size(O::Ones) = O.length
Base.getindex(::Ones, i::Int...) = one(Float64)
# Add in version 0.4 unsafe_getindex
Base.broadcast!{T}(::Function, ::Array{Float64, T}, ::Array{Float64, T}, ::Ones) = nothing
Base.scale!(::Vector{Float64}, ::Ones) = nothing


get_weight(df::AbstractDataFrame, weight::Symbol) = convert(Vector{Float64}, sqrt(df[weight]))
get_weight(df::AbstractDataFrame, ::Nothing) = Ones(size(df, 1))




