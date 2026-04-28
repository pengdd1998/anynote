# ==============================================================
# AnyNote ProGuard Rules
# ==============================================================

# ── Flutter framework ──────────────────────────────────────────
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── Flutter plugin registrant (critical for release builds) ────
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * extends io.flutter.embedding.engine.plugins.activity.ActivityAware { *; }
-keep class **.GeneratedPluginRegistrant { *; }

# ── Flutter Play Store Split (optional dependency) ──────────────
-dontwarn com.google.android.play.core.**

# ── sodium_libs (native crypto) ─────────────────────────────────
# Sodium JNI bindings must not be stripped or obfuscated
-keep class com.goterl.lazycode.** { *; }
-keep class com.goterl.lazycode.lazysodium.** { *; }
-keepclassmembers class com.goterl.lazycode.** {
    native <methods>;
    public *;
}

# ── Drift (SQLite ORM) generated code ──────────────────────────
-keep class * extends java.lang.reflect.** { *; }

# ── flutter_secure_storage ─────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── sqlite3_flutter_libs ────────────────────────────────────────
-keep class io.github.jgolfault.flutter.sqlite3.** { *; }
-keep class fr.free.sqlite3.** { *; }

# ── Kotlin reflection (used by serialization libs) ─────────────
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.reflect.**

# ── General AndroidX ───────────────────────────────────────────
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# ── Kotlin coroutines (used by some plugins) ────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler
-keepclassmembers class kotlinx.coroutines.** {
    *;
}

# ── Firebase ────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── WorkManager ────────────────────────────────────────────────
-keep class androidx.work.** { *; }

# ── Gson / JSON serialization ──────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*

# ── Native methods ─────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}
