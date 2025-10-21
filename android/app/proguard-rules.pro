# ---------- Flutter / AndroidX 기본 ----------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.annotation.Keep

# ---------- Firebase / Google Play services ----------
# 대부분 AAR에 소비자 규칙이 포함되어 있지만, 리플렉션/레지스트리용 안전망
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class * extends com.google.firebase.components.ComponentRegistrar { *; }

# ---------- Gson(직렬화) / @SerializedName 대비 ----------
-keep class com.google.gson.** { *; }
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ---------- Parcelable CREATOR ----------
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# ---------- Enum name 보존(직렬화/디버그 가독성) ----------
-keepclassmembers enum * { public static **[] values(); public static ** valueOf(java.lang.String); }

# ---------- 경고 무시(필요시) ----------
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.**

# ---------- Play Core / Flutter deferred components 참조 허용 ----------
# R8이 Play Core 클래스를 못 찾는다고 실패하는 문제 해결
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.**
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.** { *; }

# Flutter의 deferred components 관련 경로 보존
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.app.FlutterPlayStoreSplitApplication { *; }