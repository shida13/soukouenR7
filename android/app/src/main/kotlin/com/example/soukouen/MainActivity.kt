package com.example.soukouen

import io.flutter.embedding.android.FlutterActivity
import android.webkit.WebViewClient
import android.webkit.WebView
import android.net.http.SslError
import android.webkit.SslErrorHandler

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // WebViewの設定
        setupWebView()
    }
    
    private fun setupWebView() {
        // SSL証明書エラーを無視（開発用）
        // NOTE: This is for development only. Do not use in production!
    }
}
