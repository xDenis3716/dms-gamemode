import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "GameMode"

    StyledText {
        width: parent.width
        text: "Game Mode"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Maximises performance by stripping Hyprland eye candy — " +
              "animations, blur, shadows, gaps, and rounding are all disabled. " +
              "Do Not Disturb turns on automatically."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // ── Persistence file path ──────────────────────────────────────────────
    SelectionSetting {
        settingKey: "configFormat"
        label: "Config format"
        description: "Match your Hyprland config style"
        options: [
            { label: "Lua  (user_persistence.lua)",  value: "lua"  },
            { label: "Conf (user_persistence.conf)", value: "conf" }
        ]
        defaultValue: "lua"
    }

    StringSetting {
        settingKey: "persistencePath"
        label: "Persistence file path"
        description: "Absolute path to the file where game-mode keywords are written. " +
                     "Tilde (~) is expanded automatically."
        placeholder: "~/.config/hypr/nandoroid/user_persistence.lua"
        defaultValue: "~/.config/hypr/nandoroid/user_persistence.lua"
    }

    // ── Behaviour toggles ──────────────────────────────────────────────────
    ToggleSetting {
        settingKey: "syncDnd"
        label: "Sync with Do Not Disturb"
        description: "Silence notifications while Game Mode is active"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "pauseLiveWallpaper"
        label: "Pause live wallpaper"
        description: "Stop the wallpaper engine and use a static screenshot instead"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "allowTearing"
        label: "Allow tearing"
        description: "Sets allow_tearing = true for lower input latency (requires VRR / freesync)"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "borderSize"
        label: "Border size in game mode"
        description: "Pixel width of window borders while active"
        defaultValue: 1
        minimum: 0
        maximum: 4
        unit: "px"
    }
}
