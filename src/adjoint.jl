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


function unthunk_tangent end
@inline unthunk_tangent(x) = x
@inline unthunk_tangent(x::Tuple) = map(unthunk_tangent, x)
@inline unthunk_tangent(x::NamedTuple) = map(unthunk_tangent, x)


@inline maybe_final(cx::AContext, y) = nothing
@inline maybe_final(x) = nothing


function gradm(ex, mut = false, keepthunks = false, finalise = false)
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
  maybe_finalise_y = finalise ? :(maybe_final(__context__,y)) : nothing
  quote
    $adj
    @inline function ZygoteRules._pullback($cx, $f::$T, $(args...)) where $(Ts...)
      y, _back = adjoint(__context__, $f, $(argnames...))
      $(mut ? nothing : :(back(::Nothing) = nothing))
      back(Δ) = begin ∇s = $gradtuple(_back($maybe_unthunked_Δ)); $maybe_finalise_y; ∇s end
      return y, back
    end
    @inline function ZygoteRules._pullback($cx, ::$kT, kw, $f::$T, $(args...)) where $(Ts...)
      y, _back = adjoint(__context__, $f, $(argnames...); kw...)
      $(mut ? nothing : :(back(::Nothing) = nothing))
      back(Δ) = begin ∇s = $gradtuplekw(_back($maybe_unthunked_Δ)); $maybe_finalise_y; ∇s end
      return y, back
    end
    nothing
  end
end

macro adjoint(ex)
  gradm(ex, false, false, false)
end

macro adjoint!(ex)
  gradm(ex, true, false, false)
end

"""
    @adjoint_final function f(x) ...

This differs from `@adjoint` in that it may call `finalize(y)` on
the forward result `y = f(x)`, after the backward pass.
(This will never happen within `jacobian`, where the pullback is
called several times, hence `y` must be kept.)

For correctness, by using this macro you guarantee that `y = f(x)`
is a new array, never `===` nor aliasing `x`.
(Gradients `dx` also may not be thunks closing over `y`,
but like `adjoint` this should automatically un-thunk.)

Calling `finalize` is an optimisation to help free up GPU memory.
To free up intermediate steps by hand, use `maybe_final(__context__, z)`
inside the reverse pass (for `z` which must survive until then)
or `maybe_final(z)` to discard `z` immediately (even inside `jacobian`).
"""
macro adjoint_final(ex)
    ZygoteRules.gradm(ex, false, false, true)
end
