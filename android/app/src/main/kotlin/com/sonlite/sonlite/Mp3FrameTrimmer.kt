package com.sonlite.sonlite

import android.util.Log
import java.io.File
import java.io.RandomAccessFile

/// Découpage MP3 frame-aligné en pur Kotlin. Aucun ré-encodage : on
/// recopie les frames brutes correspondant à la plage demandée, en sautant
/// l'éventuel tag ID3v2. Fonctionne pour MPEG 1/2/2.5, Layer III, CBR et VBR.
object Mp3FrameTrimmer {

    private const val TAG = "Mp3FrameTrimmer"

    /// Bitrate (kbps) selon version × layer × index.
    /// [version][layer-1][bitrateIdx]
    private val BITRATES = arrayOf(
        // MPEG 1
        arrayOf(
            intArrayOf(0, 32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448, -1), // Layer I
            intArrayOf(0, 32, 48, 56,  64,  80,  96, 112, 128, 160, 192, 224, 256, 320, 384, -1), // Layer II
            intArrayOf(0, 32, 40, 48,  56,  64,  80,  96, 112, 128, 160, 192, 224, 256, 320, -1), // Layer III
        ),
        // MPEG 2 / 2.5
        arrayOf(
            intArrayOf(0, 32, 48, 56,  64,  80,  96, 112, 128, 144, 160, 176, 192, 224, 256, -1), // Layer I
            intArrayOf(0,  8, 16, 24,  32,  40,  48,  56,  64,  80,  96, 112, 128, 144, 160, -1), // Layer II
            intArrayOf(0,  8, 16, 24,  32,  40,  48,  56,  64,  80,  96, 112, 128, 144, 160, -1), // Layer III
        ),
    )

    /// Sample rate (Hz) [versionGroup][srIdx]
    /// versionGroup : MPEG1=0, MPEG2=1, MPEG2.5=2
    private val SAMPLE_RATES = arrayOf(
        intArrayOf(44100, 48000, 32000, -1),
        intArrayOf(22050, 24000, 16000, -1),
        intArrayOf(11025, 12000,  8000, -1),
    )

    /// Samples per frame [versionGroup][layer-1]
    private val SAMPLES_PER_FRAME = arrayOf(
        intArrayOf(384, 1152, 1152), // MPEG1
        intArrayOf(384, 1152,  576), // MPEG2
        intArrayOf(384, 1152,  576), // MPEG2.5
    )

    /// Renvoie le nombre de frames copiées.
    fun trim(inputPath: String, startMs: Long, endMs: Long, outputPath: String): Int {
        val src = File(inputPath)
        require(src.exists()) { "Fichier introuvable: $inputPath" }
        val totalSize = src.length()
        Log.i(TAG, "trim start=${startMs}ms end=${endMs}ms file=${totalSize}o")

        RandomAccessFile(src, "r").use { input ->
            val out = File(outputPath)
            out.parentFile?.mkdirs()

            // ── Étape 1 : sauter le tag ID3v2 (si présent)
            var pos = skipId3v2(input)
            input.seek(pos)
            Log.i(TAG, "après ID3v2 : pos=$pos")

            // ── Étape 2 : recopier les frames en accumulant la durée
            java.io.FileOutputStream(out).use { fos ->
                val buf = ByteArray(8192)
                var elapsedMs = 0.0
                var framesCopied = 0
                var framesScanned = 0
                var copying = false
                var firstFrameInfo: FrameInfo? = null

                while (pos < totalSize) {
                    input.seek(pos)
                    val frame = parseNextFrame(input, pos, totalSize) ?: break
                    framesScanned++
                    if (firstFrameInfo == null) firstFrameInfo = frame

                    val frameDurMs = frame.durationMs

                    // On commence à copier quand on dépasse startMs
                    if (!copying && elapsedMs + frameDurMs > startMs) {
                        copying = true
                    }
                    // On arrête quand on dépasse endMs
                    if (elapsedMs >= endMs) break

                    if (copying) {
                        // Recopie brute des bytes de la frame
                        input.seek(frame.offset)
                        var remaining = frame.size
                        while (remaining > 0) {
                            val n = input.read(buf, 0, minOf(buf.size, remaining))
                            if (n <= 0) break
                            fos.write(buf, 0, n)
                            remaining -= n
                        }
                        framesCopied++
                    }

                    elapsedMs += frameDurMs
                    pos = frame.offset + frame.size
                }

                Log.i(TAG, "trim terminé : $framesCopied/$framesScanned frames copiées, durée ~${elapsedMs.toInt()}ms")
                if (framesCopied == 0) {
                    out.delete()
                    throw IllegalStateException(
                        "Aucune frame MP3 copiée " +
                        "(scannées=$framesScanned, première frame: $firstFrameInfo). " +
                        "Le fichier n'est peut-être pas un MP3 valide."
                    )
                }
                return framesCopied
            }
        }
    }

