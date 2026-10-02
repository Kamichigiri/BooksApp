package com.vocsy.epub_viewer;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
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

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class Reader implements OnHighlightListener, ReadLocatorListener, FolioReader.OnClosedListener {

    private ReaderConfig readerConfig;
    public FolioReader folioReader;
    private Context context;
    private EventChannel.EventSink pageEventSink;
    private ReadLocator read_locator;

    /**
     * Creates a reader with the supplied configuration and locator event sink.
     * Starts loading bundled highlights and registers the FolioReader callbacks.
     */
    Reader(Context context, ReaderConfig config, EventChannel.EventSink sink) {
        this.context = context;
        readerConfig = config;

        getHighlightsAndSave();

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
    /**
     * Locally patched to return background open failures through the method result.
     */
    public void open(String bookPath, String lastLocation, MethodChannel.Result result) {
        final String path = bookPath;
        final String location = lastLocation;
        Handler mainHandler = new Handler(Looper.getMainLooper());
        Thread worker = new Thread(() -> {
            try {
                Log.i("SavedLocation", "-> savedLocation -> " + location);
                ReadLocator locator = location == null || location.isEmpty()
                        ? null : ReadLocator.fromJson(location);
                mainHandler.post(() -> {
                    try {
                        if (locator != null) {
                            folioReader.setReadLocator(locator);
                        }
                        folioReader.setConfig(readerConfig.config, true).openBook(path);
                        result.success(null);
                    } catch (Exception exception) {
                        result.error("open_failed", exception.getMessage(), null);
                    }
                });
            } catch (Exception exception) {
                mainHandler.post(() ->
                        result.error("open_failed", exception.getMessage(), null));
            }
        });
        worker.setName("vocsy-epub-open");
        worker.start();
    }

    /**
     * Requests that FolioReader close the current book.
     */
    public void close() {
        folioReader.close();
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
     * Sends the last saved locator to an available event sink when one exists.
     */
    @Override
    public void onFolioReaderClosed() {
        if (read_locator != null) {
            String locatorJson = read_locator.toJson();
            Log.i("readLocator", "-> saveReadLocator -> " + locatorJson);
            if (pageEventSink != null) {
                pageEventSink.success(locatorJson);
            }
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
