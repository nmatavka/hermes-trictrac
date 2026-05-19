package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.Constants.BOARD_LOCATION_RANGE
import com.k1apps.backgammon.Constants.NORMAL_PIECE
import com.k1apps.backgammon.Constants.REVERSE_PIECE
import dagger.Component
import dagger.Module
import dagger.Provides
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.mockito.Mockito.spy
import javax.inject.Inject
import javax.inject.Named

class PieceTest {

    @Inject
    @field:Named(NORMAL_PIECE)
    lateinit var pieceNormal: Piece

    @Inject
    @field:Named(REVERSE_PIECE)
    lateinit var pieceReverse: Piece

    @Before
    fun setup() {
        DaggerPieceComponentTest.create().inject(this)
    }

    @Test
    fun when_piece_set_location_is_greater_24_or_less_than_1_then_location_must_not_changed() {
        pieceNormal.location = 6
        pieceNormal.location = 28
        assertTrue(pieceNormal.location == 6)
        pieceNormal.location = 0
        assertTrue(pieceNormal.location == 6)

        pieceReverse.location = 6
        pieceReverse.location = 28
        assertTrue(pieceReverse.location == 6)
        pieceReverse.location = 0
        assertTrue(pieceReverse.location == 6)
    }


    @Test
    fun when_piece_set_location_1_to_24_then_location_must_be_1_to_24() {
        for (index in BOARD_LOCATION_RANGE) {
            pieceNormal.location = index
            assertTrue("piece location is: ${pieceNormal.location}", pieceNormal.location == index)
        }

        for (index in BOARD_LOCATION_RANGE) {
            pieceReverse.location = index
            assertTrue(
                "piece location is: ${pieceReverse.location}",
                pieceReverse.location == index
            )
        }
    }

