@testset "legacy2differential" begin
    @test legacy2differential(nothing, Any) == Zero()
    @test legacy2differential(1, Any) == 1

    # test gradient of a tuple
    legacy = (nothing, 1, nothing)
    differential = Composite{typeof(legacy)}(Zero(), 1, Zero())
    @test legacy2differential(tuple(legacy), typeof.(tuple(legacy))) == tuple(differential)

    # test gradient of a named tuple
    legacy = (a=nothing, b=1, c=nothing)
    differential = Composite{typeof(legacy)}(a=Zero(), b=1, c=Zero())
    @test legacy2differential(tuple(legacy), typeof.(tuple(legacy))) == tuple(differential)

    # test gradient of a struct
    struct Foo
        a
        b
    end
    legacy = (a=1, b=nothing)
    differential = Composite{Foo}(a=1, b=Zero())
    @test legacy2differential(tuple(legacy), typeof.(tuple(legacy))) == tuple(differential) # this should fail once ChainRules newer version is used
    @test legacy2differential(tuple(legacy), tuple(Foo)) == tuple(differential)

    # test gradient of a nested struct
    struct Bar
        x
        y::Foo
    end
    f = Foo(1, 2)
    b = Bar(3, f)
    legacy = (x=nothing, y=(a=1, b=nothing))
    differential = Composite{Bar}(x=Zero(), y=Composite{Foo}(a=1, b=Zero()))
    @test legacy2differential(tuple(legacy), tuple(Bar)) == tuple(differential)
end