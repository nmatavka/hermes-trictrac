package utils

fun <A, B> bothExist(a: A?, b: B?): Pair<A, B>? = if (a != null && b != null) a to b else null