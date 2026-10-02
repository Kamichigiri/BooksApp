import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

part 'model/enum/epub_scroll_direction.dart';
part 'model/epub_locator.dart';
part 'utils/util.dart';

class VocsyEpub {
  static const MethodChannel _channel =
      const MethodChannel('vocsy_epub_viewer');
  static const EventChannel _pageChannel = const EventChannel('page');
  // Locally patched to share a single EventChannel subscription across readers.
  static final Stream<dynamic> _locatorBroadcastStream =
      _pageChannel.receiveBroadcastStream();

  /// Configure Viewer's with available values
  ///
  /// themeColor is the color of the reader
  /// scrollDirection uses the [EpubScrollDirection] enum
  /// allowSharing
  /// enableTts is an option to enable the inbuilt Text-to-Speech
  // Locally patched to expose platform failures to the calling application.
  static Future<void> setConfig(
      {Color themeColor = Colors.blue,
      String identifier = 'book',
      bool nightMode = false,
      EpubScrollDirection scrollDirection = EpubScrollDirection.ALLDIRECTIONS,
      bool allowSharing = false,
      bool enableTts = false}) async {
    Map<String, dynamic> agrs = {
      "identifier": identifier,
      "themeColor": Util.getHexFromColor(themeColor),
      "scrollDirection": Util.getDirection(scrollDirection),
      "allowSharing": allowSharing,
      'enableTts': enableTts,
      'nightMode': nightMode
    };
    await _channel.invokeMethod<void>('setConfig', agrs);
  }

  /// bookPath should be a local file.
  /// Last location is only available for android.
  // Locally patched to expose platform failures to the calling application.
  static Future<void> open(String bookPath, {EpubLocator? lastLocation}) async {
    Map<String, dynamic> agrs = {
      "bookPath": bookPath,
      'lastLocation':
          lastLocation == null ? '' : jsonEncode(lastLocation.toJson()),
    };
    await _channel.invokeMethod<void>('setChannel');
    await _channel.invokeMethod<void>('open', agrs);
  }

  static Future<void> closeReader() async {
    await setChannel();
    await _channel.invokeMethod<void>('close');
  }

  /// bookPath should be an asset file path.
  /// Last location is only available for android.
  static Future<void> openAsset(String bookPath,
      {EpubLocator? lastLocation}) async {
    if (extension(bookPath) == '.epub') {
      Map<String, dynamic> agrs = {
        "bookPath": (await Util.getFileFromAsset(bookPath)).path,
        'lastLocation':
            lastLocation == null ? '' : jsonEncode(lastLocation.toJson()),
      };
      await setChannel();
      await _channel.invokeMethod<void>('open', agrs);
    } else {
      throw ('${extension(bookPath)} cannot be opened, use an EPUB File');
    }
  }

  static Future<void> setChannel() async {
    await _channel.invokeMethod<void>('setChannel');
  }

  /// Stream to get EpubLocator for android and pageNumber for iOS
  static Stream<dynamic> get locatorStream => _locatorBroadcastStream;
}
