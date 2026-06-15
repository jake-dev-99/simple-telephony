package io.simplezen.simple_telephony

import io.flutter.plugin.common.BinaryMessenger
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import java.nio.ByteBuffer

/**
 * Regression tests for UNFY-176: detaching one `FlutterEngine` must not tear
 * down another engine's foreground `EventChannel` handler.
 *
 * Reproduces the multi-engine ordering that produced
 * `MissingPluginException(... /foreground_events)` at consumer startup:
 * a foreground-service engine attaches, then the main app engine attaches,
 * then the service engine detaches. Before the per-engine fix, the service's
 * detach removed the *main* engine's `StreamHandler`.
 */
@RunWith(RobolectricTestRunner::class)
class ForegroundChannelBridgeTest {

    /**
     * Minimal [BinaryMessenger] that records the latest `StreamHandler`
     * registration per channel name. `EventChannel.setStreamHandler(h)` calls
     * `setMessageHandler(name, non-null)`; `setStreamHandler(null)` calls
     * `setMessageHandler(name, null)` — so a non-null entry here means "a
     * handler is installed on this engine for this channel."
     */
    private class RecordingMessenger : BinaryMessenger {
        val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler?>()

        override fun setMessageHandler(
            channel: String,
            handler: BinaryMessenger.BinaryMessageHandler?,
        ) {
            handlers[channel] = handler
        }

        override fun send(channel: String, message: ByteBuffer?) = Unit

        override fun send(
            channel: String,
            message: ByteBuffer?,
            callback: BinaryMessenger.BinaryReply?,
        ) = Unit
    }

    private val channelName = TelecomConstants.FOREGROUND_EVENTS_CHANNEL

    @Test
    fun `detach of one engine leaves another engine's handler installed`() {
        val bridge = ForegroundChannelBridge()
        val serviceEngine = RecordingMessenger()
        val mainEngine = RecordingMessenger()

        bridge.attach(serviceEngine) // a foreground-service engine attaches first
        bridge.attach(mainEngine) //   then the main app engine attaches
        bridge.detach(serviceEngine) // the service engine detaches

        assertNotNull(
            "main engine's foreground handler must survive another engine's detach",
            mainEngine.handlers[channelName],
        )
        assertNull(
            "the detaching engine's handler is removed",
            serviceEngine.handlers[channelName],
        )
    }

    @Test
    fun `detach removes only the target engine's handler`() {
        val bridge = ForegroundChannelBridge()
        val mainEngine = RecordingMessenger()

        bridge.attach(mainEngine)
        assertNotNull(
            "attach installs the engine's handler",
            mainEngine.handlers[channelName],
        )

        bridge.detach(mainEngine)
        assertNull(
            "detaching the owning engine clears its own handler",
            mainEngine.handlers[channelName],
        )
    }

    @Test
    fun `attach is idempotent for the same engine`() {
        val bridge = ForegroundChannelBridge()
        val mainEngine = RecordingMessenger()

        bridge.attach(mainEngine)
        bridge.attach(mainEngine) // re-attach must not leave a dangling handler

        bridge.detach(mainEngine)
        assertNull(
            "a single detach fully clears a re-attached engine",
            mainEngine.handlers[channelName],
        )
    }
}
