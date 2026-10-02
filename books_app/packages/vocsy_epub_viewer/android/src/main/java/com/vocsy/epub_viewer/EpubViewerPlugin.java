package com.vocsy.epub_viewer;

import android.app.Activity;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import java.util.Map;

import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

import androidx.annotation.NonNull;


/**
 * EpubReaderPlugin. Locally patched for lifecycle and method-result handling.
 */
public class EpubViewerPlugin implements MethodCallHandler, FlutterPlugin, ActivityAware {

    private Reader reader;
    private ReaderConfig config;
    private MethodChannel channel;
    static private Activity activity;
    static private Context context;
    static BinaryMessenger messenger;
    static private EventChannel eventChannel;
    static private EventChannel.EventSink sink;
    private static final String channelName = "vocsy_epub_viewer";

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {

        context = registrar.context();
        activity = registrar.activity();
        messenger = registrar.messenger();
        EpubViewerPlugin plugin = new EpubViewerPlugin();
        plugin.registerChannels(messenger, new MethodChannel(messenger, channelName));

    }

    /**
     * Registers the method and page-event channels with the Flutter engine.
     */
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        messenger = binding.getBinaryMessenger();
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), channelName);
        registerChannels(messenger, channel);
    }

    /**
     * Registers the method and page-event channels.
     */
    private void registerChannels(BinaryMessenger binaryMessenger, MethodChannel methodChannel) {
        eventChannel = new EventChannel(binaryMessenger, "page");
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink eventSink) {
                sink = eventSink;
            }

            @Override
            public void onCancel(Object arguments) {
                sink = null;
            }
        });
        channel = methodChannel;
        channel.setMethodCallHandler(this);
    }

    /**
     * Releases channel references when detached from the Flutter engine.
     */
    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
        if (eventChannel != null) {
            eventChannel.setStreamHandler(null);
            eventChannel = null;
        }
        sink = null;
        messenger = null;
        context = null;
        activity = null;
    }

    /**
     * Stores the activity supplied by the Flutter activity binding.
     */
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding activityPluginBinding) {
        activity = activityPluginBinding.getActivity();
    }

    /**
     * Releases the old activity while it is recreated for a configuration change.
     */
    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activity = null;
    }

    /**
     * Restores the activity after it is recreated for a configuration change.
     */
    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding activityPluginBinding) {
        activity = activityPluginBinding.getActivity();
    }

    /**
     * Clears the stored activity when the plugin detaches.
     */
    @Override
    public void onDetachedFromActivity() {
        activity = null;
    }

    /**
     * Dispatches reader configuration, open, close, and event-channel requests.
     * Completes every supported method call exactly once.
     */
    @Override
    public void onMethodCall(MethodCall call, Result result) {

        if (call.method.equals("setConfig")) {
            try {
                Map<String, Object> arguments = (Map<String, Object>) call.arguments;
                String identifier = arguments.get("identifier").toString();
                String themeColor = arguments.get("themeColor").toString();
                String scrollDirection = arguments.get("scrollDirection").toString();
                Boolean nightMode = Boolean.parseBoolean(arguments.get("nightMode").toString());
                Boolean allowSharing = Boolean.parseBoolean(arguments.get("allowSharing").toString());
                Boolean enableTts = Boolean.parseBoolean(arguments.get("enableTts").toString());
                config = new ReaderConfig(context, identifier, themeColor,
                        scrollDirection, allowSharing, enableTts, nightMode);
                result.success(null);
            } catch (Exception exception) {
                result.error("configuration_failed", exception.getMessage(), null);
            }

        } else if (call.method.equals("open")) {
            try {
                Map<String, Object> arguments = (Map<String, Object>) call.arguments;
                String bookPath = arguments.get("bookPath").toString();
                String lastLocation = arguments.get("lastLocation").toString();

                if (config == null) {
                    result.error("configuration_missing", "EPUB reader has not been configured.", null);
                    return;
                }
                if (activity == null) {
                    result.error("activity_unavailable", "No active Android activity is attached.", null);
                    return;
                }

                Log.i("opening", "In open function");
                reader = new Reader(context, config, sink);
                reader.open(bookPath, lastLocation, result);
            } catch (Exception exception) {
                result.error("open_failed", exception.getMessage(), null);
            }

        } else if (call.method.equals("close")) {
            try {
                if (reader != null) {
                    reader.close();
                }
                result.success(null);
            } catch (Exception exception) {
                result.error("close_failed", exception.getMessage(), null);
            }
        } else if (call.method.equals("setChannel")) {
            result.success(null);
        } else {
            result.notImplemented();
        }
    }
}
