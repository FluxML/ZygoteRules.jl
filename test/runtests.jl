using ZygoteRules, Test
using ZygoteRules: typeless, named

foo(x) = 2x
@adjoint foo(x) = 3x, ȳ -> (3,)

# using Zygote

# @test gradient(foo, x) == (3,)

"""
Extract the first parameter declaration from a function definition

This macro is necessary because the same syntax is parsed differently if it is part of a
parameter list, see the first test.
"""
macro param(def)
  @assert def.head == :function
  head = def.args[1]
  call = head.head == :where ? head.args[1] : head
  QuoteNode(call.args[2])
end

@testset "Test utilities" begin
  @test @param(function f(a::Int = 5) end) != :(a::Int = 5)

  @test @param(function f(x) end) == :(x)
  @test @param(function f(a::Int = 5) end) == Expr(:kw, :(a::Int), 5)
end

@testset "Macro utilities" begin
  @testset "extracting parameter names" begin
    @test typeless(@param function f(x) end) == :x
    @test typeless(@param function f(b::Float64 = π) end) == :b
  end

  @testset "naming anonymous parameters" begin
    @test typeless(named(@param function f(w) end)) == :w
    @test typeless(named(@param function f(σ::Float32 = 1.0) end)) == :σ

    @test typeless(named(@param function f(::Int) end)) isa Symbol
    @test typeless(named(@param function f(::Type{Val{x}}) where {x} end)) isa Symbol
  end
end
