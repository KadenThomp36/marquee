# kotlinx.serialization ships its own consumer rules; keep our @Serializable models' companions.
-keepattributes *Annotation*, InnerClasses
-keepclassmembers @kotlinx.serialization.Serializable class dev.kadenthompson.marquee.** {
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
-dontwarn org.slf4j.**

# Glance instantiates widget action callbacks by class name.
-keep class * implements androidx.glance.appwidget.action.ActionCallback { <init>(); }
-keep class dev.kadenthompson.marquee.widget.** { *; }
