# Rules for release builds (code shrinking with R8).

# shared_preferences: its Android code is called from Dart by name, so R8
# must not remove or rename it.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class dev.flutter.pigeon.** { *; }

# Dart-to-Java bridge used by newer Flutter plugins.
-keep class com.github.dart_lang.jni.** { *; }

# Kotlin coroutine types appear in those method signatures.
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Metadata { *; }

-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
