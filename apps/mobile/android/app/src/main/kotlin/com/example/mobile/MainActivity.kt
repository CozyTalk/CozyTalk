package com.example.mobile

import android.os.Bundle
import com.google.android.gms.tasks.Tasks
import com.google.firebase.appcheck.AppCheckProvider
import com.google.firebase.appcheck.AppCheckToken
import com.google.firebase.appcheck.FirebaseAppCheck
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (BuildConfig.DEBUG) {
            // Firebase Functions Android SDK (BOM 34+) unconditionally fetches an
            // App Check token before every callable invocation. Without a provider
            // the combined task fails before the HTTP request ever reaches the
            // Functions emulator. Install a fake provider that resolves instantly
            // with a hard-coded token — the Functions emulator accepts any value
            // without validation, so no Firebase Console registration is needed.
            FirebaseAppCheck.getInstance().installAppCheckProviderFactory {
                AppCheckProvider {
                    Tasks.forResult(object : AppCheckToken() {
                        override fun getToken() = "eyJhbGciOiJub25lIn0.eyJzdWIiOiJlbXVsYXRvciJ9.debug"
                        override fun getExpireTimeMillis() = Long.MAX_VALUE
                    })
                }
            }
        }
    }
}
