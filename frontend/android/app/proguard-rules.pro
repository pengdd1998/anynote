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

# ── sodium_libs (native crypto) ─────────────────────────────────
# Sodium JNI bindings must not be stripped or obfuscated
-keep class com.goterl.lazycode.** { *; }
-keepclassmembers class com.goterl.lazycode.** {
    native <methods>;
}

# ── Drift (SQLite ORM) generated code ──────────────────────────
# Drift generates .g.dart files that Dart mirrors rely on; the
# Dart VM handles these at runtime. Keep Flutter engine access.
-keep class * extends java.lang.reflect.** { *; }

# ── flutter_secure_storage ─────────────────────────────────────
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── sqlite3_flutter_libs ────────────────────────────────────────
-keep class io.github.jgolfault.flutter.sqlite3.** { *; }
-keep class fr.free.sqlite3.** { *; }

# ── Model / serializable classes ────────────────────────────────
# Keep all Dart-visible model classes used in platform channels.
# Flutter uses dart:ffi and platform channels; these rules
# prevent stripping JNI bridge classes used by plugins.
-keepclassmembers class * {
    public <init>(...);
}

# ── General AndroidX ───────────────────────────────────────────
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

# ── Kotlin coroutines (used by some plugins) ────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile **;
}
