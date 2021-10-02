"""
  pullback_for_default_literal_getproperty(cx::AContext, x, ::Val{f}) where {f}

Performant pullback implementation for the default method of `getproperty`. Works around a
known performance issue in Zygote.

To use this for your type `YourType`, copy + paste the following
```julia
using ZygoteRules
using ZygoteRules: AContext, literal_getproperty, pullback_for_default_literal_getproperty

function ZygoteRules._pullback(
  cx::AContext, ::typeof(literal_getproperty), x::YourType, ::Val{f}
) where {f}
    return pullback_for_default_literal_getproperty(cx, x, Val{f}())
end
```
and replace `YourType` with the name of your type.

You _should_ make use of this method if you have not implemented
`getproperty(::YourType, ::Symbol)`.

Conversely, you should _not_ make use of this functionality if you have a custom
implementation of `getproperty`. Instead, you should directly implement a pullback for
`literal_getproperty` that is correct for your method.

You can locate this method anywhere in your code.

If you come across a type implemented in the Julia Base or the standard libraries for which
this workaround is appropriate, but for which it has not yet been implemented, please
consider opening an issue or (better yet) a PR to Zygote to add this method for that type.
"""
function pullback_for_default_literal_getproperty(cx::AContext, x, ::Val{f}) where {f}
  return _pullback(cx, literal_getfield, x, Val{f}())
end
