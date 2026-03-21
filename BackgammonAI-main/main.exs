Code.require_file("backgammon/game/game_controller.exs")

GameController.start_game()

# board = Board.create()
# player = PlayerBuilder.default_build_white("player")
# opponent = PlayerBuilder.default_build_black("AI")
# dice_roll = [5, 3]

# game_state = MoveGenerator.new(board, opponent, player, dice_roll)

# Board.show(board)
# IO.inspect(GameEngine.choose_best_move(game_state))
# IO.inspect(MoveGenerator.generate_moves(game_state))
