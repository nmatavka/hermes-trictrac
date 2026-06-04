import Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))

Pkg.activate(ROOT)

if get(ENV, "TRICTRAC_ZERO_SKIP_BOOTSTRAP", "0") != "1"
  Pkg.develop(path = joinpath(ROOT, "vendor", "AlphaZero.jl"))
  Pkg.instantiate()
end
