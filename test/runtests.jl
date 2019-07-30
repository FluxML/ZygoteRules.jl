using ZygoteRules, Test

foo(x) = 2x
@adjoint foo(x) = 3x, ȳ -> (3,)

# using Zygote

# @test gradient(foo, x) == (3,)
