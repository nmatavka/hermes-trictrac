package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.gamelogic.event.DiceThrownEvent
import com.k1apps.backgammon.gamelogic.event.DiceBoxThrownEvent
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner


@RunWith(MockitoJUnitRunner::class)
class DiceDistributorTest {

    @Mock
    private lateinit var dice1: Dice

    @Mock
    private lateinit var dice2: Dice

    private lateinit var diceBox : DiceBox

    @Mock
    private lateinit var player1: Player

    @Mock
    private lateinit var player2: Player

    private lateinit var diceDistributor: DiceDistributor

    @Before
    fun setup() {
        diceBox = DiceBoxImpl(dice1, dice2)
        diceDistributor = DiceDistributorImpl(player1, player2, diceBox)
    }
    @Test
    fun given_started_then_each_of_two_players_must_have_dice() {
        diceDistributor.start()
        verify(player1, times(1)).dice = dice1
        verify(player2, times(1)).dice = dice2
    }

    @Test
    fun given_player1_DiceThrownEvent_called_when_player1_has_dice_and_num_is_6_and_player2_has_dice_with_number_2_then_retake_dices_from_players_and_set_dice_box_to_player1() {
        `when`(dice1.number).thenReturn(6)
        `when`(dice2.number).thenReturn(2)
        player1.dice = dice1
        player2.dice = dice2
        diceDistributor.onEvent(DiceThrownEvent(player1))
        verify(player1, times(1)).diceBox = diceBox
        verify(player2, times(0)).diceBox = diceBox
        verify(player1, times(1)).retakeDice()
        verify(player2, times(1)).retakeDice()

    }

    @Test
    fun given_player1_DiceThrownEvent_called_when_player1_has_dice_and_num_is_3_and_player2_does_not_yet_rolled_dice_then_player1_and_player2_must_have_dice() {
        `when`(dice1.number).thenReturn(3)
        `when`(dice2.number).thenReturn(null)
        diceDistributor.onEvent(DiceThrownEvent(player1))
        verify(player1, times(0)).retakeDice()
        verify(player2, times(0)).retakeDice()
    }

    @Test
    fun given_DiceThrown_occurred_when_player1_dice_num_is_equal_to_player2_then_retake_dices_and_restart_roll_dices() {
        `when`(dice1.number).thenReturn(2)
        `when`(dice2.number).thenReturn(2)
        diceDistributor.onEvent(DiceThrownEvent(player1))
        verify(player1, times(1)).dice = diceBox.dice1
        verify(player2, times(1)).dice = diceBox.dice2
        verify(player1, times(1)).retakeDice()
        verify(player2, times(1)).retakeDice()
    }

    @Test
    fun given_whichPlayerHasDiceBox_called_when_player1_has_dice_box_then_return_player1() {
        `when`(player1.diceBox).thenReturn(diceBox)
        assertTrue(diceDistributor.whichPlayerHasDice()?.first === player1)
    }

    @Test
    fun given_whichPlayerHasDiceBox_called_when_player2_has_dice_box_then_return_player2() {
        `when`(player2.diceBox).thenReturn(diceBox)
        assertTrue(diceDistributor.whichPlayerHasDice()?.first === player2)
    }

    @Test
    fun given_whichPlayerHasDice_called_when_both_player_has_dice_then_return_both_players() {
        `when`(player1.dice).thenReturn(dice1)
        `when`(player2.dice).thenReturn(dice2)
        val whichPlayerHasDice = diceDistributor.whichPlayerHasDice()
        assertTrue(whichPlayerHasDice!!.first == player1)
        assertTrue(whichPlayerHasDice.second == player2)
    }

    @Test
    fun given_DiceBoxThrownEvent_called_by_player1_when_player1_has_diceBox_then_player1_updateDicesStateInDiceBox_should_be_called() {
        `when`(player1.diceBox).thenReturn(diceBox)
        val diceBoxThrownEvent = DiceBoxThrownEvent(player1)
        diceDistributor.onEvent(diceBoxThrownEvent)
        verify(player1, times(1)).updateDiceBoxStatus()
    }

    @Test
    fun given_DiceBoxThrownEvent_called_by_player1_when_player1_has_diceBox_and_diceBox_does_not_have_enable_dice_then_retake_diceBox_from_player1_and_set_it_to_player2() {
        `when`(player1.diceBox).thenReturn(diceBox)
        `when`(diceBox.isEnabled()).thenReturn(false)
        val diceBoxThrownEvent = DiceBoxThrownEvent(player1)
        diceDistributor.onEvent(diceBoxThrownEvent)
        verify(player1, times(1)).retakeDiceBox()
        verify(player2, times(1)).diceBox = diceBox
    }
}