    @Test
    fun when_pieceAfterMove_for_reverse_piece_type_with_number_1_called_and_piece_is_dead_then_return_inGame_piece_with_location_1() {
        pieceReverse.state = PieceState.DEAD
        val pieceAfterMove = pieceReverse.pieceAfterMove(1)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 1)
    }

    @Test
    fun when_pieceAfterMove_for_reverse_piece_type_with_number_2_called_and_piece_is_dead_then_return_inGame_piece_with_location_2() {
        pieceReverse.state = PieceState.DEAD
        val pieceAfterMove = pieceReverse.pieceAfterMove(2)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 2)
    }

    @Test
    fun when_pieceAfterMove_for_reverse_piece_type_with_number_3_called_and_piece_is_dead_then_return_inGame_piece_with_location_3() {
        pieceReverse.state = PieceState.DEAD
        val pieceAfterMove = pieceReverse.pieceAfterMove(3)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 3)
    }

    @Test
    fun when_pieceAfterMove_for_reverse_piece_type_with_number_4_called_and_piece_is_dead_then_return_inGame_piece_with_location_4() {
        pieceReverse.state = PieceState.DEAD
        val pieceAfterMove = pieceReverse.pieceAfterMove(4)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 4)
    }

    @Test
    fun when_pieceAfterMove_for_reverse_piece_type_with_number_5_called_and_piece_is_dead_then_return_inGame_piece_with_location_5() {
        pieceReverse.state = PieceState.DEAD
        val pieceAfterMove = pieceReverse.pieceAfterMove(5)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 5)
    }

    @Test
    fun when_pieceAfterMove_for_reverse_piece_type_with_number_6_called_and_piece_is_dead_then_return_inGame_piece_with_location_6() {
        pieceReverse.state = PieceState.DEAD
        val pieceAfterMove = pieceReverse.pieceAfterMove(6)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue("location is ${pieceAfterMove.location}", pieceAfterMove.location == 6)
    }

    @Test
    fun when_pieceAfterMove_for_normal_piece_type_with_number_1_called_and_piece_is_dead_then_return_inGame_piece_with_location_24() {
        pieceNormal.state = PieceState.DEAD
        val pieceAfterMove = pieceNormal.pieceAfterMove(1)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 24)
    }

    @Test
    fun when_pieceAfterMove_for_normal_piece_type_with_number_2_called_and_piece_is_dead_then_return_inGame_piece_with_location_23() {
        pieceNormal.state = PieceState.DEAD
        val pieceAfterMove = pieceNormal.pieceAfterMove(2)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 23)
    }

    @Test
    fun when_pieceAfterMove_for_normal_piece_type_with_number_3_called_and_piece_is_dead_then_return_inGame_piece_with_location_22() {
        pieceNormal.state = PieceState.DEAD
        val pieceAfterMove = pieceNormal.pieceAfterMove(3)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 22)
    }

    @Test
    fun when_pieceAfterMove_for_normal_piece_type_with_number_4_called_and_piece_is_dead_then_return_inGame_piece_with_location_21() {
        pieceNormal.state = PieceState.DEAD
        val pieceAfterMove = pieceNormal.pieceAfterMove(4)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 21)
    }

    @Test
    fun when_pieceAfterMove_for_normal_piece_type_with_number_5_called_and_piece_is_dead_then_return_inGame_piece_with_location_20() {
        pieceNormal.state = PieceState.DEAD
        val pieceAfterMove = pieceNormal.pieceAfterMove(5)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 20)
    }

    @Test
    fun when_pieceAfterMove_for_normal_piece_type_with_number_6_called_and_piece_is_dead_then_return_inGame_piece_with_location_19() {
        pieceNormal.state = PieceState.DEAD
        val pieceAfterMove = pieceNormal.pieceAfterMove(6)
        assertTrue(pieceAfterMove!!.state == PieceState.IN_GAME)
        assertTrue(pieceAfterMove.location == 19)
    }


    @Test
    fun when_pieceAfterMove_for_each_piece_type_called_then_return_piece_with_different_address() {
        assertTrue(pieceNormal.pieceAfterMove(2) !== pieceNormal)
        assertTrue(pieceReverse.pieceAfterMove(2) !== pieceReverse)
    }

    @Test
    fun when_pieceAfterMove_for_each_piece_type_won_called_then_return_null() {
        (1..7).forEach { index ->
            pieceNormal.state = PieceState.WON
            val normalAfterMove = pieceNormal.pieceAfterMove(index.toByte())
            assertTrue(normalAfterMove == null)

            pieceReverse.state = PieceState.WON
            val reverseAfterMove = pieceReverse.pieceAfterMove(index.toByte())
            assertTrue(reverseAfterMove == null)
        }
    }

    @Test
    fun when_pieceAfterMove_for_normal_type_in_game_state_with_location_18_called_and_dice_is_4_then_return_piece_with_location_14() {
        pieceNormal.state = PieceState.IN_GAME
        pieceNormal.location = 18
        val normalAfterMove = pieceNormal.pieceAfterMove(4)
        assertTrue(
            "pieceLocation after move is ${normalAfterMove!!.location}",
            normalAfterMove.location == 14
        )
    }

    @Test
    fun when_pieceAfterMove_for_reverse_type_in_game_state_with_location_18_called_and_dice_is_4_then_return_piece_with_location_22() {
        pieceReverse.state = PieceState.IN_GAME
        pieceReverse.location = 18
        val reverseAfterMove = pieceReverse.pieceAfterMove(4)
        assertTrue(
            "pieceLocation after move is ${reverseAfterMove!!.location}",
            reverseAfterMove.location == 22
        )
    }

    @Test
    fun when_pieceAfterMove_for_normal_and_in_game_with_location_in_home_range_and_number_is_6_then_return_null() {
        pieceNormal.state = PieceState.IN_GAME
        pieceNormal.location = 5
        val normalAfterMove = pieceNormal.pieceAfterMove(6)
        assertTrue(normalAfterMove == null)
    }

    @Test
    fun when_pieceAfterMove_for_normal_and_in_game_with_location_is_6_number_is_5_then_return_piece_with_location_1() {
        pieceNormal.state = PieceState.IN_GAME
        pieceNormal.location = 6
        val normalAfterMove = pieceNormal.pieceAfterMove(5)
        assertTrue(
            "pieceLocation after move is ${normalAfterMove!!.location}",
            normalAfterMove.location == 1
        )
    }

    @Test
    fun when_pieceAfterMove_for_normal_and_in_game_with_location_is_5_number_is_5_then_return_null() {
        pieceNormal.state = PieceState.IN_GAME
        pieceNormal.location = 5
        val normalAfterMove = pieceNormal.pieceAfterMove(5)
        assertTrue(normalAfterMove == null)
    }

    @Test
    fun when_pieceAfterMove_for_normal_and_in_game_with_location_is_1_number_is_1_then_return_null() {
        pieceNormal.state = PieceState.IN_GAME
        pieceNormal.location = 1
        val normalAfterMove = pieceNormal.pieceAfterMove(1)
        assertTrue(normalAfterMove == null)
    }

    @Test
    fun when_pieceAfterMove_for_reverse_and_in_game_with_location_in_home_range_and_number_is_6_then_return_null() {
        pieceReverse.state = PieceState.IN_GAME
        pieceReverse.location = 19
        val reverseAfterMove = pieceReverse.pieceAfterMove(6)
        assertTrue(reverseAfterMove == null)
    }


    @Test
    fun when_pieceAfterMove_for_reverse_and_in_game_with_location_is_19_number_is_5_then_return_piece_with_location_24() {
        pieceReverse.state = PieceState.IN_GAME
        pieceReverse.location = 19
        val reverseAfterMove = pieceReverse.pieceAfterMove(5)
        assertTrue(
            "pieceLocation after move is ${reverseAfterMove!!.location}",
            reverseAfterMove.location == 24
        )
    }

    @Test
    fun when_pieceAfterMove_for_reverse_and_in_game_with_location_is_20_number_is_5_then_return_null() {
        pieceReverse.state = PieceState.IN_GAME
        pieceReverse.location = 20
        val reverseAfterMove = pieceReverse.pieceAfterMove(5)
        assertTrue(reverseAfterMove == null)
    }

    @Test
    fun when_pieceAfterMove_for_reverse_and_in_game_with_location_is_24_number_is_1_then_return_null() {
        pieceReverse.state = PieceState.IN_GAME
        pieceReverse.location = 24
        val reverseAfterMove = pieceReverse.pieceAfterMove(1)
        assertTrue(reverseAfterMove == null)
    }

    @Test
    fun when_copy_called_then_new_piece_values_must_equal_to_current_piece_but_not_same() {
        val newPiece = pieceNormal.copy()
        assertTrue(newPiece == pieceNormal)
        assertFalse(newPiece === pieceNormal)
    }

}

@Component(modules = [SpyPieceModuleTest::class])
interface PieceComponentTest {
    fun inject(pieceTest: PieceTest)
}

@Module
open class SpyPieceModuleTest {
    @Provides
    @Named(REVERSE_PIECE)
    fun provideReversePiece(): Piece {
        return spy(PieceFactory.createReversePiece())
    }

    @Provides
    @Named(NORMAL_PIECE)
    fun provideNormalPiece(): Piece {
        return spy(PieceFactory.createNormalPiece())
    }
}