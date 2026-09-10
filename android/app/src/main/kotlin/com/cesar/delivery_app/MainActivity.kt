package com.cesar.delivery_app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    /// Sobrescribimos onNewIntent para normalizar deep links de MP.
    /// El problema: rapidiya://pago/fallo se parsea con host=pago, path=/fallo.
    /// GoRouter espera /pago/fallo. Normalizamos el intent reenviándolo
    /// con un URI que tenga path=/pago/fallo.
    override fun onNewIntent(intent: Intent) {
        if (intent.action == Intent.ACTION_VIEW) {
            val data: Uri? = intent.data
            if (data != null && data.scheme == "rapidiya" && data.host == "pago") {
                // Reconstruir con host=null y path=/pago/...
                val path = data.path ?: ""
                val query = data.encodedQuery ?: ""
                val normalized = Uri.Builder()
                    .scheme("rapidiya")
                    .path("/pago$path")
                    .encodedQuery(query)
                    .build()
                val newIntent = Intent(intent).apply {
                    setData(normalized)
                }
                super.onNewIntent(newIntent)
                return
            }
        }
        super.onNewIntent(intent)
    }
}
