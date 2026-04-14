import 'package:flutter_test/flutter_test.dart';
import 'package:simple_telephony_android/simple_telephony_android.dart';
import 'package:simple_telephony_platform_interface/simple_telephony_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registerWith sets platform instance to SimpleTelephonyAndroid', () {
    SimpleTelephonyAndroid.registerWith(null);
    expect(SimpleTelephonyPlatform.instance, isA<SimpleTelephonyAndroid>());
  });

  test('SimpleTelephonyAndroid extends MethodChannelSimpleTelephony', () {
    final platform = SimpleTelephonyAndroid();
    expect(platform, isA<MethodChannelSimpleTelephony>());
  });
}
