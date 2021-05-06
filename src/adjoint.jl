using MacroTools
using MacroTools: @q, combinedef

function named(arg)
  if isexpr(arg, :(::)) && length(arg.args) == 1
    :($(gensym())::$(arg.args[1]))
  elseif isexpr(arg, :kw)
    @assert length(arg.args) == 2
    decl, default = arg.args
    Expr(:kw, named(decl), default)
  else
    arg
  end
end

typeless(x) = MacroTools.postwalk(x -> isexpr(x, :(::), :kw) ? x.args[1] : x, x)
isvararg(x) = isexpr(x, :(::)) && namify(x.args[2]) == :Vararg

for n = 0:3
  gradtuple = Symbol(:gradtuple, n)
  @eval begin
    $gradtuple(x::Tuple) = ($(ntuple(_->:nothing,n)...), x...)
    $gradtuple(x::Nothing) = nothing
    $gradtuple(x) = error("Gradient $x should be a tuple")
  end
end

abstract type AContext end
function adjoint end
function _pullback end
function pullback end

function gradm(ex, mut = false)
  @capture(shortdef(ex), (name_(args__) = body_) |
                         (name_(args__) where {Ts__} = body_)) || error("Need a function definition")
  kw = length(args) > 1 && isexpr(args[1], :parameters) ? esc(popfirst!(args)) : nothing
  isclosure = isexpr(name, :(::)) && length(name.args) > 1
  f, T = isexpr(name, :(::)) ?
    (length(name.args) == 1 ? (esc(gensym()), esc(name.args[1])) : esc.(name.args)) :
    (esc(gensym()), :(Core.Typeof($(esc(name)))))
  kT = :(Core.kwftype($T))
  Ts == nothing && (Ts = [])
  args = named.(args)
  argnames = Any[typeless(arg) for arg in args]
  !isempty(args) && isvararg(args[end]) && (argnames[end] = :($(argnames[end])...,))
  args = esc.(args)
  argnames = esc.(argnames)
  Ts = esc.(Ts)
  cx = :($(esc(:__context__))::AContext)
  fargs = kw == nothing ? [cx, :($f::$T), args...] : [kw, cx, :($f::$T), args...]
  gradtuple   = isclosure ? gradtuple0 : gradtuple1
  gradtuplekw = isclosure ? gradtuple2 : gradtuple3
  adj = @q @inline ZygoteRules.adjoint($(fargs...)) where $(Ts...) = $(esc(body))
  quote
    $adj
    @inline function ZygoteRules._pullback($cx, $f::$T, $(args...)) where $(Ts...)
      argTs = map(typeof, ($(argnames...),))
      y, _back = adjoint(__context__, $f, $(argnames...))
      $(mut ? nothing : :(back(::Nothing) = nothing))
      back(Δ) = $gradtuple($clamptype(argTs, _back(Δ)))
      return y, back
    end
    @inline function ZygoteRules._pullback($cx, ::$kT, kw, $f::$T, $(args...)) where $(Ts...)
      argTs = map(typeof, ($(argnames...),))
      y, _back = adjoint(__context__, $f, $(argnames...); kw...)
      $(mut ? nothing : :(back(::Nothing) = nothing))
      back(Δ) = $gradtuplekw($clamptype(argTs, _back(Δ)))
      return y, back
    end
    nothing
  end
end

macro adjoint(ex)
  gradm(ex)
end

macro adjoint!(ex)
  gradm(ex, true)
end

clamptype(T, dx) = dx
clamptype(Ts::Tuple{Vararg{<:Type,N}}, dxs::Tuple{Vararg{Any,N}}) where {N} = map(clamptype, Ts, dxs)

function clamptype(Ts::Tuple, dx::Tuple)
  if length(Ts)>1 && first(Ts) == GlobalRef
    clamptype(Base.tail(Ts), dx)
  else
    @info "mismatched lengths" Ts dx
    dx
  end
end

#=



using Zygote, LinearAlgebra

# using ZygoteRules
# ENV["JULIA_DEBUG"] = "all"

# Complex

gradient(x -> abs2(x+im), 0.2)     # was (0.4 + 2.0im,)
gradient(x -> abs2(x+im), 0.2+0im) # old & new agree

gradient(x -> abs2(sum(x .+ im)), [0.1, 0.2])    # uses array rule, makes a Fill
gradient(x -> abs2(sum(x .+ im)), Any[0.1, 0.2]) # uses scalar rule, makes an Array

# Bool

gradient(sqrt, true)
gradient(x -> sum(sqrt, x), rand(3) .> 0.5) # uses scalar rule
gradient(x -> sum(sqrt.(x .+ 10)), rand(3) .> 0.5)  # uses array rule

# LinearAlgebra

gradient(x -> sum(sqrt.(x .+ 10)), Diagonal(rand(3)))[1]

gradient(x -> x[1,2], Symmetric(ones(3,3)))[1]           # Symmetric
gradient(x -> x[1,2] + x[2,1], Symmetric(ones(3,3)))[1]  # twice that

sy1 = gradient(x -> sum(x .+ 1), Symmetric(ones(3,3)))[1] # Symmetric
sy2 = gradient(x -> sum(x * x'), Symmetric(ones(3,3)))[1] # tries but fails

ud = gradient((x,y) -> sum(x * y), UpperTriangular(ones(3,3)), Diagonal(ones(3,3)));
ud[1] # works, UpperTriangular
ud[2] # fails to preserve Diagonal

@eval Zygote begin  # crudely apply this also to ChainRules rules:
  using ZygoteRules: clamptype
  @inline function chain_rrule(f, args...)
    y, back = rrule(f, args...)
    ctype = (Nothing, map(typeof, args)...)
    return y, (b -> clamptype(ctype, b))∘ZBack(back)
  end
end

# now ud[2] works, sy2 still fails.

Zygote.pullback(x -> x.+1, rand(3)')[2](ones(1,3))[1]   # simplest adjoint(vec(dx))
Zygote.pullback(x -> x.+1, rand(ComplexF64, 3)')[2](ones(1,3))[1]
Zygote.pullback(x -> x.+1, rand(ComplexF64, 3)')[2](fill(0+im, 1,3))[1]  # uses transpose

=#

