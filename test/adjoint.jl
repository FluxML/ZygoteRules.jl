@testset "legacy2differential" begin
    @test legacy2differential(nothing, Any) == Zero()
    @test legacy2differential(1, Any) == 1

    legacy = (nothing, 1, nothing)
    differential = Composite{typeof(legacy)}(Zero(), 1, Zero())
    @test legacy2differential(tuple(legacy), tuple(typeof(legacy))) == tuple(differential)

    legacy = (a=nothing, b=1, c=nothing)
    differential = Composite{typeof(legacy)}(a=Zero(), b=1, c=Zero())
    @test legacy2differential(tuple(legacy), tuple(typeof(legacy))) == tuple(differential)

    struct Foo
        a
        b
    end
    legacy = (a=1, b=nothing)
    differential = Composite{Foo}(a=1, b=Zero())
    @test legacy2differential(tuple(legacy), tuple(typeof(legacy))) == tuple(differential) # make this work and try as kwargs
    @test legacy2differential(tuple(legacy), tuple(Foo)) == tuple(differential)
end