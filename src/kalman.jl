"""
    kalman_filter(model::StateSpaceModel, H::Matrix{Typ}, Q::Matrix{Typ}; tol::Float64 = 1e-5) where Typ <: AbstractFloat

Kalman filter with big Kappa initialization.
"""
function kalman_filter(model::StateSpaceModel, H::Matrix{Typ}, Q::Matrix{Typ}; tol::Typ = 1e-5) where Typ <: AbstractFloat

    # Load dimensions
    n, p, m, r = size(model)

    # Load system
    y = model.y
    Z, T, R = ztr(model)

    # Predictive state and its covariance
    a = Matrix{Float64}(undef, n+1, m)
    P = Array{Float64, 3}(undef, m, m, n+1)

    # Innovation and its covariance
    v = Matrix{Float64}(undef, n, p)
    F = Array{Float64, 3}(undef, p, p, n)

    # Kalman gain
    K = Array{Float64, 3}(undef, m, p, n)

    # Steady state initialization
    steadystate = false
    tsteady     = n+1

    # Initial state: big Kappa initialization
    a[1, :]    = zeros(m, 1)
    P[:, :, 1] = 1e6 .* Matrix(I, m, m)

    # Kalman filter
    for t = 1:n
        # Check for missing values
        if any(isnan.(y[t, :]))
            steadystate  = false
            v[t, :]      = NaN*ones(p)
            F[:, :, t]   = Z[:, :, t]*P[:, :, t]*Z[:, :, t]' + H
            K[:, :, t]   = T * P[:, :, t] * Z[:, :, t]' * inv(F[:, :, t])
            a[t+1, :]    = T*a[t, :]
            P[:, :, t+1] = ensure_pos_sym(T*P[:, :, t]*T' + R*Q*R')
        else
            v[t, :] = y[t, :] - Z[:, :, t] * a[t, :]
            if steadystate
                F[:, :, t]   = F[:, :, t-1]
                K[:, :, t]   = K[:, :, t-1]
                a[t+1, :]    = T * a[t, :] + K[:, :, t] * v[t, :]
                P[:, :, t+1] = P[:, :, t]
            else
                F[:, :, t]   = Z[:, :, t] * P[:, :, t] * Z[:, :, t]' + H
                K[:, :, t]   = T * P[:, :, t] * Z[:, :, t]' * inv(F[:, :, t])
                a[t+1, :]    = T * a[t, :] + K[:, :, t] * v[t, :]
                P[:, :, t+1] = ensure_pos_sym(T * P[:, :, t] * (T - K[:, :, t] * Z[:, :, t])' + R*Q*R')

                # Checking if steady state was attained
                if check_steady_state(P[:, :, t+1], P[:, :, t], tol)
                    steadystate = true
                    tsteady     = t
                end
            end
        end
    end

    # Return the auxiliary filter structre
    return KalmanFilter(a, v, P, F, steadystate, tsteady, K)
end

"""
    filtered_state(model::StateSpaceModel, kfilter::KalmanFilter)

Obtain the filtered state estimates and their covariance matrices.
"""
function filtered_state(model::StateSpaceModel, kfilter::KalmanFilter)

    # Load dimensions data
    n, p, m, r = size(model)

    # Load system data
    Z, T, R = ztr(model)

    # Load filter data
    a = kfilter.a
    v = kfilter.v
    F = kfilter.F
    P = kfilter.P

    # Filtered state and its covariance
    att = Matrix{Float64}(undef, n, m)
    Ptt = Array{Float64, 3}(undef, m, m, n)

    for t = 1:n
        PZF = P[:, :, t] * Z[:, :, t]' * inv(F[:, :, t])
        att[t, :]    = a[t, :] + PZF * v[t, :]
        Ptt[:, :, t] = ensure_pos_sym(P[:, :, t] - PZF * Z[:, :, t] * P[:, :, t])
    end

    return att, Ptt

end

