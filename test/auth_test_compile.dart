import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'dart:io';

void main() {
  if (Platform.isWindows || Platform.isLinux) {
    // This is a test to see if the class exists and can be assigned
    GoogleSignInPlatform.instance = GoogleSignInAllPlatforms();
    print('Successfully assigned GoogleSignInAllPlatforms');
  }
}
