# The protocol, hot reload, and policy selection code is shared.  The stored
# Bräde gspec selects raw Jacquet-parallel actions and Bräde feature encoding.
include(joinpath(@__DIR__, "frontend_bot.jl"))
main()
