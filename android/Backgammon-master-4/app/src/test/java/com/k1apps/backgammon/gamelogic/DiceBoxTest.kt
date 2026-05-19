package com.k1apps.backgammon.gamelogic

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

@RunWith(MockitoJUnitRunner::class)
class DiceBoxTest {

    @Mock
    private lateinit var dice1: Dice

    @Mock
    private lateinit var dice2 : Dice

    private lateinit var diceBox : DiceBox

    @Before
    fun setup() {
        diceBox = spy(DiceBoxImpl(dice1, dice2))
    }

    @Test
    fun given_roll_called_then_dice1_and_dice2_roll_must_be_called() {
        diceBox.roll()
        verify(diceBox.dice1, times(1)).roll()
        verify(diceBox.dice2, times(1)).roll()
    }

    @Test
    fun given_roll_called_when_dices_number_are_same_then_dice1_and_dice2_twice_should_be_invoked() {
        `when`(dice1.roll()).thenReturn(4)
        `when`(dice2.roll()).thenReturn(4)
        diceBox.roll()
        verify(dice1).twice()
        verify(dice2).twice()
    }

    @Test
    fun given_enableDiceWith_4_called_when_dice1_enableWith_4_is_false_then_dice2_enableWith_4_should_be_invoked() {
        `when`(dice1.enableWith(4)).thenReturn(false)
        diceBox.enableDiceWith(4)
        verify(diceBox.dice2, times(1)).enableWith(4)
    }

    @Test
    fun given_enableDiceWith_4_called_when_dice1_enableWith_4_is_true_then_dice2_enableWith_4_should_not_invoked() {
        `when`(dice1.enableWith(4)).thenReturn(true)
        diceBox.enableDiceWith(4)
        verify(diceBox.dice1, times(1)).enableWith(4)
        verify(diceBox.dice2, times(0)).enableWith(4)
    }


    @Test
    fun given_allActiveDicesNumbers_called_when_dices_are_same_with_numbers5_and_active_then_return_list_with_four_numbers5() {
        val list = arrayListOf<Byte>()
        list.add(5)
        list.add(5)
        `when`(dice1.getActiveNumbers()).thenReturn(list)
        `when`(dice2.getActiveNumbers()).thenReturn(list)
        val allNumbers = diceBox.allActiveDicesNumbers()
        assertTrue(allNumbers.size == 4)
        allNumbers.forEach {
            assertTrue(it == 5.toByte())
        }

    }

    @Test
    fun given_getActiveDiceWithNumber_2_called_when_dice1_number_is_2_then_return_dice1() {
        `when`(dice1.number).thenReturn(2)
        `when`(dice1.isActive()).thenReturn(true)
        assertTrue(diceBox.getActiveDiceWithNumber(2) === dice1)
    }

    @Test
    fun given_getActiveDiceWithNumber_2_called_when_dice1_number_is_3_and_dice2_number_is_5_then_return_null() {
        `when`(dice1.isActive()).thenReturn(true)
        `when`(dice1.number).thenReturn(3)
//        `when`(dice2.isActive()).thenReturn(true)
        `when`(dice2.number).thenReturn(5)
        assertTrue(diceBox.getActiveDiceWithNumber(2) === null)
    }
    @Test
    fun given_getActiveDiceWithNumber_2_called_when_dice1_number_is_null_and_dice2_number_is_2_then_return_dice2() {
        `when`(dice1.isActive()).thenReturn(true)
//        `when`(dice2.isActive()).thenReturn(true)
//        `when`(dice1.number).thenReturn(null)
        `when`(dice2.number).thenReturn(2)
        assertTrue(diceBox.getActiveDiceWithNumber(2) === dice2)
    }

    @Test
    fun given_getActiveDiceWithNumber_2_called_when_dice1_number_is_null_and_dice2_is_null_then_return_null() {
        assertTrue(diceBox.getActiveDiceWithNumber(2) == null)
    }

    @Test
    fun given_getActiveDiceGreaterEqual_2_called_then_invoke_getActiveDiceWithNumber_2() {
        diceBox.getActiveDiceGreaterEqual(2)
        verify(diceBox).getActiveDiceWithNumber(2)
    }

    @Test
    fun given_getActiveDiceGreaterEqual_2_called_when_dice1_number_is_2_and_dice2_number_is_3_then_return_dice1() {
        `when`(dice1.isActive()).thenReturn(true)
//        `when`(dice2.isActive()).thenReturn(true)
        `when`(dice1.number).thenReturn(2)
//        `when`(dice2.number).thenReturn(3)
        val diceResult = diceBox.getActiveDiceGreaterEqual(2)
        assertTrue(diceResult === dice1)
    }

    @Test
    fun given_getActiveDiceGreaterEqual_2_called_when_dice1_number_is_1_and_dice2_number_is_4_then_return_dice2() {
        `when`(dice1.isActive()).thenReturn(true)
        `when`(dice1.number).thenReturn(1)
        `when`(dice2.number).thenReturn(4)
        val diceResult = diceBox.getActiveDiceGreaterEqual(2)
        assertTrue(diceResult === dice2)
    }

    @Test
    fun given_getActiveDiceGreaterEqual_2_called_when_dice1_number_is_1__and_dice2_nuber_is_1_then_return_null() {
        `when`(dice1.isActive()).thenReturn(true)
//        `when`(dice2.isActive()).thenReturn(true)
        `when`(dice1.number).thenReturn(1)
        `when`(dice2.number).thenReturn(1)
        val diceResult = diceBox.getActiveDiceGreaterEqual(2)
        assertTrue(diceResult == null)
    }

    @Test(expected = DiceRangeException::class)
    fun given_getActiveDiceGreaterEqual_8_called_then_throw_diceRangeException() {
        diceBox.getActiveDiceGreaterEqual(8)
    }

    @Test
    fun given_isEnable_called_when_dice1_is_active_and_dice2_is_deactive_then_return_true() {
        `when`(dice1.isActive()).thenReturn(true)
//        `when`(dice2.isActive()).thenReturn(false)
        assertTrue(diceBox.isEnabled())
    }

    @Test
    fun given_isEnable_called_when_dice1_and_dice2_is_deactive_then_return_false() {
        `when`(dice1.isActive()).thenReturn(false)
        `when`(dice2.isActive()).thenReturn(false)
        assertFalse(diceBox.isEnabled())
    }
}