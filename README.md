# ZygoteRules.jl

This is a minimal (<100sloc) package which enables you to add custom gradients to Zygote, without depending on Zygote itself.

Usage:

```julia
foo(a, b) = a*b

using ZygoteRules

@adjoint foo(a, b) = a*b, c̄ -> (b'c̄, a'c̄)
```

See the Zygote docs for more details on how to write custom gradients.
