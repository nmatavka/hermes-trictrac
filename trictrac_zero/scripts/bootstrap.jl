import Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))

Pkg.activate(ROOT)
Pkg.develop(path = joinpath(ROOT, "vendor", "AlphaZero.jl"))
Pkg.instantiate()
