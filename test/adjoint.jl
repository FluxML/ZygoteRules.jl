struct Foo
    a
    b
end

struct Bar
    x
    y::Foo
end

recursive_typeof(a) = typeof(a)
recursive_typeof(a::Union{AbstractArray, Tuple}) = recursive_typeof.(a)
recursive_typeof(a::AbstractArray{<:Number}) = typeof(a)

@testset "differential2legacy" begin
    @test differential2legacy(Zero()) == nothing
    @test differential2legacy(1) == 1

    @testset "tuple of gradients" begin
        legacy = (1, 2, nothing, nothing)
        differential = (1, 2, Zero(), DoesNotExist())
        @test differential2legacy(differential) == legacy
    end

    @testset "gradient of a tuple" begin
        legacy = (nothing, 1, nothing)
        differential = Composite{typeof(legacy)}(Zero(), 1, Zero())
        @test differential2legacy(tuple(differential)) == tuple(legacy)
    end

    @testset "gradient of a named tuple" begin
        legacy = (a=nothing, b=1, c=nothing)    
        differential = Composite{typeof(legacy)}(a=Zero(), b=1, c=Zero())
        @test differential2legacy(differential) == legacy
    end

    @testset "gradient of a struct" begin
        legacy = (a=1, b=nothing)
        differential = Composite{Foo}(a=1, b=Zero())
        @test differential2legacy(differential) == legacy
    end
    
    @testset "incomplete gradient of a struct" begin
        legacy = (a=1, b=nothing)
        differential = Composite{Foo}(a=1,)
        @test differential2legacy(differential) == legacy
    end

    @testset "gradient of a nested struct" begin
        f = Foo(1, 2)
        b = Bar(3, f)
        legacy = (x=nothing, y=(a=1, b=nothing))
        differential = Composite{Bar}(x=Zero(), y=Composite{Foo}(a=1, b=Zero()))
        @test differential2legacy(differential) == legacy
    end

    @testset "gradient of an array" begin
        dfoo = (a=1, b=nothing)
        legacy = [dfoo, 1, nothing]
        differential = [Composite{typeof(dfoo)}(a=1, b=Zero()), 1, Zero()]
        @test differential2legacy(differential) == legacy
    end

    @testset "gradient of an array in a tuple" begin
        dfoo = (a=1, b=nothing)
        legacy = [dfoo, 1, nothing]
        differential = [Composite{typeof(dfoo)}(a=1, b=Zero()), 1, Zero()]
        @test differential2legacy(tuple(differential)) == tuple(legacy)
    end
    
    @testset "gradient of an array with an array element" begin
        dfoo = (a=1, b=nothing)
        legacy = [[dfoo, nothing], 1, nothing]
        differential = [[Composite{typeof(dfoo)}(a=1, b=Zero()), Zero()], 1, Zero()]
        @test differential2legacy(differential) == legacy
    end

    @testset "tuple of a tuple of array" begin
        ta = ([0.3 0.2; 0.1 2.0],)
        legacy = (ta, nothing)
        differential = (Composite{typeof(ta)}([0.3 0.2; 0.1 2.0],), Zero())
        @test differential2legacy(differential) == legacy
    end

    @testset "triple nested tuple" begin
        legacy = (((nothing, 1),),)
        differential = (Composite{Tuple{Composite{Tuple{Zero,Int64},Tuple{Zero,Int64}}}}(Composite{Tuple{Zero,Int64}}(Zero(), 1),),)
        @test differential2legacy(differential) == legacy
    end
end

@testset "legacy2differential" begin
    @test legacy2differential(nothing, Any) == Zero()
    @test legacy2differential(1, Any) == 1

    @testset "tuple of gradients" begin
        legacy = (1, 2, nothing, nothing)
        differential = (1, 2, Zero(), Zero())
        @test legacy2differential(legacy, legacy) == differential
    end

    @testset "gradient of a tuple" begin
        legacy = (nothing, 1, nothing)
        differential = Composite{typeof(legacy)}(Zero(), 1, Zero())
        @test legacy2differential(tuple(legacy), tuple(legacy)) == tuple(differential)
    end

    @testset "gradient of a named tuple" begin
        legacy = (a=nothing, b=1, c=nothing)
        differential = Composite{typeof(legacy)}(a=Zero(), b=1, c=Zero())
        @test legacy2differential(tuple(legacy), tuple(legacy)) == tuple(differential)
    end

    @testset "gradient of a struct" begin
        legacy = (a=1, b=nothing)
        differential = Composite{Foo}(a=1, b=Zero())
        @test legacy2differential(tuple(legacy), tuple(Foo(1, 2))) == tuple(differential)
    end

    @testset "incomplete gradient of a struct" begin
        legacy = (a=1,)
        differential = Composite{Foo}(a=1, b=Zero())
        @test legacy2differential(tuple(legacy), tuple(Foo(1, 2))) == tuple(differential)
    end

    @testset "gradient of a nested struct" begin
        f = Foo(1, 2)
        b = Bar(3, f)
        legacy = (x=nothing, y=(a=1, b=nothing))
        differential = Composite{Bar}(x=Zero(), y=Composite{Foo}(a=1, b=Zero()))
        @test legacy2differential(tuple(legacy), tuple(b)) == tuple(differential)
    end

    @testset "gradient of an array" begin
        dfoo = (a=1, b=nothing)
        legacy = [dfoo, 1, nothing]
        differential = [Composite{typeof(dfoo)}(a=1, b=Zero()), 1, Zero()]
        @test legacy2differential(legacy, legacy) == differential
    end

    @testset "gradient of an array in a tuple" begin
        dfoo = (a=1, b=nothing)
        legacy = [dfoo, 1, nothing]
        differential = [Composite{typeof(dfoo)}(a=1, b=Zero()), 1, Zero()]
        @test legacy2differential(tuple(legacy), tuple(legacy)) == tuple(differential)
    end
    
    @testset "gradient of an array with an array element" begin
        dfoo = [(a=1, b=nothing), nothing]
        legacy = [dfoo, 1, nothing]
        differential = [[Composite{typeof(dfoo)}(a=1, b=Zero()), Zero()], 1, Zero()]
        @test legacy2differential(legacy, legacy) == differential
    end

    @testset "tuple of a tuple of array" begin
        ta = ([0.3 0.2; 0.1 2.0],)
        legacy = (ta, nothing)
        differential = (Composite{typeof(ta)}([0.3 0.2; 0.1 2.0],), Zero())
        @test legacy2differential(legacy, legacy) == differential
    end

    @testset "triple nested tuple" begin
        legacy = (((nothing, 1),),)
        differential = (
            Composite{
                Tuple{Composite{Tuple{Zero,Int64},Tuple{Zero,Int64}}}
            }(
                Composite{Tuple{Zero,Int64}}(Zero(), 1),
            ),
        )
        @test legacy2differential(legacy, legacy) == differential
    end
end