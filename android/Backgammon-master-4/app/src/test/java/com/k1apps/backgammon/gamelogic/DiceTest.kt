package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.DiceStatus
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.Spy
import org.mockito.junit.MockitoJUnitRunner
import kotlin.random.Random

@RunWith(MockitoJUnitRunner::class)
class DiceTest {

    companion object {
        private const val NUMBER: Byte = 5
    }

    @Mock
    private lateinit var random: Random
    @Spy
    private lateinit var status: DiceStatus

    private lateinit var dice: Dice

    @Before
    fun setup() {
        `when`(random.nextInt(1, 7)).thenReturn(5)
        dice = spy(DiceImpl(random, status))
    }

    @Test(expected = DiceException::class)
    fun given_roll_called_when_dice_rolled_and_not_yet_use_and_rolled_again_then_throw_DiceException() {
        dice.roll()
        //dice.enable()
        dice.roll()
    }

    @Test(expected = DiceException::class)
    fun given_roll_called_when_dice_rolled_and_twice_and_two_time_enabled_and_one_time_used_then_rolled_again_should_throw_DiceException() {
        dice.roll()
        dice.twice()
        dice.enableWith(NUMBER)
        dice.enableWith(NUMBER)
        dice.use()
        dice.roll()
    }

    @Test
    fun given_roll_called_when_dice_rolled_without_twice_and_two_time_enabled_and_one_time_used_then_rolled_again_should_be_without_DiceException() {
        dice.roll()
//        dice.twice()
        dice.enableWith(NUMBER)
        dice.enableWith(NUMBER)
        dice.use()
        dice.roll()
    }

    @Test(expected = DiceException::class)
    fun give_use_called_when_dice_is_not_yet_rolled_then_throw_DiceException() {
        dice.use()
    }

    @Test
    fun give_use_called_when_dice_is_disable_then_return_false() {
        dice.roll()
        //dice.enable()
        assertFalse(dice.use())
    }

    @Test
    fun give_use_called_when_dice_rolled_and_enabled_then_return_value_should_be_true_and_can_roll_again() {
        dice.roll()
        dice.enableWith(NUMBER)
        assertTrue(dice.use())
        dice.roll()
    }

    @Test(expected = DiceException::class)
    fun give_use_called_when_dice_rolled_and_enabled_and_twice_then_return_value_should_be_true_and_can_not_roll_again() {
        dice.roll()
        dice.enableWith(NUMBER)
        dice.twice()
        assertTrue(dice.use())
        dice.roll()
    }

    @Test(expected = DiceException::class)
    fun give_enable_called_when_dice_is_not_yet_rolled_then_throw_DiceException() {
        dice.enableWith(NUMBER)
    }

    @Test
    fun given_enableWith_called_when_dice_is_twice_and_one_time_enabled_then_return_true() {
        dice.roll()
        dice.twice()
        dice.enableWith(NUMBER)
        assertTrue(dice.enableWith(NUMBER))
    }

    @Test
    fun give_enableWith_called_when_dice_is_twice_and_one_time_enabled_and_one_time_use_called_then_return_true() {
        dice.roll()
        dice.twice()
        dice.enableWith(NUMBER)
        dice.use()
        assertTrue(dice.enableWith(NUMBER))
    }

    @Test(expected = DiceException::class)
    fun given_twice_called_when_dice_is_not_rolled_then_throw_DiceException() {
        dice.twice()
    }

    @Test(expected = DiceException::class)
    fun given_twice_called_when_dice_is_used_before_then_throw_DiceException() {
        dice.roll()
        dice.enableWith(NUMBER)
        dice.use()
        dice.twice()
    }

    @Test
    fun given_isActive_called_when_dice_is_not_yet_rolled_then_return_false() {
        assertFalse(dice.isActive())
    }

    @Test
    fun given_isActive_called_when_rolled_and_not_enabled_then_return_false() {
        dice.roll()
        assertFalse(dice.isActive())
    }

    @Test
    fun given_isActive_called_when_rolled_and_enabled_and_used_then_return_false() {
        dice.roll()
        dice.enableWith(NUMBER)
        dice.use()
        assertFalse(dice.isActive())
    }

    @Test
    fun given_isActive_called_when_rolled_and_twice_and_one_time_enable_invoked_then_isActive_should_be_false() {
        dice.roll()
        dice.enableWith(NUMBER)
        dice.twice()
        dice.use()
        assertFalse(dice.isActive())
    }

    @Test
    fun given_isActive_called_when_rolled_and_enabled_then_return_true() {
        dice.roll()
        dice.enableWith(NUMBER)
        assertTrue(dice.isActive())
    }

    @Test
    fun given_createMemento_called_when_restore_memento_to_new_object_then_new_object_should_equal_to_first_object() {
        dice.roll()
        val memento = dice.createMemento()
        val dice1 = DiceImpl(random, DiceStatus())
        dice1.restore(memento)
        assertTrue(dice1 == dice)
    }

    @Test
    fun given_getActiveNumbers_called_when_dice_number_is_5_and_status_enable_count_is_2_then_return_should_be_array_two_count_5() {
        `when`(dice.number).thenReturn(NUMBER)
        `when`(status.enableCount()).thenReturn(2)
        assertTrue(dice.getActiveNumbers().size == 2)
        assertTrue(dice.getActiveNumbers()[0] == NUMBER)
        assertTrue(dice.getActiveNumbers()[1] == NUMBER)
    }
    @Test
    fun given_getActiveNumbers_called_when_dice_number_is_5_and_status_enable_count_is_1_then_return_should_be_array_one_count_5() {
        `when`(dice.number).thenReturn(NUMBER)
        `when`(status.enableCount()).thenReturn(1)
        assertTrue(dice.getActiveNumbers().size == 1)
        assertTrue(dice.getActiveNumbers()[0] == NUMBER)
    }
    @Test
    fun given_getActiveNumbers_called_when_dice_number_is_5_and_status_enable_count_is_0_then_return_should_be_empty_array() {
//        `when`(dice.number).thenReturn(NUMBER)
        `when`(status.enableCount()).thenReturn(0)
        assertTrue(dice.getActiveNumbers().isEmpty())
    }
}