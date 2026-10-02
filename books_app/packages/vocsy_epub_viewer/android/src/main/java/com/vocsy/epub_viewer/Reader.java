package com.vocsy.epub_viewer;

import android.content.Context;
import android.util.Log;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.folioreader.Config;
import com.folioreader.FolioReader;
import com.folioreader.model.HighLight;
import com.folioreader.model.locators.ReadLocator;
import com.folioreader.ui.base.OnSaveHighlight;
import com.folioreader.util.OnHighlightListener;
import com.folioreader.util.ReadLocatorListener;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class Reader implements OnHighlightListener, ReadLocatorListener, FolioReader.OnClosedListener {

    private ReaderConfig readerConfig;
    public FolioReader folioReader;
    private Context context;
    public MethodChannel.Result result;
    private EventChannel eventChannel;
    private EventChannel.EventSink pageEventSink;
    private BinaryMessenger messenger;
    private ReadLocator read_locator;
    private static final String PAGE_CHANNEL = "sage";

    /**
     * Creates a reader with the supplied configuration and locator event sink.
     * Starts loading bundled highlights and registers the FolioReader callbacks.
     */
    Reader(Context context, BinaryMessenger messenger, ReaderConfig config, EventChannel.EventSink sink) {
        this.context = context;
        readerConfig = config;

        getHighlightsAndSave();
        //setPageHandler(messenger);

        folioReader = FolioReader.get()
                .setOnHighlightListener(this)
                .setReadLocatorListener(this)
                .setOnClosedListener(this);
        pageEventSink = sink;
    }

    /**
     * Starts a background task to open an EPUB and optionally restore its locator.
     *
     * @param bookPath path of the EPUB to open
     * @param lastLocation locator JSON, or null or an empty string to skip restoration
     */
    public void open(String bookPath, String lastLocation) {
        final String path = bookPath;
        final String location = lastLocation;
        new Thread(new Runnable() {
            /**
             * Restores a supplied locator and opens the book, logging any exception.
             */
            @Override
            public void run() {
                try {
                    Log.i("SavedLocation", "-> savedLocation -> " + location);
                    if (location != null && !location.isEmpty()) {
                        ReadLocator readLocator = ReadLocator.fromJson(location);
                        folioReader.setReadLocator(readLocator);
                    }
                    folioReader.setConfig(readerConfig.config, true)
                            .openBook(path);
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }).start();

    }

    /**
     * Requests that FolioReader close the current book.
     */
    public void close() {
        folioReader.close();
    }

    /**
     * Registers the legacy {@code sage} channel for locator events.
     */
    private void setPageHandler(BinaryMessenger messenger) {
//        final MethodChannel channel = new MethodChannel(registrar.messenger(), "page");
//        channel.setMethodCallHandler(new EpubKittyPlugin());
        Log.i("event sink is", "in set page handler:");
        eventChannel = new EventChannel(messenger, PAGE_CHANNEL);

        try {

            eventChannel.setStreamHandler(new EventChannel.StreamHandler() {

                /**
                 * Stores the event sink used to publish the final reading position.
                 */
                @Override
                public void onListen(Object o, EventChannel.EventSink eventSink) {

                    Log.i("event sink is", "this is eveent sink:");

                    pageEventSink = eventSink;
                    if (pageEventSink == null) {
                        Log.i("empty", "Sink is empty");
                    }
                }

                /**
                 * Leaves the stored event sink unchanged when the stream is cancelled.
                 */
                @Override
                public void onCancel(Object o) {

                }
            });
        } catch (Error err) {
            Log.i("and error", "error is " + err.toString());
        }
    }

    /**
     * Starts a background task to read the bundled highlight data.
     */
    private void getHighlightsAndSave() {
        new Thread(new Runnable() {
            /**
             * Parses the bundled highlights and calls the save hook if the list is null.
             */
            @Override
            public void run() {
                ArrayList<HighLight> highlightList = null;
                ObjectMapper objectMapper = new ObjectMapper();
                try {
                    highlightList = objectMapper.readValue(
                            loadAssetTextAsString("highlights/highlights_data.json"),
                            new TypeReference<List<HighlightData>>() {
                            });
                } catch (IOException e) {
                    e.printStackTrace();
                }

                if (highlightList == null) {
                    folioReader.saveReceivedHighLights(highlightList, new OnSaveHighlight() {
                        /**
                         * Receives highlight-save completion without performing additional work.
                         */
                        @Override
                        public void onFinished() {
                            //You can do anything on successful saving highlight list
                        }
                    });
                }
            }
        }).start();
    }


    /**
     * Reads an asset as text, joining its lines with newline characters.
     *
     * @param name asset path relative to the Android assets directory
     * @return asset text, or null if the asset cannot be read
     */
    private String loadAssetTextAsString(String name) {
        BufferedReader in = null;
        try {
            StringBuilder buf = new StringBuilder();
            InputStream is = context.getAssets().open(name);
            in = new BufferedReader(new InputStreamReader(is));

            String str;
            boolean isFirst = true;
            while ((str = in.readLine()) != null) {
                if (isFirst)
                    isFirst = false;
                else
                    buf.append('\n');
                buf.append(str);
            }
            return buf.toString();
        } catch (IOException e) {
            Log.e("Reader", "Error opening asset " + name);
        } finally {
            if (in != null) {
                try {
                    in.close();
                } catch (IOException e) {
                    Log.e("Reader", "Error closing asset " + name);
                }
            }
        }
        return null;
    }

    /**
     * Logs the last saved locator and sends its JSON to an available event sink.
     * Requires a locator to have been supplied through {@link #saveReadLocator}.
     */
    @Override
    public void onFolioReaderClosed() {
        Log.i("readLocator", "-> saveReadLocator -> " + read_locator.toJson());

        if (pageEventSink != null) {
            pageEventSink.success(read_locator.toJson());
        }
    }

    /**
     * Receives highlight changes without performing additional work.
     */
    @Override
    public void onHighlight(HighLight highlight, HighLight.HighLightAction type) {

    }

    /**
     * Stores the latest locator for publication when the reader closes.
     */
    @Override
    public void saveReadLocator(ReadLocator readLocator) {
        read_locator = readLocator;
    }


}
