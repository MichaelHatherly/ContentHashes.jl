import ContentHashes
const C = ContentHashes

using Test

@testset "ContentHashes.jl" begin
    struct T{S}
        x::S
    end
    @testset "primatives" begin
        @test C.hash(1) === C.hash(1)
        @test C.hash("string"^10) === C.hash("string"^10)
        @test C.hash([]) === C.hash([])
        @test C.hash(()) === C.hash(())
        @test C.hash(Dict(1 => 2, 2 => 1)) === C.hash(Dict(2 => 1, 1 => 2))
        @test C.hash(Matrix{Any}(undef, 5, 5)) === C.hash(Matrix{Any}(undef, 5, 5))
        @test C.hash(ntuple(n -> T(undef), 50)) === C.hash(ntuple(n -> T(undef), 50))

        @test C.hash(1, 1) === C.hash(1, 1)
        @test C.hash(1, 1) !== C.hash(1, 2)
    end
    @testset "anonymous functions" begin
        f = x -> T(@fastmath sin(x[1:5] + 1 / 2))
        g = x -> T(@fastmath sin(x[1:5] + 1 / 2))

        @test hash(f) !== hash(g)
        @test C.hash(f) === C.hash(g)
    end
    @testset "circular references" begin
        a = []
        push!(a, a)
        b = []
        push!(b, b)
        @test C.hash(a) === C.hash(b)

        push!(a, a)
        push!(b, b)
        @test C.hash(a) === C.hash(b)
        push!(a, T(Ref([])))
        push!(b, T(Ref([])))
        @test C.hash(a) === C.hash(b)

        push!(a[1], a)
        push!(b[1], b)
        @test C.hash(a) === C.hash(b)
    end
end

