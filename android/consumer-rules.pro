# simple_telephony uses FlutterCallbackInformation to look up Dart callback
# handles by reflection. Obfuscating these classes breaks background event
# delivery when the host app enables R8/ProGuard.

-keep class io.flutter.view.FlutterCallbackInformation { *; }
-keep class io.flutter.embedding.engine.dart.DartExecutor$DartCallback { *; }
-keep class io.simplezen.simple_telecom.** { *; }
