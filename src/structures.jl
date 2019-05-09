"""Structure with state space dimensions"""
struct StateSpaceDimensions
    n::Int
    p::Int
    m::Int
    r::Int
    p_exp::Int
end

"""Structure with state space matrices and data"""
struct StateSpaceSystem
    y::Array{Float64, 2} # observations
    X::Array{Float64, 2} # exogenous variables
    s::Int # seasonality
    Z::Vector{Array{Float64, 2}} # observation matrix
    T::Array{Float64, 2} # state matrix
    R::Array{Float64, 2} # state error matrix
end

"""Structure with state space hyperparameters"""
mutable struct StateSpaceParameters
    sqrtH::Array{Float64, 2} # lower triangular matrix with sqrt-covariance of the observation
    sqrtQ::Array{Float64, 2} # lower triangular matrix with sqrt-covariance of the state
end

"""Structure with smoothed state"""
struct SmoothedState
    trend::Array{Float64, 2} # smoothed trend
    slope::Array{Float64, 2} # smoothed slope
    seasonal::Array{Float64, 2} # smoothed seasonality
    exogenous::Vector{Array{Float64, 2}} # smoothed regression of exogenous variables
    V::Vector{Array{Float64, 2}} # variance of smoothed state
    alpha::Vector{Array{Float64, 2}} # smoothed state matrix
end

"""Structure with Kalman filter output"""
mutable struct FilterOutput
    a::Vector{Array{Float64, 2}} # predictive state
    v::Vector{Array{Float64, 2}} # innovations
    steadystate::Bool # flag that indicates if steady state was attained
    tsteady::Int # instant when steady state was attained
    Ksteady::Array{Float64, 2}
    U2star::Vector{Array{Float64, 2}}
    sqrtP::Vector{Array{Float64, 2}} # lower triangular matrix with sqrt-covariance of the predictive state
    sqrtF::Vector{Array{Float64, 2}} # lower triangular matrix with sqrt-covariance of the innovations
    sqrtPsteady::Array{Float64, 2}
end

"""General output structure for the user"""
struct StateSpace
    sys::StateSpaceSystem
    dim::StateSpaceDimensions
    state::SmoothedState
    param::StateSpaceParameters
    filter::FilterOutput
end
