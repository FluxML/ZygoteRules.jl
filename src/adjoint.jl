using MacroTools
using MacroTools: @q, combinedef
using ChainRulesCore: AbstractZero, Zero, DoesNotExist, Composite, unthunk

named(arg) = isexpr(arg, :(::)) && length(arg.args) == 1 ? :($(gensym())::$(arg.args[1])) : arg

typeless(x) = MacroTools.postwalk(x -> isexpr(x, :(::), :kw) ? x.args[1] : x, x)
isvararg(x) = isexpr(x, :(::)) && namify(x.args[2]) == :Vararg

"""
    legacytype_warn()

Issue a warning that a ChainRules differential type was expected but a Zygote legacy type
was received. This is used to report bugs in transitioning to ChainRules types and can be
deleted once/if `@adjoint` macro is deprecated.
"""
function legacytype_warn()
  # can't use logging macros as that breaks nested AD.
  Core.println("""
    Zygote internal use of Nothing/Tuple/NamedTuple, rather than AbstractZero/Composite,
    detected. This should never occur. Please open an issue on
    https://github.com/FluxML/Zygote.jl/issues, including the full text of this message.
    Stacktrace:"""
  )
  for (i, callsite) in enumerate(stacktrace())
    Core.println("[$i] $callsite")
  end
end

"""
    difftype_warn()

Issue a warning that a Zygote legacy type was expected but a ChainRules differential type
was received. This is used to report bugs in transitioning to ChainRules types and can be
deleted once/if `@adjoint` macro is deprecated.
"""
function difftype_warn()
  # can't use logging macros as that breaks nested AD.
  Core.println("""
    AbstractZero/Composite passed when NothingTuple/NamedTuple expected. This should never
    occur. Please open an issue on https://github.com/FluxML/Zygote.jl/issues, including
    the full text of this message.
    Stacktrace:"""
  )
  for (i, callsite) in enumerate(stacktrace())
    Core.println("[$i] $callsite")
  end
end

"""
    legacy2differential(x)

Convert input `x` from the legacy ZygoteRules format to the ChainRules differential types.
"""
legacy2differential(x) = x
legacy2differential(::Nothing) = Zero()
legacy2differential(x::Union{AbstractZero, Composite}) = (difftype_warn(); return x)
legacy2differential(t::Union{Tuple, NamedTuple}) = map(l2d, t)

l2d(x) = x
l2d(::Nothing) = Zero()
function l2d(t::Union{Tuple, NamedTuple})
  tp = map(l2d, t)
  return Composite{Any, typeof(tp)}(tp)
end
"""
    differential2legacy(x)

Convert input `x` from the ChainRules differential types to the legacy ZygoteRules format.
"""
differential2legacy(x) = unthunk(x) # TODO eventually remove this
differential2legacy(::AbstractZero) = nothing
differential2legacy(t::Union{Tuple, NamedTuple}) = map(differential2legacy, t)
differential2legacy(::Nothing) = (legacytype_warn(); return nothing)
#differential2legacy(x::Tuple{Vararg{AbstractZero}}) = Zero() # TODO should this happen?
for T_outer in (:Tuple, :NamedTuple)
  # we create separate methods rather than using a `Union` + an `if` so that we avoid a
  # branch that changes output type, because nested AD on that kinda thing makes Zygote less
  # than happy.
  @eval @inline function differential2legacy(x::Composite{P, T}) where {P, T<:$T_outer}
    xp = map(differential2legacy, x)
    convert($T_outer, xp)
  end
end

for n = 0:3
  gradtuple = Symbol(:gradtuple, n)
  @eval begin
    $gradtuple(x::Tuple) = ($(ntuple(_->:(DoesNotExist()),n)...), x...)
    $gradtuple(x::AbstractZero) = x
    $gradtuple(x::Composite) = x # TODO should this be here?
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
      y, _back = adjoint(__context__, $f, $(argnames...))
      $(mut ? nothing : :(back(::Union{Nothing,AbstractZero}) = Zero()))
      back(Δ) = $gradtuple(legacy2differential(_back(differential2legacy(Δ))))
      return y, back
    end
    @inline function ZygoteRules._pullback($cx, ::$kT, kw, $f::$T, $(args...)) where $(Ts...)
      y, _back = adjoint(__context__, $f, $(argnames...); kw...)
      $(mut ? nothing : :(back(::Union{Nothing,AbstractZero}) = Zero()))
      back(Δ) = $gradtuplekw(legacy2differential(_back(differential2legacy(Δ))))
      return y, back
    end
    return nothing  # make nothing show in terminal after using macro
  end
end

macro adjoint(ex)
  gradm(ex)
end

macro adjoint!(ex)
  gradm(ex, true)
end
