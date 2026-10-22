package com.jackh0006.bnb_wallet_gui

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FLAG_SECURE prevents screenshots and screen recording of the app,
        // protecting wallet secrets and QR codes from leakage.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
