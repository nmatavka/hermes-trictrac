package com.k1apps.backgammon.gamelogic

import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

@RunWith(MockitoJUnitRunner::class)
class GameTest {
    @Mock
    lateinit var board: Board
    @Mock
    lateinit var player1: Player
    @Mock
    lateinit var player2: Player
    @Mock
    lateinit var diceDistributor: DiceDistributor
    @InjectMocks
    lateinit var game: GameImpl

    @Test
    fun when_referee_started_then_board_should_be_init_called() {
        game.start()
        verify(board, times(1)).initBoard()
    }


    @Test
    fun when_referee_started_then_dice_distributor_should_started() {
        game.start()
        verify(diceDistributor, times(1)).start()
    }

    @Test
    fun when_referee_started_then_start_dice_distributor() {
        game.start()
        verify(diceDistributor, times(1)).start()
    }

    @Test
    fun when_roll_called_then_pass_roll_to_player_if_turn_is_correct() {
        `when`(diceDistributor.whichPlayerHasDice()).thenReturn(Pair(player1, null))
        `when`(player1.playerType).thenReturn(PlayerType.LocalPlayer)
        game.roll(PlayerType.LocalPlayer)
        verify(player1, times(1)).roll()
    }

    @Test
    fun when_dice_distributor_return_two_player_and_player1_type_is_correct_then_pass_roll_to_player1() {
        `when`(diceDistributor.whichPlayerHasDice()).thenReturn(Pair(player1, player2))
        `when`(player1.playerType).thenReturn(PlayerType.AndroidPlayer)
        game.roll(PlayerType.AndroidPlayer)
        verify(player1, times(1)).roll()
        verify(player2, times(0)).roll()
    }

    @Test
    fun when_dice_distributor_return_two_player_and_player2_type_is_correct_then_pass_roll_to_player2() {
        `when`(diceDistributor.whichPlayerHasDice()).thenReturn(Pair(player1, player2))
        `when`(player1.playerType).thenReturn(PlayerType.AndroidPlayer)
        `when`(player2.playerType).thenReturn(PlayerType.LocalPlayer)
        game.roll(PlayerType.LocalPlayer)
        verify(player2, times(1)).roll()
        verify(player1, times(0)).roll()
    }

    @Test
    fun when_dice_distributor_return_two_player_and_both_of_two_players_type_is_correct_then_pass_roll_to_player1() {
        `when`(diceDistributor.whichPlayerHasDice()).thenReturn(Pair(player1, player2))
        `when`(player1.playerType).thenReturn(PlayerType.LocalPlayer)
        game.roll(PlayerType.LocalPlayer)
        verify(player2, times(0)).roll()
        verify(player1, times(1)).roll()
    }

    @Test
    fun when_dice_distributor_return_two_player_and_both_of_two_players_type_is_incorrect_then_pass_roll_to_no_any_players() {
        `when`(diceDistributor.whichPlayerHasDice()).thenReturn(Pair(player1, player2))
        `when`(player1.playerType).thenReturn(PlayerType.LocalPlayer)
        `when`(player2.playerType).thenReturn(PlayerType.LocalPlayer)
        game.roll(PlayerType.AndroidPlayer)
        verify(player1, times(0)).roll()
        verify(player2, times(0)).roll()
    }


    @Test
    fun when_roll_called_then_dont_pass_roll_to_player_if_turn_is_incorrect() {
        `when`(diceDistributor.whichPlayerHasDice()).thenReturn(Pair(player1, null))
        `when`(player1.playerType).thenReturn(PlayerType.LocalPlayer)
        game.roll(PlayerType.AndroidPlayer)
        verify(player1, times(0)).roll()
    }

    @Test
    fun when_roll_called_and_dice_box_dont_with_any_players_then_dont_pass_roll_to_player() {
        `when`(diceDistributor.whichPlayerHasDice()).thenReturn(null)
        game.roll(PlayerType.AndroidPlayer)
        verify(player1, times(0)).roll()
        verify(player2, times(0)).roll()
    }

    @Test
    fun given_getTargetCellsBasedOn_called_when_playerType_is_incorrect_then_should_return_empty_array() {
        `when`(player1.playerType).thenReturn(PlayerType.AndroidPlayer)
        `when`(diceDistributor.whichPlayerHasDice()).thenReturn(Pair(player1, null))
        val lst = game.getTargetCellsBasedOn(PlayerType.LocalPlayer, 10)
        assertTrue(lst.isEmpty())
    }

    @Test
    fun given_getTargetCellsBasedOn_called_when_playerType_is_correct_then_player_getTargetCellsBasedOn_should_be_called() {
        `when`(player1.playerType).thenReturn(PlayerType.LocalPlayer)
        `when`(diceDistributor.whichPlayerHasDice()).thenReturn(Pair(player1, null))
        val cellPosition = 10
        game.getTargetCellsBasedOn(PlayerType.LocalPlayer, cellPosition)
        verify(player1).getTargetCellsBasedOn(cellPosition)
    }
}