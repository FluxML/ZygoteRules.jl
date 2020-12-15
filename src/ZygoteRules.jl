module ZygoteRules

export @adjoint, @adjoint!

"""
    ZygoteRules.literal_getproperty(x, ::Val{f})

In Zygote, differentiation of property access is defined by defining adjoint of
`ZygoteRules.literal_getproperty` rather than of `Base.getproperty`.
"""
literal_getproperty(x, ::Val{f}) where f = getproperty(x, f)

"""
    ZygoteRules.literal_getfield(x, ::Val{f})

In Zygote, differentiation of property access is defined by defining adjoint of
`ZygoteRules.literal_getfield` rather than of `Base.getfield`.
"""
literal_getfield(x, ::Val{f}) where f = getfield(x, f)

include("adjoint.jl")

end
