import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property bool isGameMode: pluginData.isGameMode || false
    property var savedState: ({})

    readonly property var gameOptions: [
        "decoration:rounding",
        "decoration:shadow:enabled",
        "decoration:blur:enabled",
        "general:border_size",
        "animations:enabled"
    ]
    readonly property var gameValues: ({
        "decoration:rounding": 0,
        "decoration:shadow:enabled": 0,
        "decoration:blur:enabled": 0,
        "general:border_size": 1,
        "animations:enabled": 0
    })
    // Fallback defaults, only used if we somehow have no saved/current value to restore
    readonly property var fallbackDefaults: ({
        "decoration:rounding": 12,
        "decoration:shadow:enabled": 1,
        "decoration:blur:enabled": 1,
        "general:border_size": 2,
        "animations:enabled": 1
    })

    // Options whose numeric 0/1 must become real Lua true/false — Lua treats
    // 0 as truthy, so passing the raw int here would leave shadow/blur/anim ON.
    readonly property var boolOptions: [
        "decoration:shadow:enabled",
        "decoration:blur:enabled",
        "animations:enabled"
    ]

    function getOpt(option, callback) {
        // Reading is unaffected by the config provider - getoption is a plain
        // query, only "keyword" writes are blocked on a Lua config.
        Proc.runCommand(pluginId + ".getopt." + option, ["hyprctl", "-j", "getoption", option],
            function (stdout, exitCode) {
                if (exitCode !== 0) {
                    callback(null)
                    return
                }
                try {
                    var data = JSON.parse(stdout)
                    var value = data.int !== undefined
                        ? data.int
                        : (data.set !== undefined ? (data.set ? 1 : 0) : null)
                    callback(value)
                } catch (e) {
                    callback(null)
                }
            }, 0, undefined, root)
    }

    function luaLiteral(v) {
        if (v === true) return "true"
        if (v === false) return "false"
        if (typeof v === "number") return String(v)
        if (typeof v === "object" && v !== null) {
            var parts = []
            for (var k in v) parts.push(k + "=" + luaLiteral(v[k]))
            return "{" + parts.join(",") + "}"
        }
        return "\"" + String(v) + "\""
    }

    // Turns {"decoration:rounding": 0, "decoration:shadow:enabled": 0, ...}
    // into a nested table, converting boolOptions ints to real booleans.
    function buildNestedTable(flatMap) {
        var tree = {}
        for (var key in flatMap) {
            var parts = key.split(":")
            var node = tree
            for (var i = 0; i < parts.length - 1; i++) {
                if (!node[parts[i]]) node[parts[i]] = {}
                node = node[parts[i]]
            }
            var raw = flatMap[key]
            node[parts[parts.length - 1]] = boolOptions.indexOf(key) !== -1
                ? (raw ? true : false)
                : raw
        }
        return tree
    }

    // Applies every option in one shot via `hyprctl eval 'hl.config({...})'`
    // - the only write path that actually works on a Lua-config Hyprland.
    // `hyprctl keyword` is a documented no-op in that mode.
    function applyOptions(flatMap) {
        var tree = buildNestedTable(flatMap)
        var luaCmd = "hl.config(" + luaLiteral(tree) + ")"
        Quickshell.execDetached(["hyprctl", "eval", luaCmd])
    }

    function enableGameMode() {
        var pending = gameOptions.length
        var results = {}

        gameOptions.forEach(function (opt) {
            getOpt(opt, function (value) {
                results[opt] = value
                pending--
                if (pending === 0) {
                    root.savedState = results
                    if (pluginService) {
                        try {
                            pluginService.savePluginData(pluginId, "savedState", JSON.stringify(results))
                        } catch (e) {
                            console.warn("gamemode: failed to persist savedState:", e)
                        }
                    }
                    applyOptions(gameValues)
                }
            })
        })
    }

    function disableGameMode() {
        var state = root.savedState
        if (!state || Object.keys(state).length === 0) {
            if (pluginService) {
                try {
                    var raw = pluginService.loadPluginData(pluginId, "savedState", "{}")
                    state = JSON.parse(raw)
                } catch (e) {
                    console.warn("gamemode: failed to load savedState:", e)
                    state = {}
                }
            }
        }
        var restoreMap = {}
        gameOptions.forEach(function (o) {
            restoreMap[o] = (state && state[o] !== undefined) ? state[o] : fallbackDefaults[o]
        })
        applyOptions(restoreMap)
        if (pluginService) {
            try {
                pluginService.savePluginData(pluginId, "savedState", "{}")
            } catch (e) {
                console.warn("gamemode: failed to clear savedState:", e)
            }
        }
        root.savedState = {}
    }

    // --- Control Center toggle ---
    ccWidgetIcon: "sports_esports"
    ccWidgetPrimaryText: "Game Mode"
    ccWidgetSecondaryText: isGameMode ? "Optimized \u2014 low latency" : "Normal desktop effects"
    ccWidgetIsActive: isGameMode

    onCcWidgetToggled: {
        isGameMode = !isGameMode

        if (pluginService) {
            pluginService.savePluginData(pluginId, "isGameMode", isGameMode)
        }

        if (isGameMode) {
            enableGameMode()
        } else {
            disableGameMode()
        }

        ToastService.showInfo(isGameMode ? "Game Mode ON" : "Game Mode OFF")
    }

    // --- DankBar pills (optional glance indicator) ---
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "sports_esports"
                size: Theme.iconSize
                color: root.isGameMode ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            DankIcon {
                name: "sports_esports"
                size: Theme.iconSize
                color: root.isGameMode ? Theme.primary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
