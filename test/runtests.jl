using ZygoteRules
using ZygoteRules: legacy2differential, differential2legacy
using ChainRulesCore
using Test

foo(x) = 2x
@adjoint foo(x) = 3x, ȳ -> (3,)

# using Zygote

# @test gradient(foo, x) == (3,)
@testset "ZygoteRules" begin
  include("adjoint.jl")
end