"""
    smoother(model::StateSpaceModel, kfilter::KalmanFilter)

Smoother for state-space model.
"""
function smoother(model::StateSpaceModel, kfilter::KalmanFilter)

    # Load dimensions data
    n, p, m, r = size(model)

    # Load system data
    Z, T, R = ztr(model)

    # Load filter data
    a       = kfilter.a
    v       = kfilter.v
    tsteady = kfilter.tsteady
    F       = kfilter.F
    P       = kfilter.P
    K       = kfilter.K

    # Smoothed state and its covariance
    alpha = Matrix{Float64}(undef, n, m)
    V     = Array{Float64, 3}(undef, m, m, n)
    L     = Array{Float64, 3}(undef, m, m, n)
    r     = Matrix{Float64}(undef, n, m)
    N     = Array{Float64, 3}(undef, m, m, n)

    # Initialization
    N[:, :, end] = zeros(m, m)
    r[end, :]    = zeros(m, 1)
    Psteady      = P[:, :, end]
    Fsteady      = F[:, :, end]

    # Iterating backwards
    for t = n:-1:tsteady
        # Check for missing values
        if any(isnan.(v[t, :]))
            L[:, :, t]   = T
            r[t-1, :]    = L[:, :, t]' * r[t, :]
            N[:, :, t-1] = L[:, :, t]' * N[:, :, t] * L[:, :, t]
        else
            L[:, :, t]   = T - K[:, :, end] * Z[:, :, t]
            r[t-1, :]    = Z[:, :, t]' * inv(Fsteady) * v[t, :] + L[:, :, t]' * r[t, :]
            N[:, :, t-1] = Z[:, :, t]' * inv(Fsteady) * Z[:, :, t] + L[:, :, t]' * N[:, :, t] * L[:, :, t]
        end

        # Smoothed state and its covariance
        alpha[t, :] = a[t, :] + Psteady * r[t-1, :]
        V[:, :, t]  = Psteady - Psteady * N[:, :, t-1] * Psteady
    end

    for t = tsteady-1:-1:2
        if any(isnan.(v[t, :]))
            L[:, :, t]   = T
            r[t-1, :]    = L[:, :, t]' * r[t, :]
            N[:, :, t-1] = L[:, :, t]' * N[:, :, t] * L[:, :, t]
        else
            L[:, :, t]   = T - K[:, :, t] * Z[:, :, t]
            r[t-1, :]    = Z[:, :, t]' * inv(F[:, :, t]) * v[t, :] + L[:, :, t]' * r[t, :]
            N[:, :, t-1] = Z[:, :, t]' * inv(F[:, :, t]) * Z[:, :, t] + L[:, :, t]' * N[:, :, t] * L[:, :, t]
        end

        # Smoothed state and its covariance
        alpha[t, :]  = a[t, :] + P[:, :, t] * r[t-1, :]
        V[:, :, t]   = P[:, :, t] - (P[:, :, t] * N[:, :, t-1] * P[:, :, t])
    end

    if any(isnan.(v[1, :]))
        L[:, :, 1]  = T
        r_0         = L[:, :, 1]' * r[1, :]
        N_0         = L[:, :, 1]' * N[:, :, 1] * L[:, :, 1]
    else
        L[:, :, 1]  = T - K[:, :, 1] * Z[:, :, 1]
        r_0         = Z[:, :, 1]' * inv(F[:, :, 1]) * v[1, :] + L[:, :, 1]' * r[1, :]
        N_0         = Z[:, :, 1]' * inv(F[:, :, 1]) * Z[:, :, 1] + L[:, :, 1]' * N[:, :, 1] * L[:, :, 1]
    end

    alpha[1, :] = a[1, :] + P[:, :, 1] * r_0
    V[:, :, 1]  = P[:, :, 1] - (P[:, :, 1] * N_0 * P[:, :, 1])

    # Return the smoothed state structure
    return Smoother(alpha, V)
end

# All filters have to implement the following functions
# *
# *
# *

function statespace_covariance(psi::Vector{T}, p::Int, r::Int,
                               filter_type::Type{KalmanFilter}) where T <: AbstractFloat

    # Build lower triangular matrices
    if p > 1
        sqrtH     = tril!(ones(p, p))
        unknownsH = Int(p*(p + 1)/2)
        sqrtH[findall(isequal(1), sqrtH)] = psi[1:unknownsH]
    else
        sqrtH = psi[1].*ones(1, 1)
        unknownsH = 1
    end

    sqrtQ = kron(Matrix{Float64}(I, Int(r/p), Int(r/p)), tril!(ones(p, p)))
    sqrtQ[findall(x -> x == 1, sqrtQ)] = psi[(unknownsH+1):Int(unknownsH + (r/p)*(p*(p + 1)/2))]

    # Obtain full matrices
    H = gram(sqrtH)
    Q = gram(sqrtQ)

    return H, Q
end

function get_log_likelihood_params(psitilde::Vector{T}, model::StateSpaceModel,
                                   filter_type::Type{KalmanFilter}) where T <: AbstractFloat

    H, Q = statespace_covariance(psitilde, model.dim.p, model.dim.r, filter_type)

    # Obtain innovation v and its variance F
    kfilter = kalman_filter(model, H, Q)

    # Return v and F
    return kfilter.v, kfilter.F
end

function kalman_filter_and_smoother(model::StateSpaceModel, covariance::StateSpaceCovariance,
                                    filter_type::Type{KalmanFilter})

    # Run filter and smoother
    filter_output  = kalman_filter(model, covariance.H, covariance.Q)
    smoothed_state = smoother(model, filter_output)
    att, Ptt       = filtered_state(model, filter_output)

    return FilterOutput(filter_output.a[1:end-1, :], att, filter_output.v,
                        filter_output.P[:, :, 1:end-1], Ptt, filter_output.F,
                        filter_output.steadystate, filter_output.tsteady),
           SmoothedState(smoothed_state.alpha, smoothed_state.V)
end
