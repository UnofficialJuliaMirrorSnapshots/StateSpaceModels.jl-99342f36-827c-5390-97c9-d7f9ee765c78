export size, ztr

"""
    size(model::StateSpaceModel)

Return the dimensions `n`, `p`, `m` and `r` of the `StateSpaceModel`
"""
function size(model::StateSpaceModel)
    return model.dim.n, model.dim.p, model.dim.m, model.dim.r
end

"""
    ztr(model::StateSpaceModel)

Return the state space model arrays `Z`, `T` and `R` of the `StateSpaceModel`
"""
function ztr(model::StateSpaceModel)
    return model.Z, model.T, model.R
end


# Linar Algebra wrappers
function gram_in_time(mat::Array{Float64, 3})
    gram_in_time = similar(mat)
    for t = 1:size(gram_in_time, 3)
        gram_in_time[:, :, t] = gram(mat[:, :, t])
    end
    return gram_in_time
end

function gram(mat::Matrix{T}) where T <: AbstractFloat
    return mat*mat'    
end

"""
    check_steady_state(P_t1::Matrix{T}, P_t::Matrix{T}, tol::T) where T <: AbstractFloat

Return `true` if steady state was attained with respect to tolerance `tol`, `false` otherwise
"""
function check_steady_state(P_t1::Matrix{T}, P_t::Matrix{T}, tol::T) where T <: AbstractFloat
    return maximum(abs.((P_t1 - P_t)./P_t1)) < tol ? true : false
end