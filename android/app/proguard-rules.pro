-keep class com.yausername.** { *; }
-keep class com.fasterxml.jackson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes Exceptions
-dontwarn java.beans.ConstructorProperties
-dontwarn java.beans.Transient
-dontwarn org.w3c.dom.bootstrap.DOMImplementationRegistry

# Désactive le renommage des classes — évite les erreurs masquées avec youtubedl-android
-dontobfuscate
