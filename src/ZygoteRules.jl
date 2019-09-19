module ZygoteRules

export @adjoint, @adjoint!

"""
    ZygoteRules.literal_getproperty(x, ::Val{f})

In Zygote, differentiation of property access is defined by defining adjoint of
`ZygoteRules.literal_getproperty` rather than of `Base.getproperty`.
"""
literal_getproperty(x, ::Val{f}) where f = getproperty(x, f)

include("adjoint.jl")

end
