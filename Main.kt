var ticks = 0
val cache = MyCache()

var totalAsksCnt = 0

fun cacheRead8(address: Address) {
    ticks += 2
    cache.processData(address, 1, false)
    totalAsksCnt += 1
}

fun cacheRead16(address: Address) {
    ticks += 2
    cache.processData(address, 2, false)
    totalAsksCnt += 1
}

fun cacheWrite32(address: Address) {
    ticks += 2
    cache.processData(address, 4, true)
    totalAsksCnt += 1
}

fun multi() {
    ticks += 5
}

fun add() {
    ticks += 1
}

fun init() {
    ticks += 1
}

fun iteration() {
    ticks += 1 // итерация цикла
    ticks += 1 // (x++ / y++ / k++)
}

fun ext() {
    ticks += 1
}

fun endBits(num: Int, number: UInt) = number.shl(32 - num).shr(32 - num)

fun intToAddress(address: UInt): Address {
    val addressSet = endBits(cacheSetBits, address.shr(offsetBits)).toInt()
    val addressTag = endBits(tagBits,address.shr(offsetBits + cacheSetBits)).toInt()

    return Address(addressTag, addressSet)
}


const val M = 64
const val N = 60
const val K = 32
const val aBegPtr = 0
const val bBegPtr = M * K * 1 //массив элементов по 2 байта, поэтому в след. строке * 2
const val cBegPtr = M * K * 1 + K * N * 2 //массив элементов по 4 байта, учитываем это в (*)

fun main() {

    var pa = aBegPtr
    init() // pa
    var pc = cBegPtr
    init() // pc
    init() // y
    for (y in 0 until M) {
        init() // x
        for (x in 0 until N) {
            var pb = bBegPtr
            init() // pb
            init() // s
            init() // k
            for (k in 0 until K) {
                cacheRead8(intToAddress((pa + k * 1).toUInt()))
                multi()
                cacheRead16(intToAddress((pb + x * 2).toUInt()))
                add()
                pb += N * 2
                add()
                iteration()
            }
            cacheWrite32(intToAddress((pc + x * 4).toUInt()))
            iteration()
        }
        pa += K
        add()
        pc += N * 4 // (*)
        add()
        iteration()
    }
    ext() // exit function
    println("Total ticks: $ticks")
    println("Total memory accesses: $totalAsksCnt")
    println("Cache hits: ${cache.cacheHitCnt}")
    println("Success hits (%): ${cache.cacheHitCnt.toDouble() * 100 / totalAsksCnt}")
}