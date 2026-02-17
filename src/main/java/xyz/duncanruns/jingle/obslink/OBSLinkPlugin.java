package xyz.duncanruns.jingle.obslink;

import com.google.common.io.Resources;
import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.annotations.SerializedName;
import me.duncanruns.kerykeion.Kerykeion;
import me.duncanruns.kerykeion.listeners.HermesStateListener;
import org.apache.logging.log4j.Level;
import xyz.duncanruns.jingle.Jingle;
import xyz.duncanruns.jingle.JingleAppLaunch;
import xyz.duncanruns.jingle.gui.JingleGUI;
import xyz.duncanruns.jingle.obslink.gui.OBSLinkPanel;
import xyz.duncanruns.jingle.plugin.PluginEvents;
import xyz.duncanruns.jingle.plugin.PluginManager;
import xyz.duncanruns.jingle.util.FileUtil;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.Charset;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;

public class OBSLinkPlugin {
    private static final Gson GSON = new GsonBuilder().serializeNulls().create();
    private static final ScheduledExecutorService EXECUTOR = Executors.newSingleThreadScheduledExecutor();
    private static final Path OUT = Jingle.FOLDER.resolve("obs-link-state");

    private static int currentInstance = -1;
    private static State currentState = State.PLAYING;

    public static void main(String[] args) throws IOException {
        // This is only used to test the plugin in the dev environment
        // ExamplePlugin.main itself is never used when users run Jingle

        JingleAppLaunch.launchWithDevPlugin(args, PluginManager.JinglePluginData.fromString(
                Resources.toString(Resources.getResource(OBSLinkPlugin.class, "/jingle.plugin.json"), Charset.defaultCharset())
        ), OBSLinkPlugin::initialize);
    }


    public static void initialize() {
        PluginEvents.STOP.register(EXECUTOR::shutdown);
        JingleGUI.addPluginTab("OBS Link", new OBSLinkPanel().mainPanel);
        PluginEvents.END_TICK.register(() -> {
        });
        PluginEvents.MAIN_INSTANCE_CHANGED.register(() -> currentInstance = Jingle.getMainInstance().map(i -> i.pid).orElse(-1));
        Kerykeion.addListener((HermesStateListener) (instance, s) -> {
            if (instance.has("pid") && instance.get("pid").getAsInt() == currentInstance)
                onState(s);
        }, 1, EXECUTOR);
        try {
            copyResourceToFile("/jingle-obs-link.lua", Jingle.FOLDER.resolve("jingle-obs-link.lua"));
            Jingle.log(Level.INFO, "Regenerated obs link script");
        } catch (IOException e) {
            Jingle.logError("Failed to write Script!", e);
            Jingle.log(Level.ERROR, "You can download the script manually from https://github.com/DuncanRuns/Jingle-OBS-Link/blob/main/src/main/resources/jingle-obs-link.lua");
        }
        write();
    }

    private static void onState(JsonObject hermesStateJson) {
        HermesState hermesState;
        try {
            hermesState = GSON.fromJson(hermesStateJson, HermesState.class);
        } catch (Exception e) {
            Jingle.logError("(OBS Link) Failed to parse Hermes state:", e);
            return;
        }

        State lastState = currentState;

        if (hermesState.world != null && !hermesState.world.isJsonNull()) {
            currentState = State.PLAYING;
        } else if (hermesState.screen.javaClass != null && hermesState.screen.javaClass.endsWith(".SeedQueueWallScreen")) {
            currentState = State.WALL;
        }

        if (lastState != currentState) {
            write();
        }
    }

    private static void write() {
        try {
            FileUtil.writeString(OUT, currentState == State.WALL ? "W" : "P");
        } catch (IOException e) {
            Jingle.logError("(OBS Link) Failed to write to " + OUT, e);
        }
    }

    @SuppressWarnings("unused")
    private static class HermesState {
        public Screen screen;
        @SerializedName("last_world_joined")
        public JsonElement lastWorldJoined;
        public JsonElement world;

        private static class Screen {
            @SerializedName("class")
            public String javaClass;
            public JsonElement title;
            @SerializedName("is_pause")
            public boolean isPause;
        }
    }


    // Copy of Jingle code but using OBSLinkPlugin.class
    private static void copyResourceToFile(String resourceName, Path destination) throws IOException {
        // Answer to https://stackoverflow.com/questions/10308221/how-to-copy-file-inside-jar-to-outside-the-jar
        InputStream inStream = getResourceAsStream(resourceName);
        OutputStream outStream = Files.newOutputStream(destination);
        int readBytes;
        byte[] buffer = new byte[4096];
        while ((readBytes = inStream.read(buffer)) > 0) {
            outStream.write(buffer, 0, readBytes);
        }
        inStream.close();
        outStream.close();
    }

    private static InputStream getResourceAsStream(String name) {
        return OBSLinkPlugin.class.getResourceAsStream(name);
    }

    private enum State {
        WALL,
        PLAYING
    }
}
