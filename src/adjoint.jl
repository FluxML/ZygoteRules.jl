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
      back(Δ) = $gradtuple(ZygoteRules.clamptype(argTs, _back(Δ)))
      return y, back
    end
    @inline function ZygoteRules._pullback($cx, ::$kT, kw, $f::$T, $(args...)) where $(Ts...)
      argTs = map(typeof, ($(argnames...),))
      y, _back = adjoint(__context__, $f, $(argnames...); kw...)
      $(mut ? nothing : :(back(::Nothing) = nothing))
      back(Δ) = $gradtuplekw(ZygoteRules.clamptype(argTs, _back(Δ)))
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

clamptype(::Type{<:Real}, dx::Complex) = (@info "preserving Real, from $dx"; real(dx))
clamptype(::Type{<:AbstractArray{<:Real}}, dx::AbstractArray{<:Complex}) = 
  (@info "fixing AbstractArray{<:Complex}"; real(dx))

clamptype(Ts::Tuple{Vararg{<:Type,N}}, dxs::Tuple{Vararg{Any,N}}) where {N} =
    map(clamptype, Ts, dxs)
clamptype(x, dx) = (@debug "Any" x dx; dx)

