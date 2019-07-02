# Tests
@testset "Strutural model tests" begin
    @testset "Constant signal with basic structural model" begin
        y = ones(30)
        model = structural(y, 2)

        @test isa(model, StateSpaceModel)
        @test model.mode == "time-invariant"
        @test model.filter_type == KalmanFilter

        ss = statespace(model)

        @test isa(ss, StateSpace)

        @test all(ss.covariance.H .< 1e-6)
        @test all(ss.covariance.Q .< 1e-6)
    end

    @testset "Constant signal with exogenous variables" begin
        y = ones(15)
        X = randn(30, 2)

        model = structural(y, 2; X = X)

        @test isa(model, StateSpaceModel)
        @test model.mode == "time-variant"
        @test model.filter_type == KalmanFilter

        ss = statespace(model)

        @test isa(ss, StateSpace)
        @test all(ss.covariance.H .< 1e-6)
        @test all(ss.covariance.Q .< 1e-6)

        sim = simulate(ss, 10, 1000)
        pred = mean(sim[1, :, :], dims = 2)
        @test all(abs.(pred .- ones(10)) .< 1e-3)
    end

    @testset "Multivariate test" begin
       
        y = [ones(20) collect(1:20)]
        model = structural(y, 2)

        @test isa(model, StateSpaceModel)
        @test model.mode == "time-invariant"
        @test model.filter_type == KalmanFilter

        ss = statespace(model)
        sim  = simulate(ss, 10, 1000)

        @test mean(sim, dims = 3)[1, :] ≈ ones(10) rtol = 1e-3
        @test mean(sim, dims = 3)[2, :] ≈ collect(21:30) rtol = 1e-3
    end

    @testset "Error tests" begin
        y = ones(15, 1)
        @test_throws ErrorException structural(y, 2; X = ones(10, 2))

        Z = Array{Float64, 3}(undef, 1, 2, 20)
        for t = 1:20
            Z[:, :, t] = [1 0]
        end
        T = [1. 1; 0 1]
        R = [1. 0; 0 1]
        
        model = StateSpaceModel(y, Z, T, R)
        ss = statespace(model)
        @test_throws ErrorException sim  = simulate(ss, 10, 1000)
    end
end