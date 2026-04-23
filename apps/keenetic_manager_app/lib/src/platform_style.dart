import 'package:flutter/foundation.dart';

bool get isMacOSDesignTarget =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

bool get isAppleNativeTarget =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS);
