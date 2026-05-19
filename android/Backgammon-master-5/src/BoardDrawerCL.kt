object BoardDrawerCL {
    fun draw(b: Board) {
        val sb = StringBuilder()
        sb.append("--1---2---3---4---5---6---BW----7---8---9--10--11--12--\n")
        for (i in 1..5) {
            drawTopStoneLine(i, b, sb)
            sb.append("|\n")
        }
        drawTopNumberLines(b, sb)
        sb.append("|\n")
        sb.append("=======================================================\n")
        drawBottomNumberLines(b, sb)
        sb.append("|\n")
        for (i in 5 downTo 1) {
            drawBottomStoneLine(i, b, sb)
            sb.append("|\n")
        }
        sb.append("-24--23--22--21--20--19---BB---18--17--16--15--14--13--\n")
        print(sb)
    }

    private fun drawBottomStoneLine(i: Int, b: Board, sb: StringBuilder) {
        for (j in 23 downTo 18) {
            drawSegment(i, j, b, sb)
        }
        sb.append("|| ")
        if (b.getBarCount(Stone.Color.BLACK) >= i) {
            sb.append(Stone.BLACK)
        } else {
            sb.append(' ')
        }
        sb.append(" |")
        for (j in 17 downTo 12) {
            drawSegment(i, j, b, sb)
        }
    }

    private fun drawTopStoneLine(i: Int, b: Board, sb: StringBuilder) {
        for (j in 0..5) {
            drawSegment(i, j, b, sb)
        }
        sb.append("|| ")
        if (b.getBarCount(Stone.Color.WHITE) >= i) {
            sb.append(Stone.WHITE)
        } else {
            sb.append(' ')
        }
        sb.append(" |")
        for (j in 6..11) {
            drawSegment(i, j, b, sb)
        }
    }

    private fun drawBottomNumberLines(b: Board, sb: StringBuilder) {
        for (j in 23 downTo 18) {
            drawSegmentNumberH(j, b, sb)
        }
        sb.append("|| ")
        if (b.getBarCount(Stone.Color.BLACK) >= 10) {
            sb.append(1)
        } else if (b.getBarCount(Stone.Color.BLACK) > 5) {
            sb.append(b.getBarCount(Stone.Color.BLACK))
        } else {
            sb.append(' ')
        }
        sb.append(" |")
        for (j in 17 downTo 12) {
            drawSegmentNumberH(j, b, sb)
        }
        sb.append("|\n")
        for (j in 23 downTo 18) {
            drawSegmentNumberL(j, b, sb)
        }
        sb.append("|| ")
        if (b.getBarCount(Stone.Color.BLACK) >= 10) {
            sb.append(b.getBarCount(Stone.Color.BLACK) - 10)
        } else {
            sb.append(' ')
        }
        sb.append(" |")
        for (j in 17 downTo 12) {
            drawSegmentNumberL(j, b, sb)
        }
    }

    private fun drawTopNumberLines(b: Board, sb: StringBuilder) {
        for (j in 0..5) {
            drawSegmentNumberH(j, b, sb)
        }
        sb.append("|| ")
        if (b.getBarCount(Stone.Color.WHITE) >= 10) {
            sb.append(1)
        } else if (b.getBarCount(Stone.Color.WHITE) > 5) {
            sb.append(b.getBarCount(Stone.Color.WHITE))
        } else {
            sb.append(' ')
        }
        sb.append(" |")
        for (j in 6..11) {
            drawSegmentNumberH(j, b, sb)
        }
        sb.append("|\n")
        for (j in 0..5) {
            drawSegmentNumberL(j, b, sb)
        }
        sb.append("|| ")
        if (b.getBarCount(Stone.Color.WHITE) >= 10) {
            sb.append(b.getBarCount(Stone.Color.WHITE) - 10)
        } else {
            sb.append(' ')
        }
        sb.append(" |")
        for (j in 6..11) {
            drawSegmentNumberL(j, b, sb)
        }
    }

    private fun drawSegmentNumberH(j: Int, b: Board, sb: StringBuilder) {
        sb.append("| ")
        if (b.getStoneCount(j) >= 10) {
            sb.append(1)
        } else if (b.getStoneCount(j) > 5) {
            sb.append(b.getStoneCount(j))
        } else {
            sb.append(' ')
        }
        sb.append(" ")
    }

    private fun drawSegmentNumberL(j: Int, b: Board, sb: StringBuilder) {
        sb.append("| ")
        if (b.getStoneCount(j) >= 10) {
            sb.append(b.getStoneCount(j) - 10)
        } else {
            sb.append(' ')
        }
        sb.append(" ")
    }

    private fun drawSegment(i: Int, j: Int, b: Board, sb: StringBuilder) {
        sb.append("| ")
        if (b.getStoneCount(j) >= i) {
            sb.append(b.getStone(j))
        } else {
            sb.append(' ')
        }
        sb.append(" ")
    }
}
