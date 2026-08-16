# Race-game sessions persist a RaceGameSpec that selects their raw physical
# action codec and variant-specific encoder.  The protocol and checkpoint hot
# reload implementation is shared with the existing Julia frontend.
include(joinpath(@__DIR__, "frontend_bot.jl"))
main()
