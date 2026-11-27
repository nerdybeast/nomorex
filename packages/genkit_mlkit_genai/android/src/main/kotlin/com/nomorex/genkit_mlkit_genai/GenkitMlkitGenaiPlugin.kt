package com.nomorex.genkit_mlkit_genai

import android.os.Build
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.prompt.Candidate
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Gemini Nano through the ML Kit GenAI Prompt API, for Genkit over Pigeon. The
 * Dart side (`defineMlKitGenAiModel`) turns Genkit requests into
 * [MlKitGenerateRequest]s, with any output schema already in the prompt: ML
 * Kit's structured output is compile-time only.
 */
class GenkitMlkitGenaiPlugin : FlutterPlugin, MlKitGenAiHostApi {
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val model: GenerativeModel by lazy { Generation.getClient() }

  // The download this app started, reported by status().
  private var download: Job? = null
  private var bytesToDownload: Long? = null
  private var bytesDownloaded: Long? = null
  private var downloadError: String? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    MlKitGenAiHostApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    MlKitGenAiHostApi.setUp(binding.binaryMessenger, null)
    scope.cancel()
  }

  override suspend fun status(): MlKitModelStatus {
    val availability = try {
      when (model.checkStatus()) {
        FeatureStatus.AVAILABLE -> MlKitModelAvailability.AVAILABLE
        FeatureStatus.DOWNLOADABLE -> MlKitModelAvailability.DOWNLOADABLE
        FeatureStatus.DOWNLOADING -> MlKitModelAvailability.DOWNLOADING
        else -> MlKitModelAvailability.UNAVAILABLE
      }
    } catch (e: Exception) {
      // No AICore, or a device ML Kit doesn't know: treated as can't run.
      MlKitModelAvailability.UNAVAILABLE
    }
    val tokenLimit = if (availability == MlKitModelAvailability.AVAILABLE) {
      try { model.getTokenLimit().toLong() } catch (e: Exception) { null }
    } else null
    return MlKitModelStatus(
      availability = availability,
      bytesDownloaded = bytesDownloaded,
      bytesToDownload = bytesToDownload,
      downloadError = downloadError,
      tokenLimit = tokenLimit,
      sdkInt = Build.VERSION.SDK_INT.toLong(),
      deviceModel = Build.MODEL ?: "",
    )
  }

  override fun startDownload() {
    if (download?.isActive == true) return
    downloadError = null
    bytesDownloaded = null
    bytesToDownload = null
    download = scope.launch {
      try {
        model.download().collect { status ->
          when (status) {
            is DownloadStatus.DownloadStarted -> {
              bytesToDownload = status.bytesToDownload
              bytesDownloaded = 0
            }
            is DownloadStatus.DownloadProgress -> bytesDownloaded = status.totalBytesDownloaded
            is DownloadStatus.DownloadCompleted -> bytesDownloaded = bytesToDownload
            is DownloadStatus.DownloadFailed -> downloadError = status.e.message ?: "Download failed"
          }
        }
      } catch (e: Exception) {
        downloadError = e.message ?: e.toString()
      }
    }
  }

  override suspend fun generate(request: MlKitGenerateRequest): MlKitGenerateResponse {
    val contentRequest = generateContentRequest(TextPart(request.prompt)) {
      request.temperature?.let { temperature = it.toFloat() }
      maxOutputTokens = request.maxOutputTokens.toInt()
    }
    try {
      val inputTokens = try { model.countTokens(contentRequest).totalTokens.toLong() } catch (e: Exception) { null }
      val candidate = model.generateContent(contentRequest).candidates.firstOrNull()
      return MlKitGenerateResponse(
        text = candidate?.text ?: "",
        cutOff = candidate?.finishReason == Candidate.FinishReason.MAX_TOKENS,
        inputTokens = inputTokens,
      )
    } catch (e: GenAiException) {
      throw FlutterError(errorCode(e.errorCode), e.message ?: "ML Kit error ${e.errorCode}", e.errorCode)
    }
  }

  /** One code per error the Dart side handles differently. */
  private fun errorCode(code: Int): String = when (code) {
    GenAiException.ErrorCode.REQUEST_TOO_LARGE -> "tooLong"
    GenAiException.ErrorCode.BUSY,
    GenAiException.ErrorCode.PER_APP_BATTERY_USE_QUOTA_EXCEEDED -> "busy"
    GenAiException.ErrorCode.NOT_AVAILABLE,
    GenAiException.ErrorCode.NOT_SUPPORTED,
    GenAiException.ErrorCode.NEEDS_SYSTEM_UPDATE,
    GenAiException.ErrorCode.AICORE_INCOMPATIBLE,
    GenAiException.ErrorCode.BACKGROUND_USE_BLOCKED,
    GenAiException.ErrorCode.NOT_ENOUGH_DISK_SPACE -> "unavailable"
    else -> "failed"
  }
}
