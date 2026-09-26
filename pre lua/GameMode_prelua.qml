import QtQuick
import Quickshell
import Quickshell.Io
import qs.Widgets
import qs.Common
import qs.Modules.Plugins

PluginComponent {
    id: root

    // ── Home dir from $HOME ─────────────────────────────────────────────────
    readonly property string homeDir: {
        const h = Qt.environment["HOME"]
        return (h && h !== "") ? h : "/home/user"
    }

    // ── State ────────────────────────────────────────────────────────────────
    property bool active: pluginData.active || false

    // Which Hyprland config provider is running. Since Hyprland 0.55,
    // hyprlang is deprecated in favor of Lua (~/.config/hypr/hyprland.lua).
    // "hyprctl keyword" is a no-op on a Lua config — live changes there must
    // go through "hyprctl eval 'hl.config({...})'" instead.
    property bool isLua: true

    // Layout captured right before enabling, so it can be restored exactly.
    property string previousLayout: ""

    // ── Sane restore-to defaults (stock-ish Hyprland values) ────────────────
    readonly property var offValues: ({
        animEnabled: true,
        shadowEnabled: true,
        blurEnabled: true,
        rounding: 10,
        gapsIn: 5,
        gapsOut: 10,
        borderSize: 2,
        allowTearing: false
    })

    // ── Control Center tile ────────────────────────────────────────────────
    ccWidgetIcon:          "sports_esports"
    ccWidgetPrimaryText:   "Game Mode"
    ccWidgetSecondaryText: active ? "Active • Performance optimised" : "Inactive"
    ccWidgetIsActive:      active
    onCcWidgetToggled: toggle()

    // ── Bar pills ──────────────────────────────────────────────────────────
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            DankIcon {
                name: "sports_esports"
                size: root.iconSize
                color: root.active ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: "Game"
                visible: root.active
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: 2
            anchors.horizontalCenter: parent.horizontalCenter
            DankIcon {
                name: "sports_esports"
                size: root.iconSize
                color: root.active ? Theme.primary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ── Startup: detect Hyprland's active config provider ──────────────────
    Process {
        id: providerCheckProc
        running: true
        command: ["bash", "-c",
            "test -f '" + root.homeDir + "/.config/hypr/hyprland.lua' && echo lua || echo conf"]
        stdout: SplitParser {
            onRead: line => { root.isLua = (line.trim() === "lua") }
        }
    }

    // ── Fetch current layout (used before enabling, so it can be restored) ──
    Process {
        id: fetchLayoutProc
        command: ["bash", "-c",
            "hyprctl getoption general:layout -j | jq -r '.str // \"dwindle\"'"]
        stdout: SplitParser {
            onRead: line => {
                const l = line.trim()
                root.previousLayout = l !== "" ? l : "dwindle"
            }
        }
    }

    // ── Apply process — runs the actual hyprctl call and surfaces failures ──
    Process {
        id: applyProc
        stdout: SplitParser {
            onRead: line => {
                const t = line.trim()
                if (t !== "" && t !== "ok")
                    ToastService.showError("Game Mode", t)
            }
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.trim() !== "")
                    ToastService.showError("Game Mode", line)
            }
        }
    }

    // ── Screenshot + static-wallpaper swap (best-effort, non-blocking) ──────
    function _pauseLiveWallpaper() {
        const cachePath = root.homeDir + "/.cache/dms_gamemode_wallpaper.png"
        Quickshell.execDetached(["bash", "-c",
            "grim -o \"$(hyprctl monitors -j | jq -r '.[0].name')\" '" + cachePath + "' " +
            "2>/dev/null && dms wallpaper set '" + cachePath + "' 2>/dev/null || true"])
    }

    // ── Public toggle ──────────────────────────────────────────────────────
    function toggle() {
        if (root.active) {
            _disable()
        } else {
            _enable()
        }
    }

    function _saveActive() {
        try {
            if (pluginService)
                pluginService.savePluginData(pluginId, "active", root.active)
        } catch (e) {
            console.warn("Game Mode: failed to save active state:", e)
        }
    }

    function _enable() {
        root.active = true
        // Capture the current layout in the background (for restore on
        // disable) — independent of, and not a prerequisite for, applying
        // the performance profile below.
        fetchLayoutProc.running = true
        _applyPerformanceState(true)
        _pauseLiveWallpaper()
        _saveActive()
        ToastService.showInfo("Game Mode", "Enabled — performance unlocked")
    }

    function _disable() {
        root.active = false
        _applyPerformanceState(false)
        _saveActive()
        ToastService.showInfo("Game Mode", "Disabled — restored")
    }

    // enabling: true -> apply the stripped-down performance profile
    // enabling: false -> restore sane defaults (+ the captured layout)
    function _applyPerformanceState(enabling) {
        if (root.isLua) {
            let luaCmd
            if (enabling) {
                luaCmd =
                    "hl.config({" +
                    "animations={enabled=false}," +
                    "decoration={shadow={enabled=false},blur={enabled=false},rounding=0}," +
                    "general={gaps_in=0,gaps_out=0,border_size=1,allow_tearing=true}" +
                    "})"
            } else {
                const v = root.offValues
                let layoutPart = root.previousLayout !== ""
                    ? ",layout=\"" + root.previousLayout + "\""
                    : ""
                luaCmd =
                    "hl.config({" +
                    "animations={enabled=" + v.animEnabled + "}," +
                    "decoration={shadow={enabled=" + v.shadowEnabled + "}," +
                    "blur={enabled=" + v.blurEnabled + "},rounding=" + v.rounding + "}," +
                    "general={gaps_in=" + v.gapsIn + ",gaps_out=" + v.gapsOut +
                    ",border_size=" + v.borderSize +
                    ",allow_tearing=" + v.allowTearing + layoutPart + "}" +
                    "})"
            }
            applyProc.command = ["bash", "-c", "hyprctl eval '" + luaCmd + "'"]
        } else {
            let cmds
            if (enabling) {
                cmds = [
                    "hyprctl keyword animations:enabled 0",
                    "hyprctl keyword decoration:shadow:enabled 0",
                    "hyprctl keyword decoration:blur:enabled 0",
                    "hyprctl keyword general:gaps_in 0",
                    "hyprctl keyword general:gaps_out 0",
                    "hyprctl keyword general:border_size 1",
                    "hyprctl keyword decoration:rounding 0",
                    "hyprctl keyword general:allow_tearing 1"
                ]
            } else {
                const v = root.offValues
                cmds = [
                    "hyprctl keyword animations:enabled " + (v.animEnabled ? 1 : 0),
                    "hyprctl keyword decoration:shadow:enabled " + (v.shadowEnabled ? 1 : 0),
                    "hyprctl keyword decoration:blur:enabled " + (v.blurEnabled ? 1 : 0),
                    "hyprctl keyword general:gaps_in " + v.gapsIn,
                    "hyprctl keyword general:gaps_out " + v.gapsOut,
                    "hyprctl keyword general:border_size " + v.borderSize,
                    "hyprctl keyword decoration:rounding " + v.rounding,
                    "hyprctl keyword general:allow_tearing " + (v.allowTearing ? 1 : 0)
                ]
                if (root.previousLayout !== "")
                    cmds.push("hyprctl keyword general:layout " + root.previousLayout)
            }
            applyProc.command = ["bash", "-c", cmds.join(" && ")]
        }
        applyProc.running = true
    }
}
