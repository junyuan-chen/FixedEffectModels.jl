
AbstractFloatMatrix{T<:AbstractFloat} =  AbstractMatrix{T}


mutable struct ModelMatrix{T <: AbstractFloatMatrix}
    m::T
    assign::Vector{Int}
end

Base.size(mm::ModelMatrix) = size(mm.m)
Base.size(mm::ModelMatrix, dim...) = size(mm.m, dim...)



## construct model matrix columns from model frame + name (checks for contrasts)
function modelmat_cols(::Type{T}, name::Symbol, mf::ModelFrame; non_redundant::Bool = false) where T<:AbstractFloatMatrix
    if haskey(mf.contrasts, name)
        modelmat_cols(T, mf.df[!, name],
                      non_redundant ?
                      convert(ContrastsMatrix{FullDummyCoding}, mf.contrasts[name]) :
                      mf.contrasts[name])
    else
        modelmat_cols(T, mf.df[!, name])
    end
end

modelmat_cols(::Type{T}, v::AbstractVector{<:Union{Missing, Real}}) where {T<:AbstractFloatMatrix} =
    convert(T, reshape(v, length(v), 1))
# Categorical column, does not make sense to convert to float
modelmat_cols(::Type{T}, v::AbstractVector) where {T<:AbstractFloatMatrix} =
    modelmat_cols(T, reshape(v, length(v), 1))

# All non-real columns are considered as categorical
# Could be made more efficient by directly storing the result into the model matrix
modelmat_cols(::Type{T}, v::AbstractVector, contrast::ContrastsMatrix) where {T<:AbstractFloatMatrix} =
    modelmat_cols(T, categorical(v), contrast)


function modelmat_cols(::Type{T},
                       v::AbstractCategoricalVector,
                       contrast::ContrastsMatrix) where T<:AbstractFloatMatrix
    ## make sure the levels of the contrast matrix and the categorical data
    ## are the same by constructing a re-indexing vector. Indexing into
    ## reindex with v.refs will give the corresponding row number of the
    ## contrast matrix
    reindex = indexin(CategoricalArrays.index(v.pool), contrast.levels)
    contrastmatrix = convert(T, contrast.matrix)
    return indexrows(contrastmatrix, convert(Vector{Int}, reindex[v.refs]))
end

indexrows(m::AbstractMatrix, ind::AbstractVector{Int}) = m[ind, :]


function expandcols(trm::Vector{T}) where T<:AbstractFloatMatrix
    if length(trm) == 1
        trm[1]
    else
        a = trm[1]
        b = expandcols(trm[2 : end])
        reduce(hcat, [broadcast(*, a, view(b, :, j)) for j in 1 : size(b, 2)])
    end
end


function droprandomeffects(trms::Terms)
    retrms = Bool[Meta.isexpr(t, :call) && t.args[1] == :| for t in trms.terms]
    if !any(retrms)  # return trms unchanged
        trms
    elseif all(retrms) && !trms.response   # return an empty Terms object
        Terms(Any[],Any[],zeros(Bool,0,0),zeros(Bool,0,0), Int[], false, trms.intercept)
    else
        # the rows of `trms.factors` correspond to `eterms`, the columns to `terms`
        # After dropping random-effects terms we drop any eterms whose rows are all false
        ckeep = .!retrms                 # columns to retain
        facs = trms.factors[:, ckeep]
        rkeep = vec(sum(facs, dims=2) .> 0)
        Terms(trms.terms[ckeep], trms.eterms[rkeep], facs[rkeep, :],
              trms.is_non_redundant[rkeep, ckeep],
              trms.order[ckeep], trms.response, trms.intercept)
    end
end


function dropresponse!(trms::Terms)
    if trms.response
        ckeep = 2:size(trms.factors, 2)
        rkeep = vec(any(trms.factors[:, ckeep], dims=2))
        Terms(trms.terms, trms.eterms[rkeep], trms.factors[rkeep, ckeep],
              trms.is_non_redundant[rkeep, ckeep], trms.order[ckeep], false, trms.intercept)
    else
        trms
    end
end


function ModelMatrix{T}(mf::ModelFrame) where T<:AbstractFloatMatrix
    dfrm = mf.df
    terms = droprandomeffects(dropresponse!(mf.terms))

    blocks = T[]
    assign = Int[]
    if terms.intercept
        push!(blocks, ones(size(dfrm, 1), 1))  # columns of 1's is first block
        push!(assign, 0)                       # this block corresponds to term zero
    end

    factors = terms.factors

    ## Map eval. term name + redundancy bool to cached model matrix columns
    eterm_cols = Dict{Tuple{Symbol,Bool}, T}()
    ## Accumulator for each term's vector of eval. term columns.

    ## TODO: this method makes multiple copies of the data in the ModelFrame:
    ## first in term_cols (1-2x per evaluation term, depending on redundancy),
    ## second in constructing the matrix itself.

    ## turn each term into a vector of mm columns for its eval. terms, using
    ## "promoted" full-rank versions of categorical columns for non-redundant
    ## eval. terms:
    for (i_term, term) in enumerate(terms.terms)
        term_cols = T[]
        ## Pull out the eval terms, and the non-redundancy flags for this term
        ff = view(factors, :, i_term)
        eterms = view(terms.eterms, ff)
        non_redundants = view(terms.is_non_redundant, ff, i_term)
        ## Get cols for each eval term (either previously generated, or generating
        ## and storing as necessary)
        for (et, nr) in zip(eterms, non_redundants)
            if ! haskey(eterm_cols, (et, nr))
                eterm_cols[(et, nr)] = modelmat_cols(T, et, mf, non_redundant=nr)
            end
            push!(term_cols, eterm_cols[(et, nr)])
        end
        push!(blocks, expandcols(term_cols))
        append!(assign, fill(i_term, size(blocks[end], 2)))
    end

    if isempty(blocks)
        error("Could not construct model matrix. Resulting matrix has 0 columns.")
    end

    I = size(dfrm, 1)
    J = mapreduce(x -> size(x, 2), +, blocks)
    X = similar(blocks[1], I, J)
    i = 1
    for block in blocks
        len = size(block, 2)
        X[:, i:(i + len - 1)] = block
        i += len
    end
    ModelMatrix{T}(X, assign)
end
ModelMatrix(mf::ModelFrame) = ModelMatrix{Matrix{Float64}}(mf)
