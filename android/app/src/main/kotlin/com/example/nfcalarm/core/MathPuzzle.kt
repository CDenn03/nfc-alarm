package com.example.nfcalarm.core

import java.util.Random

/**
 * Two-group arithmetic puzzle, e.g. "(45 + 23) - (6 × 4)".
 * Harder than single-operation so it isn't a trivial half-asleep dismiss.
 */
object MathPuzzle {

    data class Puzzle(val expression: String, val answer: Int)

    private val rng = Random()

    fun generate(): Puzzle {
        val a = 10 + rng.nextInt(41) // 10..50
        val b = 10 + rng.nextInt(41)
        val addFirst = rng.nextBoolean()
        val g1 = if (addFirst) a + b else a - b
        val op1 = if (addFirst) "+" else "-"

        val c = 2 + rng.nextInt(11) // 2..12
        val d = 2 + rng.nextInt(11)
        val g2 = c * d

        val addSecond = rng.nextBoolean()
        val answer = if (addSecond) g1 + g2 else g1 - g2
        val op2 = if (addSecond) "+" else "-"

        return Puzzle("($a $op1 $b) $op2 ($c × $d)", answer)
    }
}
