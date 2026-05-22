package com.sonlite.sonlite

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

class MainActivity : AudioServiceFragmentActivity() {

    companion object {
        private const val TAG = "SonLiteYtDlp"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var progressSink: EventChannel.EventSink? = null

    @Volatile
    private var ytdlpInitialized = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "com.sonlite/ytdlp_progress")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    progressSink = sink
                }

                override fun onCancel(args: Any?) {
                    progressSink = null
                }
            })

        MethodChannel(messenger, "com.sonlite/ffmpeg")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "execute" -> {
                        val args = call.argument<List<String>>("args")!!
                        Thread {
                            try {
                                ensureInitialized()
                                val rc = runFFmpeg(args)
                                mainHandler.post { result.success(rc) }
                            } catch (e: Throwable) {
                                Log.e(TAG, "ffmpeg execute: ÉCHEC", e)
                                mainHandler.post { result.error("FFMPEG_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(messenger, "com.sonlite/audio_editor")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "trim" -> {
                        val inputPath = call.argument<String>("inputPath")!!
                        val startMs   = (call.argument<Number>("startMs")!!).toLong()
                        val endMs     = (call.argument<Number>("endMs")!!).toLong()
                        val outputPath = call.argument<String>("outputPath")!!
                        Thread {
                            try {
                                trimAudio(inputPath, startMs, endMs, outputPath)
                                mainHandler.post { result.success(null) }
                            } catch (e: Throwable) {
                                Log.e(TAG, "audio_editor trim: ÉCHEC", e)
                                mainHandler.post { result.error("TRIM_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "split" -> {
                        val inputPath = call.argument<String>("inputPath")!!
                        @Suppress("UNCHECKED_CAST")
                        val segments = call.argument<List<Map<String, Any>>>("segments")!!
                        Thread {
                            try {
                                for (seg in segments) {
                                    val startMs    = (seg["startMs"] as Number).toLong()
                                    val endMs      = (seg["endMs"] as Number).toLong()
                                    val outputPath = seg["outputPath"] as String
                                    trimAudio(inputPath, startMs, endMs, outputPath)
                                }
                                mainHandler.post { result.success(null) }
                            } catch (e: Throwable) {
                                Log.e(TAG, "audio_editor split: ÉCHEC", e)
                                mainHandler.post { result.error("SPLIT_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    "toMp3" -> {
                        val inputPath  = call.argument<String>("inputPath")!!
                        val outputPath = call.argument<String>("outputPath")!!
                        Thread {
                            try {
                                ensureInitialized()
                                val bin = findFfmpegBin()
                                    ?: throw IllegalStateException("Binaire FFmpeg introuvable — init() a peut-être échoué")
                                runFfmpegBin(bin, listOf(
                                    "-i", inputPath,
                                    "-acodec", "libmp3lame",
                                    "-q:a", "2",
                                    "-y", outputPath,
                                ))
                                mainHandler.post { result.success(null) }
                            } catch (e: Throwable) {
                                Log.e(TAG, "audio_editor toMp3: ÉCHEC", e)
                                mainHandler.post { result.error("MP3_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(messenger, "com.sonlite/ytdlp")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> handleUpdate(result)
                    "getInfo" -> handleGetInfo(call.argument<String>("url")!!, result)
                    "download" -> handleDownload(
                        call.argument<String>("url")!!,
                        call.argument<String>("outputTemplate")!!,
                        result,
                    )
                    else -> result.notImplemented()
                }
            }
    }

    // ── Helpers FFmpeg ────────────────────────────────────────────────────────

    private fun findFfmpegBin(): File? {
        val noBackup = applicationContext.noBackupFilesDir
        val primary = File(noBackup, "packages/ffmpeg/bin/ffmpeg")
        if (primary.exists()) return primary
        // Fallback : recherche récursive dans le dossier packages
        File(noBackup, "packages").walk()
            .find { it.name == "ffmpeg" && it.canExecute() }
            ?.let { return it }
        return null
    }

    private fun runFfmpegBin(bin: File, args: List<String>): Int {
        val cmd = listOf(bin.absolutePath) + args
        Log.d(TAG, "ffmpeg: ${cmd.joinToString(" ")}")
        val stderr = StringBuilder()
        val process = ProcessBuilder(cmd)
            .redirectErrorStream(true)
            .apply { environment()["LD_LIBRARY_PATH"] = applicationInfo.nativeLibraryDir }
            .start()
        process.inputStream.bufferedReader().forEachLine {
            Log.d(TAG, "ffmpeg: $it")
            stderr.appendLine(it)
        }
        val rc = process.waitFor()
        if (rc != 0) throw RuntimeException("FFmpeg a échoué (rc=$rc)\n${stderr.take(400)}")
        return rc
    }

    /// Compatibilité : canal com.sonlite/ffmpeg (conservé mais non utilisé par l'éditeur).
    private fun runFFmpeg(args: List<String>): Int {
        val bin = findFfmpegBin()
            ?: throw IllegalStateException("Binaire FFmpeg introuvable")
        return runFfmpegBin(bin, args)
    }

    // ── Helpers MediaExtractor / MediaMuxer ───────────────────────────────────

    private fun selectAudioTrack(extractor: MediaExtractor): Int {
        for (i in 0 until extractor.trackCount) {
            val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                extractor.selectTrack(i)
                return i
            }
        }
        throw IllegalArgumentException("Aucune piste audio trouvée dans le fichier")
    }

    private fun trimAudio(inputPath: String, startMs: Long, endMs: Long, outputPath: String) {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)
        val format = extractor.getTrackFormat(selectAudioTrack(extractor))

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val muxTrack = muxer.addTrack(format)
        extractor.seekTo(startMs * 1_000L, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)
        muxer.start()

        val buf = ByteBuffer.allocate(1 * 1024 * 1024)
        val info = MediaCodec.BufferInfo()

        while (true) {
            info.size = extractor.readSampleData(buf, 0)
            if (info.size < 0) break
            val sampleUs = extractor.sampleTime
            if (sampleUs > endMs * 1_000L) break
            if (sampleUs >= startMs * 1_000L) {
                info.offset = 0
                info.presentationTimeUs = sampleUs - startMs * 1_000L
                info.flags = extractor.sampleFlags
                muxer.writeSampleData(muxTrack, buf, info)
            }
            extractor.advance()
        }

        muxer.stop()
        muxer.release()
        extractor.release()
    }

    /// Initialise yt-dlp + ffmpeg (extrait le runtime Python au premier appel).
    /// Doit être appelé depuis un thread d'arrière-plan.
    private fun ensureInitialized() {
        if (ytdlpInitialized) return
        synchronized(this) {
            if (ytdlpInitialized) return
            Log.i(TAG, "init: extraction du runtime Python (peut être long)...")
            YoutubeDL.getInstance().init(applicationContext)
            FFmpeg.getInstance().init(applicationContext)
            ytdlpInitialized = true
            Log.i(TAG, "init: terminé")
        }
    }

    /// Met à jour yt-dlp vers la dernière version stable depuis GitHub.
    private fun handleUpdate(result: MethodChannel.Result) {
        Thread {
            try {
                Log.i(TAG, "update: initialisation...")
                ensureInitialized()
                Log.i(TAG, "update: téléchargement de la dernière version yt-dlp...")
                val status = YoutubeDL.getInstance().updateYoutubeDL(
                    applicationContext,
                    YoutubeDL.UpdateChannel.STABLE,
                )
                Log.i(TAG, "update: terminé — $status")
                mainHandler.post { result.success(status?.name ?: "UNKNOWN") }
            } catch (e: Throwable) {
                Log.e(TAG, "update: ÉCHEC", e)
                mainHandler.post { result.error("UPDATE_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun handleGetInfo(url: String, result: MethodChannel.Result) {
        Thread {
            try {
                Log.i(TAG, "getInfo: initialisation...")
                ensureInitialized()
                Log.i(TAG, "getInfo: extraction des métadonnées de $url")
                val info = YoutubeDL.getInstance().getInfo(url)
                Log.i(TAG, "getInfo: OK — titre=${info.title}")
                val map = mapOf(
                    "title" to info.title,
                    "duration" to info.duration,
                    "thumbnail" to info.thumbnail,
                    "uploader" to info.uploader,
                    "id" to info.id,
                )
                mainHandler.post { result.success(map) }
            } catch (e: Throwable) {
                Log.e(TAG, "getInfo: ÉCHEC", e)
                mainHandler.post { result.error("GETINFO_ERROR", e.message, null) }
            }
        }.start()
    }

    private fun handleDownload(
        url: String,
        outputTemplate: String,
        result: MethodChannel.Result,
    ) {
        Thread {
            try {
                Log.i(TAG, "download: initialisation...")
                ensureInitialized()
                Log.i(TAG, "download: démarrage pour $url")
                val request = YoutubeDLRequest(url)
                request.addOption("-x")
                request.addOption("--audio-format", "best")
                request.addOption("--audio-quality", "0")
                // --embed-thumbnail retiré : miniature téléchargée séparément côté Dart.
                request.addOption("--no-playlist")
                request.addOption("-o", outputTemplate)

                YoutubeDL.getInstance().execute(request, null) { progress, eta, line ->
                    Log.d(TAG, "download: ${progress}% — $line")
                    // Float→Double, null-safety pour interop Java (line/eta peuvent être null).
                    val event = mapOf(
                        "progress" to progress.toDouble(),
                        "eta"      to (eta?.toDouble() ?: 0.0),
                        "line"     to (line ?: ""),
                    )
                    mainHandler.post {
                        try {
                            progressSink?.success(event)
                        } catch (e: Throwable) {
                            Log.e(TAG, "download: erreur progress sink: $e")
                        }
                    }
                }
                Log.i(TAG, "download: terminé, envoi résultat Flutter...")
                mainHandler.post {
                    try {
                        result.success(true)
                        Log.i(TAG, "download: result.success envoyé")
                    } catch (e: Throwable) {
                        // Le canal peut être fermé si l'engine a été détaché (ex. rotation d'écran).
                        Log.e(TAG, "download: result.success ÉCHEC (engine détaché ?): $e")
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "download: ÉCHEC", e)
                mainHandler.post { result.error("DOWNLOAD_ERROR", e.message, null) }
            }
        }.start()
    }
}