    /// Saute le tag ID3v2 en début de fichier s'il existe.
    /// Format : "ID3" + 2 bytes version + 1 byte flags + 4 bytes synchsafe size.
    private fun skipId3v2(input: RandomAccessFile): Long {
        input.seek(0)
        val head = ByteArray(10)
        if (input.read(head) != 10) return 0L
        if (head[0] != 'I'.code.toByte() || head[1] != 'D'.code.toByte() || head[2] != '3'.code.toByte()) {
            return 0L
        }
        // Synchsafe int : 4 octets, 7 bits utiles chacun
        val size = ((head[6].toInt() and 0x7F) shl 21) or
                   ((head[7].toInt() and 0x7F) shl 14) or
                   ((head[8].toInt() and 0x7F) shl 7)  or
                   (head[9].toInt() and 0x7F)
        return 10L + size
    }

    private data class FrameInfo(
        val offset: Long,
        val size: Int,
        val durationMs: Double,
        val bitrate: Int,
        val sampleRate: Int,
        val version: Int,
        val layer: Int,
    ) {
        override fun toString(): String =
            "Frame(offset=$offset, size=${size}o, ${durationMs.toInt()}ms, ${bitrate}kbps, ${sampleRate}Hz, MPEG$version L$layer)"
    }

    /// Parse la frame MP3 commençant à [startPos] (ou la prochaine sync trouvée).
    /// Renvoie null si on n'a pas trouvé de frame valide avant fin de fichier.
    private fun parseNextFrame(input: RandomAccessFile, startPos: Long, totalSize: Long): FrameInfo? {
        var pos = startPos
        val header = ByteArray(4)

        while (pos < totalSize - 4) {
            input.seek(pos)
            if (input.read(header) != 4) return null

            // Sync : 11 bits à 1 (0xFFE0)
            val b0 = header[0].toInt() and 0xFF
            val b1 = header[1].toInt() and 0xFF
            if (b0 != 0xFF || (b1 and 0xE0) != 0xE0) {
                pos++
                continue
            }

            // Version : bits 19-20 (00=2.5, 10=2, 11=1)
            val versionBits = (b1 shr 3) and 0x03
            if (versionBits == 1) { pos++; continue } // réservé
            val versionGroup = when (versionBits) {
                3 -> 0 // MPEG1
                2 -> 1 // MPEG2
                0 -> 2 // MPEG2.5
                else -> { pos++; continue }
            }
            val versionNum = when (versionBits) { 3 -> 1; 2 -> 2; else -> 25 }

            // Layer : bits 17-18 (01=L3, 10=L2, 11=L1)
            val layerBits = (b1 shr 1) and 0x03
            if (layerBits == 0) { pos++; continue }
            val layer = when (layerBits) { 3 -> 1; 2 -> 2; 1 -> 3; else -> { pos++; continue } }

            // Bitrate : bits 12-15 du byte 2
            val b2 = header[2].toInt() and 0xFF
            val brIdx = (b2 shr 4) and 0x0F
            if (brIdx == 0 || brIdx == 15) { pos++; continue }
            val bitrateBlock = if (versionGroup == 0) 0 else 1 // MPEG1 vs MPEG2/2.5
            val bitrate = BITRATES[bitrateBlock][layer - 1][brIdx]
            if (bitrate <= 0) { pos++; continue }

            // Sample rate : bits 10-11
            val srIdx = (b2 shr 2) and 0x03
            if (srIdx == 3) { pos++; continue }
            val sampleRate = SAMPLE_RATES[versionGroup][srIdx]
            if (sampleRate <= 0) { pos++; continue }

            // Padding : bit 9
            val padding = (b2 shr 1) and 0x01

            // Taille de la frame
            val samples = SAMPLES_PER_FRAME[versionGroup][layer - 1]
            val frameSize = if (layer == 1) {
                ((12 * bitrate * 1000 / sampleRate) + padding) * 4
            } else {
                (samples / 8) * bitrate * 1000 / sampleRate + padding
            }
            if (frameSize <= 4 || pos + frameSize > totalSize) { pos++; continue }

            val durationMs = (samples.toDouble() * 1000.0) / sampleRate.toDouble()

            return FrameInfo(
                offset = pos,
                size = frameSize,
                durationMs = durationMs,
                bitrate = bitrate,
                sampleRate = sampleRate,
                version = versionNum,
                layer = layer,
            )
        }
        return null
    }
}
