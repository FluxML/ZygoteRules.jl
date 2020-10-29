@testset "legacy2differential" begin
    @test legacy2differential(nothing, Any) == Zero()
    @test legacy2differential(1, Any) == 1

    @testset "gradient of a tuple" begin
        legacy = (nothing, 1, nothing)
        differential = Composite{typeof(legacy)}(Zero(), 1, Zero())
        @test legacy2differential(tuple(legacy), recursive_typeof(tuple(legacy))) == tuple(differential)
    end

    @testset "gradient of a named tuple" begin
        legacy = (a=nothing, b=1, c=nothing)
        differential = Composite{typeof(legacy)}(a=Zero(), b=1, c=Zero())
        @test legacy2differential(tuple(legacy), recursive_typeof(tuple(legacy))) == tuple(differential)
    end

    struct Foo
        a
        b
    end

    @testset "gradient of a struct" begin
        legacy = (a=1, b=nothing)
        differential = Composite{Foo}(a=1, b=Zero())
        @test legacy2differential(tuple(legacy), recursive_typeof(tuple(legacy))) == tuple(differential) # this should fail once ChainRules newer version is used
        @test legacy2differential(tuple(legacy), tuple(Foo)) == tuple(differential)
    end

    struct Bar
        x
        y::Foo
    end

    @testset "gradient of a nested struct" begin
        f = Foo(1, 2)
        b = Bar(3, f)
        legacy = (x=nothing, y=(a=1, b=nothing))
        differential = Composite{Bar}(x=Zero(), y=Composite{Foo}(a=1, b=Zero()))
        @test legacy2differential(tuple(legacy), tuple(Bar)) == tuple(differential)
    end

    @testset "gradient of an array" begin
        dfoo = (a=1, b=nothing)
        legacy = [dfoo, 1, nothing]
        differential = [Composite{typeof(dfoo)}(a=1, b=Zero()), 1, Zero()]
        @test legacy2differential(legacy, recursive_typeof(legacy)) == differential
    end

    @testset "gradient of an array in a tuple" begin
        dfoo = (a=1, b=nothing)
        legacy = [dfoo, 1, nothing]
        differential = [Composite{typeof(dfoo)}(a=1, b=Zero()), 1, Zero()]
        @test legacy2differential(tuple(legacy), recursive_typeof(tuple(legacy))) == tuple(differential)
    end
    
    @testset "gradient of an array" begin
        dfoo = [(a=1, b=nothing), nothing]
        legacy = [dfoo, 1, nothing]
        differential = [[Composite{typeof(dfoo)}(a=1, b=Zero()), Zero()], 1, Zero()]
        @test legacy2differential(legacy, recursive_typeof(legacy)) == differential
    end
end