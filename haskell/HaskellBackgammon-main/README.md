# HaskellBackgammon

Implementation of Backgammon board game using Haskell

Description:
    Backgammon is a two-player board game played with checkers and dice. each player has fifteen checkers. The backgammon table pieces move along twenty-four 'points' according to the roll of two dice. The objective of the game is to move the fifteen pieces around the board and be first to bear off, i.e., remove them from the board.



Board:
	Each side of the board has a track of 12 long triangles, called points. The points form a continuous track in the shape of a horseshoe, and are numbered from A to X starting from the bottom left.
Note: In online versions, you'll find them numbered clockwise, but in our game it's counter clockwise.

Setup:
	Each player begins with fifteen pieces; all are placed on their 24-point (the numbering of the points is different for each player).
The two players move their pieces in opposing directions, from the 24-point towards the 1-point.
Points A through F are called the home board or inner board, and others are called the outer board.

Movement:
	After rolling the dice, players must, if possible, move their pieces according to the number shown on each die. For example, if the player rolls a 6 and a 3 (denoted as "6-3"), the player must move one checker six points forward, and another or the same checker three points forward. The same checker may be moved twice, as long as the two moves can be made separately and legally: six and then three, or three and then six. If a player rolls two of the same number, called doubles, that player must play each die twice. For example, a roll of 5-5 allows the player to make four moves of five spaces each. On any roll, a player must move according to the numbers on both dice if it is at all possible to do so. If one or both numbers do not allow a legal move, the player forfeits that portion of the roll and the turn ends. If moves can be made according to either one die or the other, but not both, the player can choose any one. In the course of a move, a checker may land on any point that is unoccupied or is occupied by one or more of the player's own checkers. It may also land on a point occupied by exactly one opposing checker. In this case, the checker has been "Mahbousa" and is not allowed to move unless the checker (and all the checkers on the same point) that made it Mahbousa move. A checker may never land on a point occupied by two or more opposing checkers. There is no limit to the number of checkers that can occupy a point or the bar at any given time.

Bearing off:
	When all of a player's checkers are in that player's home board, that player may start removing them; this is called "bearing off". A roll of 1 may be used to bear off a checker from the 1-point, a 2 from the 2-point, and so on. If all of a player's checkers are on points lower than the number showing on a particular die, the player must use that die to bear off one checker from the highest occupied point. For example, if a player rolls a 6 and a 5, but has no checkers on the 6-point and two on the 5-point, then the 6 and the 5 must be used to bear off the two checkers from the 5-point. When bearing off, a player may also move a lower die roll before the higher even if that means the full value of the higher die is not fully utilized. For example, if a player has exactly one checker remaining on the 6-point, and rolls a 6 and a 1, the player may move the 6-point checker one place to the 5-point with the lower die roll of 1, and then bear that checker off the 5-point using the die roll of 6; this is sometimes useful tactically. As before, if there is a way to use all moves showing on the dice by moving checkers within the home board or by bearing them off, the player must do so.

If players can't play any move their turn will be skipped.

Running the Game

Use Cabal and GHC "cabal run", versions are specificed HaskellBackgammon.cabal in file.
