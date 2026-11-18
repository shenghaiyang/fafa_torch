package com.shenghaiyang.fafa.torch

import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlin.math.roundToInt

class FafaTorchPlugin : FlutterPlugin, TorchHostApi {
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null
    private var torchEnabled = false
    private var eventChannel: StateChangesEventChannel? = null
    private var eventSink: PigeonEventSink<TorchState>? = null

    private val torchCallback = object : CameraManager.TorchCallback() {
        override fun onTorchModeChanged(cameraId: String, enabled: Boolean) {
            if (cameraId == this@FafaTorchPlugin.cameraId) {
                torchEnabled = enabled
                emitState()
            }
        }

        override fun onTorchModeUnavailable(cameraId: String) {
            if (cameraId == this@FafaTorchPlugin.cameraId) {
                torchEnabled = false
                emitState()
            }
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val manager =
            binding.applicationContext.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        cameraManager = manager
        resolveCameraId()
        TorchHostApi.setUp(binding.binaryMessenger, this)
        manager.registerTorchCallback(torchCallback, Handler(Looper.getMainLooper()))
        val streamHandler = object : StateChangesStreamHandler() {
            override fun onListen(p0: Any?, sink: PigeonEventSink<TorchState>) {
                eventSink = sink
                sink.success(currentState())
            }

            override fun onCancel(p0: Any?) {
                eventSink = null
            }
        }
        eventChannel = StateChangesStreamHandler.register(binding.binaryMessenger, streamHandler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        TorchHostApi.setUp(binding.binaryMessenger, null)
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        eventSink = null
        cameraManager?.unregisterTorchCallback(torchCallback)
        cameraManager = null
        cameraId = null
        torchEnabled = false
    }

    override fun isAvailable(): Boolean {
        return resolveCameraId() != null
    }

    override fun isOn(): Boolean {
        return torchEnabled
    }

    override fun supportsLevel(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            maxStrengthLevel() > 1
    }

    override fun level(): Double {
        if (!supportsLevel()) {
            throw FlutterError(
                "levelUnsupported",
                "Level control is not supported on this device.",
                null,
            )
        }
        val manager = cameraManager
            ?: throw FlutterError("torchOperationFailed", "CameraManager is unavailable.", null)
        val id = resolveCameraId()
            ?: throw FlutterError("torchUnavailable", "No flashlight is available.", null)
        return try {
            val level = manager.getTorchStrengthLevel(id)
            (level.toDouble() / maxStrengthLevel()).coerceIn(0.0, 1.0)
        } catch (e: CameraAccessException) {
            throw e.toFlutterError()
        } catch (e: IllegalArgumentException) {
            throw FlutterError("torchUnavailable", e.message, null)
        } catch (e: SecurityException) {
            throw FlutterError("torchOperationFailed", e.message, null)
        }
    }

    override fun turnOn(level: Double?) {
        val manager = cameraManager
            ?: throw FlutterError("torchOperationFailed", "CameraManager is unavailable.", null)
        val id = resolveCameraId()
            ?: throw FlutterError("torchUnavailable", "No flashlight is available.", null)
        if (level != null && !supportsLevel()) {
            throw FlutterError(
                "levelUnsupported",
                "Level control is not supported on this device.",
                null,
            )
        }

        try {
            if (level != null) {
                manager.turnOnTorchWithStrengthLevel(id, toStrengthLevel(level))
            } else {
                manager.setTorchMode(id, true)
            }
        } catch (e: CameraAccessException) {
            throw e.toFlutterError()
        } catch (e: IllegalArgumentException) {
            throw FlutterError("torchUnavailable", e.message, null)
        } catch (e: SecurityException) {
            throw FlutterError("torchOperationFailed", e.message, null)
        }

        torchEnabled = true
        emitState()
    }

    override fun turnOff() {
        val manager = cameraManager
            ?: throw FlutterError("torchOperationFailed", "CameraManager is unavailable.", null)
        val id = resolveCameraId()
            ?: throw FlutterError("torchUnavailable", "No flashlight is available.", null)

        try {
            manager.setTorchMode(id, false)
        } catch (e: CameraAccessException) {
            throw e.toFlutterError()
        } catch (e: IllegalArgumentException) {
            throw FlutterError("torchUnavailable", e.message, null)
        } catch (e: SecurityException) {
            throw FlutterError("torchOperationFailed", e.message, null)
        }

        torchEnabled = false
        emitState()
    }

    private fun currentState(): TorchState {
        return TorchState(
            available = resolveCameraId() != null,
            on = torchEnabled,
        )
    }

    private fun emitState() {
        eventSink?.success(currentState())
    }

    private fun resolveCameraId(): String? {
        cameraId?.let { return it }
        val manager = cameraManager ?: return null
        val ids = try {
            manager.cameraIdList
        } catch (_: CameraAccessException) {
            return null
        }
        var fallback: String? = null
        for (id in ids) {
            val characteristics = try {
                manager.getCameraCharacteristics(id)
            } catch (_: CameraAccessException) {
                continue
            }
            if (characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) != true) {
                continue
            }
            if (characteristics.get(CameraCharacteristics.LENS_FACING) ==
                CameraCharacteristics.LENS_FACING_BACK
            ) {
                cameraId = id
                return id
            }
            if (fallback == null) {
                fallback = id
            }
        }
        cameraId = fallback
        return fallback
    }

    private fun maxStrengthLevel(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return 1
        }
        val manager = cameraManager ?: return 1
        val id = resolveCameraId() ?: return 1
        return try {
            (manager.getCameraCharacteristics(id)
                .get(CameraCharacteristics.FLASH_INFO_STRENGTH_MAXIMUM_LEVEL) ?: 1)
                .coerceAtLeast(1)
        } catch (_: CameraAccessException) {
            1
        }
    }

    private fun toStrengthLevel(value: Double): Int {
        val max = maxStrengthLevel()
        return (value * max).roundToInt().coerceIn(1, max)
    }

    private fun CameraAccessException.toFlutterError(): FlutterError {
        val code = when (reason) {
            CameraAccessException.CAMERA_IN_USE,
            CameraAccessException.MAX_CAMERAS_IN_USE -> "torchInUse"

            else -> "torchOperationFailed"
        }
        return FlutterError(code, message, null)
    }
}
