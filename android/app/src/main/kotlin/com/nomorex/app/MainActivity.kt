package com.nomorex.app

import android.graphics.BitmapFactory
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.ImagePart
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

// SPIKE (#183): on-device LLM bridge to Gemini Nano through the ML Kit GenAI Prompt API.
class MainActivity : FlutterActivity() {
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private val model by lazy { Generation.getClient() }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nomorex/on_device_llm").setMethodCallHandler { call, result ->
      scope.launch {
        try {
          when (call.method) {
            "status" -> {
              val state = when (model.checkStatus()) {
                FeatureStatus.AVAILABLE -> "available"
                FeatureStatus.DOWNLOADABLE -> "downloadable"
                FeatureStatus.DOWNLOADING -> "downloading"
                else -> "unavailable"
              }
              result.success(mapOf("state" to state, "os" to "android ${android.os.Build.VERSION.SDK_INT}", "device" to android.os.Build.MODEL))
            }
            "download" -> {
              var last = "started"
              model.download().collect { s ->
                last = when (s) {
                  is DownloadStatus.DownloadStarted -> "started"
                  is DownloadStatus.DownloadProgress -> "progress ${s.totalBytesDownloaded}"
                  is DownloadStatus.DownloadCompleted -> "completed"
                  is DownloadStatus.DownloadFailed -> "failed ${s.e.message}"
                }
              }
              result.success(mapOf("download" to last))
            }
            "generate" -> {
              val prompt = listOfNotNull(call.argument<String>("system"), call.argument<String>("prompt")).joinToString("\n\n")
              val image = call.argument<ByteArray>("image")
              val temperature = call.argument<Double>("temperature")
              val maxTokens = call.argument<Int>("maxTokens")
              val start = System.currentTimeMillis()
              val request = if (image != null) {
                generateContentRequest(ImagePart(BitmapFactory.decodeByteArray(image, 0, image.size)), TextPart(prompt)) {
                  temperature?.let { this.temperature = it.toFloat() }
                  maxTokens?.let { maxOutputTokens = it }
                }
              } else {
                generateContentRequest(TextPart(prompt)) {
                  temperature?.let { this.temperature = it.toFloat() }
                  maxTokens?.let { maxOutputTokens = it }
                }
              }
              val response = model.generateContent(request)
              result.success(mapOf(
                "text" to (response.candidates.firstOrNull()?.text ?: ""),
                "ms" to (System.currentTimeMillis() - start).toInt(),
              ))
            }
            else -> result.notImplemented()
          }
        } catch (e: Exception) {
          result.error("failed", e.toString(), null)
        }
      }
    }
  }
}
