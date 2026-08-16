using TricTracZero

isempty(ARGS) && error("Usage: julia scripts/train_race.jl <backgammon|tapa|jacquet|garanguet|tavli>")
run_race_train(ARGS[1])
