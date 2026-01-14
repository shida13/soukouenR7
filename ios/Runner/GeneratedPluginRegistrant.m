//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<flutter_blue_plus_darwin/FlutterBluePlusPlugin.h>)
#import <flutter_blue_plus_darwin/FlutterBluePlusPlugin.h>
#else
@import flutter_blue_plus_darwin;
#endif

#if __has_include(<url_launcher_ios/URLLauncherPlugin.h>)
#import <url_launcher_ios/URLLauncherPlugin.h>
#else
@import url_launcher_ios;
#endif

#if __has_include(<webview_flutter_wkwebview/WebViewFlutterPlugin.h>)
#import <webview_flutter_wkwebview/WebViewFlutterPlugin.h>
#else
@import webview_flutter_wkwebview;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FlutterBluePlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterBluePlusPlugin"]];
  [URLLauncherPlugin registerWithRegistrar:[registry registrarForPlugin:@"URLLauncherPlugin"]];
  [WebViewFlutterPlugin registerWithRegistrar:[registry registrarForPlugin:@"WebViewFlutterPlugin"]];
}

@end
