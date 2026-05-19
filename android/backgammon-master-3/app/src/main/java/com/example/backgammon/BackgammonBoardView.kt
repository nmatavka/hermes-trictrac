package com.example.backgammon

import android.content.Context
import android.graphics.*
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.widget.Toast
import androidx.core.content.ContextCompat
import com.google.firebase.database.DataSnapshot
import kotlin.math.abs

class BackgammonBoardView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    /* ─────────────────────────────────────────────
       1.  פונקציית-עזר לגישה בטוחה למערך הלוח
    ────────────────────────────────────────────── */
    private fun bs(i: Int): Pair<Int, Boolean>? =
        boardState.getOrNull(i)     // null אם i מחוץ ל-0..28

    /* ─────────  משתנים גלובליים  ───────── */
    private var dice1: Drawable = ContextCompat.getDrawable(context, R.drawable.dice_1)!!
    private var dice2: Drawable = ContextCompat.getDrawable(context, R.drawable.dice_1)!!
    private var lastTouchX = 0f
    private var lastTouchY = 0f
    private var isWhiteTurn = true
    private var currentPlayerName = ""

    private var dice1Value = 0
    private var dice2Value = 0
    private var availableMoves = mutableListOf<Int>()
    private var initialDiceRoll = false

    private val triangleAreas = Array(24) { RectF() }
    private val moveHistory = mutableListOf<Move>()
    private var waitForDoneButton = false
    private var currentTurnMoves = 0

    /*  פאיֶר(count, isWhite) לכל עמדה (0-23),
        24 = בר שחור, 25 = בר לבן,
        26-27 = “יצאו”  */
    private val boardState = Array(29) { pos ->
        when (pos) {
            0  -> Pair(2,  true)
            5  -> Pair(5, false)
            7  -> Pair(3, false)
            11 -> Pair(5,  true)
            12 -> Pair(5, false)
            16 -> Pair(3,  true)
            18 -> Pair(5,  true)
            23 -> Pair(2, false)
            24 -> Pair(0, false)   // Bar שחור – תמיד שחור
            25 -> Pair(0,  true)   // Bar לבן  – תמיד לבן
            else -> Pair(0,  true)
        }
    }

    data class Move(
        val from: Int,
        val to: Int,
        val eatenChecker: Pair<Int, Boolean>?,
        val usedDiceValues: List<Int>
    )

    /* ─────────────────────────────────────────────
       2.  ציורים (onDraw, drawCheckers) – ללא שינוי
    ────────────────────────────────────────────── */
    // ... (שאר onDraw ו-drawCheckers כבקוד הקיים – לא השתנה) ...

    /* ─────────────────────────────────────────────
       3.  getPositionFromTouch – מתאים ל-Bars בצד שמאל
    ────────────────────────────────────────────── */
    /** 0-23 משולשים, 24 Bar-שחור, 25 Bar-לבן, ‎-1 חוץ  */
    private fun getPositionFromTouch(x: Float, y: Float): Int {
        val w = width.toFloat()
        val h = height.toFloat()
        val outer = 120f
        val triW = (w - outer * 2) / 12
        val checkerR = triW * 0.2f
        val barX = outer * 0.6f     // שני ה-Bars מצוירים בצד שמאל

        // מחוץ למסך
        if (x !in 0f..w || y !in 0f..h) return -1

        // Bar שחור (חצי עליון)
        if (x in (barX - checkerR)..(barX + checkerR) && y in outer..(h / 2))
            return 24

        // Bar לבן  (חצי תחתון)
        if (x in (barX - checkerR)..(barX + checkerR) && y in (h / 2)..(h - outer))
            return 25

        // משולשים
        for (i in 0..23)
            if (triangleAreas[i].contains(x, y)) return i

        return -1
    }

    /* ─────────────────────────────────────────────
       4.  getValidBarEntriesForDice – נוסחה חדשה!
    ────────────────────────────────────────────── */
    private fun getValidBarEntriesForDice(isWhite: Boolean, dice: List<Int>): List<Int> {
        val entries = mutableListOf<Int>()
        val barPos = if (isWhite) 25 else 24
        if (boardState[barPos].first == 0) return entries      // אין חיילים

        dice.distinct().forEach { d ->
            val entryPos = if (isWhite) 24 - d else d - 1      // ← נוסחה מעודכנת
            if (entryPos in 0..23) {
                val spot = boardState[entryPos]
                if (spot.first <= 1 || spot.second == isWhite) entries += entryPos
            }
        }
        return entries
    }

    /* ─────────────────────────────────────────────
       5.  moveChecker – עם בדיקות בטיחות
    ────────────────────────────────────────────── */
    private fun moveChecker(from: Int, to: Int, opts: List<Int>) {

        // חוץ-לוח (ולא 99) → ביטול
        if (to !in 0..23 && to != 99) {
            Toast.makeText(context, "מהלך לא חוקי", Toast.LENGTH_SHORT).show()
            return
        }

        val src = bs(from) ?: return
        val cnt = src.first
        val isWhite = src.second
        if (cnt == 0) return

        val isBarEntry = (from == 25 && isWhite) || (from == 24 && !isWhite)
        val bearing    = opts.contains(99) && (to == 99 || to >= 24 || to < 0)

        /* --------------------------------------------------
           5A. Bearing-off
        -------------------------------------------------- */
        if (bearing) {
            val dist = if (isWhite) 24 - from else from + 1
            val exact = availableMoves.find { it == dist }
            val larger = availableMoves.filter { it > dist }.minOrNull()

            when {
                exact != null -> availableMoves.remove(exact)
                larger != null && isLastFarthestChecker(from, isWhite) -> availableMoves.remove(larger)
                else -> { Toast.makeText(context, "אין מספר מתאים", Toast.LENGTH_SHORT).show(); return }
            }

            boardState[from] = Pair(cnt - 1, isWhite)
            val outPos = if (isWhite) 26 else 27
            boardState[outPos] = Pair(boardState[outPos].first + 1, isWhite)
            moveHistory += Move(from, 99, null, listOf(dist))
            if (isAllBornOff(isWhite)) gameOver(isWhite)
            afterMoveCommon(); return
        }

        /* --------------------------------------------------
           5B. חישוב מרחק
        -------------------------------------------------- */
        val dist = when {
            isBarEntry && isWhite  -> 24 - to
            isBarEntry && !isWhite -> to + 1
            else -> abs(to - from)
        }

        // צריכת קוביות (הגיון כמו קודם, מקוצר מעט)
        when {
            availableMoves.contains(dist) -> availableMoves.remove(dist)
            dice1Value != dice2Value &&
                    dist == dice1Value + dice2Value &&
                    availableMoves.containsAll(listOf(dice1Value, dice2Value)) -> {
                availableMoves.remove(dice1Value); availableMoves.remove(dice2Value)
            }
            dice1Value == dice2Value && dist % dice1Value == 0 -> {
                val need = dist / dice1Value
                if (availableMoves.count { it == dice1Value } < need) {
                    Toast.makeText(context, "אין מספיק דאבלים", Toast.LENGTH_SHORT).show(); return
                }
                repeat(need) { availableMoves.remove(dice1Value) }
            }
            else -> { Toast.makeText(context, "מרחק לא תואם קוביות", Toast.LENGTH_SHORT).show(); return }
        }

        /* --------------------------------------------------
           5C. ביצוע המהלך (כולל אכילה)
        -------------------------------------------------- */
        var eaten: Pair<Int, Boolean>? = null
        if (to in 0..23) {
            val dst = bs(to) ?: Pair(0, isWhite)
            when {
                dst.first == 1 && dst.second != isWhite -> {
                    eaten = Pair(to, dst.second)
                    val bar = if (dst.second) 25 else 24
                    boardState[bar] = Pair(boardState[bar].first + 1, dst.second)
                    boardState[to] = Pair(1, isWhite)
                }
                dst.first == 0 || dst.second == isWhite ->
                    boardState[to] = Pair(dst.first + 1, isWhite)
                else -> { Toast.makeText(context, "חסום", Toast.LENGTH_SHORT).show(); return }
            }
        }

        boardState[from] = Pair(cnt - 1, isWhite)
        moveHistory += Move(from, to, eaten, listOf(dist))
        afterMoveCommon()
    }

    /* ─────────────────────────────────────────────
       6. afterMoveCommon – קריאה משותפת
    ────────────────────────────────────────────── */
    private fun afterMoveCommon() {
        currentTurnMoves++
        if (availableMoves.isEmpty()) {
            waitForDoneButton = true
            Toast.makeText(context, "מהלכים הושלמו – DONE", Toast.LENGTH_SHORT).show()
        }
        updateFirebase()
        invalidate()
    }

    // פונקציה לבדיקה אם כל החיילים יצאו
    private fun isAllBornOff(isWhite: Boolean): Boolean {
        // בדיקה שאין יותר חיילים על הלוח
        for (i in 0..23) {
            if (boardState[i].first > 0 && boardState[i].second == isWhite) {
                return false
            }
        }

        // בדיקה שאין חיילים בבר
        val barPosition = if (isWhite) 25 else 24
        if (boardState[barPosition].first > 0 && boardState[barPosition].second == isWhite) {
            return false
        }

        return true
    }

    // פונקציה לטיפול בסיום משחק
    private fun gameOver(winnerIsWhite: Boolean) {
        val message = if (winnerIsWhite) "השחקן הלבן ניצח!" else "השחקן השחור ניצח!"
        Toast.makeText(context, message, Toast.LENGTH_LONG).show()
        // כאן אפשר להוסיף קוד נוסף שיקרה בסיום המשחק
    }    private fun showCurrentTurn() {
        val message = if (isWhiteTurn) "תור השחקן הלבן" else "תור השחקן השחור"
    }

    private fun switchTurn() {
        isWhiteTurn = !isWhiteTurn
        availableMoves.clear()  // נקה את המהלכים הזמינים
        moveHistory.clear()  // נקה את היסטוריית המהלכים של התור הקודם
        currentTurnMoves = 0 // איפוס מספר המהלכים בתור
        initialDiceRoll = false  // איפוס לתחילת תור חדש
        waitForDoneButton = false // איפוס מצב DONE
        selectedCheckerPosition = null // איפוס בחירת חייל
        Log.d("Backgammon", "מעבר תור ל${if (isWhiteTurn) "לבן" else "שחור"}")
        showCurrentTurn()
    }
    // פונקציה לבדיקה אם יש חיילים רחוקים יותר
    private fun hasCheckersFartherBack(position: Int, isWhite: Boolean): Boolean {
        if (isWhite) {
            // עבור שחקן לבן, בדוק אם יש חיילים לפני העמדה הנוכחית
            for (i in 0 until position) {
                if (boardState[i].first > 0 && boardState[i].second == isWhite) {
                    return true
                }
            }
        } else {
            // עבור שחקן שחור, בדוק אם יש חיילים אחרי העמדה הנוכחית
            for (i in position + 1..23) {
                if (boardState[i].first > 0 && !boardState[i].second) {
                    return true
                }
            }
        }
        return false
    }
    private fun isLastFarthestChecker(position: Int, isWhite: Boolean): Boolean {
        Log.d("Backgammon", "בודק אם חייל בעמדה $position הוא הרחוק ביותר. צבע: ${if (isWhite) "לבן" else "שחור"}")

        if (isWhite) {
            // עבור שחקן לבן, בדוק רק אם יש חיילים לבנים במיקומים פנימיים יותר (0-17)
            // כשנמצאים בבית (עמדות 18-23), בדיקה אחרת
            if (position >= 18) {
                // בודקים אם יש חיילים לבנים בעמדות נמוכות יותר מהעמדה הנוכחית
                for (i in 18 until position) {
                    if (boardState[i].first > 0 && boardState[i].second == isWhite) {
                        Log.d("Backgammon", "נמצא חייל לבן בעמדה $i שרחוק יותר מעמדה $position")
                        return false
                    }
                }
                // אם הגענו לכאן, זה אומר שאין חיילים בעמדות נמוכות יותר בתוך הבית
                Log.d("Backgammon", "עמדה $position היא העמדה הנמוכה ביותר עם חיילים לבנים בבית")
                return true
            } else {
                // מחוץ לבית - לא ניתן להוציא
                return false
            }
        } else {
            // עבור שחקן שחור, בדוק רק אם יש חיילים שחורים במיקומים פנימיים יותר (6-23)
            // כשנמצאים בבית (עמדות 0-5), בדיקה אחרת
            if (position <= 5) {
                // בודקים אם יש חיילים שחורים בעמדות גבוהות יותר מהעמדה הנוכחית
                for (i in position + 1..5) {
                    if (boardState[i].first > 0 && !boardState[i].second) {
                        Log.d("Backgammon", "נמצא חייל שחור בעמדה $i שרחוק יותר מעמדה $position")
                        return false
                    }
                }
                // אם הגענו לכאן, זה אומר שאין חיילים בעמדות גבוהות יותר בתוך הבית
                Log.d("Backgammon", "עמדה $position היא העמדה הגבוהה ביותר עם חיילים שחורים בבית")
                return true
            } else {
                // מחוץ לבית - לא ניתן להוציא
                return false
            }
        }
    }

    private fun logBoardState() {
        Log.d("Backgammon", "מצב הלוח:")
        for (i in 0..27) {
            if (boardState[i].first > 0) {
                Log.d("Backgammon", "עמדה $i: ${boardState[i].first} חיילים, צבע: ${if (boardState[i].second) "לבן" else "שחור"}")
            }
        }
    }

    // פונקציה חדשה להחזרת מהלך אחורה
    fun undoLastMove() {
        if (moveHistory.isEmpty()) {
            Toast.makeText(context, "אין מהלכים לביטול", Toast.LENGTH_SHORT).show()
            return
        }

        // בדיקה שלא ניסו לבטל יותר מהמהלכים שבוצעו בתור הנוכחי
        if (currentTurnMoves <= 0) {
            Toast.makeText(context, "לא ניתן לבטל יותר מהלכים בתור זה", Toast.LENGTH_SHORT).show()
            return
        }

        // קח את המהלך האחרון
        val lastMove = moveHistory.removeAt(moveHistory.size - 1)
        Log.d("Backgammon", "מבטל מהלך: מעמדה ${lastMove.from} לעמדה ${lastMove.to}")

        // החזר את החייל למצב הקודם
        val isWhite = if (lastMove.to == 99) boardState[lastMove.from].second else boardState[lastMove.to].second

        // פחות חייל במיקום החדש
        if (lastMove.to == 99) { // אם זו הייתה הוצאת חייל
            val bearOffPosition = if (isWhite) 26 else 27
            boardState[bearOffPosition] = Pair(boardState[bearOffPosition].first - 1, isWhite)
        } else {
            boardState[lastMove.to] = Pair(boardState[lastMove.to].first - 1, isWhite)
        }

        // יותר חייל במיקום המקורי
        boardState[lastMove.from] = Pair(boardState[lastMove.from].first + 1, isWhite)

        // אם זה היה מהלך שאכל חייל
        lastMove.eatenChecker?.let { (position, color) ->
            val barPosition = if (color) 25 else 24
            // פחות חייל בבר
            boardState[barPosition] = Pair(boardState[barPosition].first - 1, color)
            // יותר חייל במיקום המקורי
            boardState[position] = Pair(boardState[position].first + 1, color)
        }

        // החזר את ערך הקובייה ששימשה למהלך
        availableMoves.addAll(lastMove.usedDiceValues)

        // הפחת את מספר המהלכים בתור הנוכחי
        currentTurnMoves--

        // הצג כמה מהלכים עוד ניתן לבטל
        if (currentTurnMoves > 0) {
            Toast.makeText(context, "ניתן לבטל עוד $currentTurnMoves מהלכים", Toast.LENGTH_SHORT).show()
        }

        // אם כבר הסתיים התור, לא צריך לחכות לDONE
        if (waitForDoneButton && availableMoves.size > 0) {
            waitForDoneButton = false
        }

        invalidate()
    }

    // פונקציה לסנכרון מצב המשחק עם Firebase
    fun syncWithFirebase(snapshot: DataSnapshot) {
        snapshot.child("dice1").getValue(Int::class.java)?.let {
            dice1Value = it
        }
        snapshot.child("dice2").getValue(Int::class.java)?.let {
            dice2Value = it
        }

        snapshot.child("currentTurn").getValue(String::class.java)?.let {
            isWhiteTurn = it == "white"
        }

        val boardStateData = snapshot.child("boardState")
        if (boardStateData.exists()) {
            val newBoard = boardStateData.children.mapIndexed { index, snapshot ->
                val isWhite = snapshot.child("isWhite").getValue(Boolean::class.java) ?: true
                val count = snapshot.child("count").getValue(Int::class.java) ?: 0
                Pair(count, isWhite)
            }

            for (i in newBoard.indices) {
                if (i < boardState.size) {
                    boardState[i] = newBoard[i]
                }
            }
        }

        loadDiceImages(context)
        invalidate()
    }

    // מעדכן את מצב המשחק ב-Firebase אחרי מהלך
    private fun updateFirebase() {
        val boardStateMap = boardState.mapIndexed { index, pair ->
            "position_$index" to mapOf(
                "count" to pair.first,
                "isWhite" to pair.second
            )
        }.toMap()

        MultiplayerManager.updateGameState(
            mapOf(
                "dice1" to dice1Value,
                "dice2" to dice2Value,
                "currentTurn" to if (isWhiteTurn) "white" else "black",
                "boardState" to boardStateMap
            )
        )
    }

    // פונקציה לסיום התור עם סנכרון Firebase
    fun finishTurn() {
        Log.d("Backgammon", "finishTurn called - isWhiteTurn: $isWhiteTurn, availableMoves: $availableMoves, dice1Value: $dice1Value, dice2Value: $dice2Value")

        // בדיקה ראשונה: אם לא הטילו קוביות
        if (!initialDiceRoll) {
            Toast.makeText(context, "יש להטיל קוביות תחילה", Toast.LENGTH_SHORT).show()
            return
        }

        // בדיקה שנייה: אם יש חיילים בבר - הם חייבים להיכנס קודם
        val barPosition = if (isWhiteTurn) 25 else 24
        if (boardState[barPosition].first > 0 && boardState[barPosition].second == isWhiteTurn) {
            val validBarMoves = getValidBarEntriesForDice(isWhiteTurn, availableMoves)
            if (validBarMoves.isNotEmpty()) {
                Toast.makeText(context, "חייב להכניס את החיילים מהבר קודם", Toast.LENGTH_SHORT).show()
                return
            } else {
                // אין אפשרויות כניסה מהבר - סיום תור אוטומטי מותר
                Log.d("Backgammon", "אין אפשרות להכניס חיילים מהבר - סיום תור אוטומטי")
                switchTurn()
                updateFirebase()
                invalidate()
                return
            }
        }

        // בדיקה שלישית: אם יש עוד מהלכים אפשריים
        if (availableMoves.isNotEmpty()) {
            val hasValidMoves = playerHasAnyValidMoves(isWhiteTurn, availableMoves)

            if (hasValidMoves) {
                // יש מהלכים אפשריים - השחקן צריך לבצע אותם או ללחוץ "Done" שוב לאישור סיום מוקדם
                if (!waitForDoneButton) {
                    waitForDoneButton = true
                    val remainingMovesText = if (dice1Value == dice2Value) {
                        "יש לך עוד ${availableMoves.size} מהלכים דאבל (${dice1Value}). לחץ 'סיום' שוב אם אין מהלכים חוקיים."
                    } else {
                        "יש לך עוד מהלכים: ${availableMoves.joinToString(", ")}. לחץ 'סיום' שוב אם אין מהלכים חוקיים."
                    }
                    Toast.makeText(context, remainingMovesText, Toast.LENGTH_LONG).show()
                    return
                } else {
                    // לחצו "Done" פעמיים - מאפשרים סיום תור גם עם מהלכים שנותרו
                    Log.d("Backgammon", "שחקן בחר לסיים תור למרות מהלכים זמינים")
                    waitForDoneButton = false
                }
            } else {
                // אין מהלכים אפשריים למרות קוביות זמינות - סיום תור אוטומטי
                Log.d("Backgammon", "אין מהלכים אפשריים עם קוביות זמינות - סיום תור אוטומטי")
            }
        }

        // כל הבדיקות עברו - סיים תור
        Log.d("Backgammon", "סיום תור של שחקן ${if (isWhiteTurn) "לבן" else "שחור"}")
        switchTurn()
        waitForDoneButton = false
        updateFirebase()
        invalidate()
    }

    // פונקציה חדשה לבדיקה אם לשחקן יש מהלכים חוקיים כלשהם
    private fun playerHasAnyValidMoves(isPlayerWhite: Boolean, currentDice: List<Int>): Boolean {
        if (currentDice.isEmpty()) {
            return false // אין קוביות, אין מהלכים
        }

        // בדוק קודם את עמדת הבר של השחקן
        val barPosition = if (isPlayerWhite) 25 else 24
        if (boardState[barPosition].first > 0 && boardState[barPosition].second == isPlayerWhite) {
            val barMoves = getValidBarEntriesForDice(isPlayerWhite, currentDice)
            if (barMoves.isNotEmpty()) {
                return true // יש מהלכים מהבר
            }
            // אם אין מהלכים מהבר והשחקן על הבר, הוא לא יכול לבצע מהלכים אחרים
            return false 
        }

        // עבור על כל המשבצות הרגילות
        for (position in 0..23) {
            if (boardState[position].first > 0 && boardState[position].second == isPlayerWhite) {
                val possibleMoves = getValidMovesForDice(position, isPlayerWhite, currentDice)
                if (possibleMoves.isNotEmpty()) {
                    return true // נמצא מהלך חוקי
                }
            }
        }
        return false // לא נמצאו מהלכים חוקיים
    }

    // פונקציה להגדרת השם של השחקן הנוכחי
    fun setCurrentPlayerName(playerName: String) {
        currentPlayerName = playerName
        // השחקן תמיד יתחיל כלבן
        isWhiteTurn = true
        invalidate()
    }
    
    // פונקציה לקבלת השם של השחקן הנוכחי
    fun getCurrentPlayerName(): String {
        return currentPlayerName
    }
}

