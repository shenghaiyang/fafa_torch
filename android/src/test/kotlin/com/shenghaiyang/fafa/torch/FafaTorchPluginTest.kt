package com.shenghaiyang.fafa.torch

import kotlin.test.Test
import kotlin.test.assertFalse

internal class FafaTorchPluginTest {
    @Test
    fun defaultsBeforeAttach() {
        val plugin = FafaTorchPlugin()

        assertFalse(plugin.isAvailable())
        assertFalse(plugin.isOn())
        assertFalse(plugin.supportsLevel())
    }
}
