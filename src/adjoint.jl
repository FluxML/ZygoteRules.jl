using MacroTools
using MacroTools: @q, combinedef
using ChainRulesCore: AbstractZero, AbstractThunk, @non_differentiable

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
    $gradtuple(::Tuple{Vararg{Nothing}}) = nothing
    $gradtuple(x::Nothing) = nothing
    $gradtuple(x) = error("Gradient $x should be a tuple")
  end
end

abstract type AContext end
function adjoint end
function _pullback end
function pullback end
function unthunk_tangent end

function gradm(ex, mut = false, keepthunks = false)
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
  maybe_unthunked_Δ = keepthunks ? :Δ : :(unthunk_tangent(Δ))
  quote
    $adj
    @inline function ZygoteRules._pullback($cx, $f::$T, $(args...)) where $(Ts...)
      y, _back = adjoint(__context__, $f, $(argnames...))
      $(mut ? nothing : quote
        back(::Nothing) = nothing
        back(Δ::AbstractZero) = $gradtuple(ntuple(_ -> Δ, $(length(args))))
      end)
      back(Δ) = $gradtuple(_back($maybe_unthunked_Δ))
      return y, back
    end
    @inline function ZygoteRules._pullback($cx, ::$kT, kw, $f::$T, $(args...)) where $(Ts...)
      y, _back = adjoint(__context__, $f, $(argnames...); kw...)
      $(mut ? nothing : quote
        back(::Nothing) = nothing
        back(Δ::AbstractZero) = $gradtuplekw(ntuple(_ -> Δ, $(length(args))))
      end)
      back(Δ) = $gradtuplekw(_back($maybe_unthunked_Δ))
      return y, back
    end
    nothing
  end
end

macro adjoint(ex)
  gradm(ex, false, false)
end

macro adjoint!(ex)
  gradm(ex, true, false)
end
