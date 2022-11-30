const val cacheWay = 2
const val cacheLineCount = 64
// const val cacheLineSize = 16

const val offsetBits = 4 // log(2, cacheLineSize)
const val cacheSetBits = 5 // log(2, cacheLineCount / cacheWay)
const val tagBits = 10


data class CacheLine(
    var valid: Boolean,
    var dirty: Boolean,
    var tag: Int
)

data class Address(
    var tag: Int,
    var set: Int
)

class MyCache {
    var cacheHitCnt = 0
    var cacheMissCnt = 0
    private val innerCacheData = List(cacheLineCount / cacheWay) { List (cacheWay) {CacheLine(false,  false, 0) }}
    private val lastUsed = MutableList(cacheLineCount / cacheWay) {0}
    fun processData(address : Address, sentDataSizeByte : Int, writing : Boolean) {
        var matched = -1;
        innerCacheData[address.set].forEachIndexed { index, cacheLine ->
            if (cacheLine.tag == address.tag && cacheLine.valid){
                ticks += 4 // 4 т.к. за 2 такта мы передаём данные от cpu
                matched = index
                cacheHitCnt += 1
                lastUsed[address.set] = index;
            }
        }
        if (matched == -1) {
            cacheMissCnt += 1
            matched = (lastUsed[address.set] + 1) % 2
            val interestingLine = innerCacheData[address.set][matched]
            ticks += 2 // кэш посылает запрос через 4 такта после miss, возможно нужно учитывать что команда началась 2 такта назад (тогда тут 2) иначе 4
            if (interestingLine.valid && interestingLine.dirty) {
                ticks += 100
                ticks += 1 // Эти 4 такта появляются во время
            }
            ticks += 100
            ticks += 7 //данные идут от памяти к кэшу
            innerCacheData[address.set][matched].dirty = false
            innerCacheData[address.set][matched].valid = true
            innerCacheData[address.set][matched].tag = address.tag
            lastUsed[address.set] = (lastUsed[address.set] + 1) % 2
        }
        ticks += 1//отправка данных обратно к процессору
        if (!writing && sentDataSizeByte == 4)
            ticks += 1//если 32 бита, то нужно 2 такта, а не 1
        if (writing)
            innerCacheData[address.set][matched].dirty = true
    }
}
