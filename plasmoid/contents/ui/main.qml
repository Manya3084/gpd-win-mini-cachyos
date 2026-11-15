import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // Live state, filled from `tdpctl status`
    property int tdp: 0
    property int tdpMin: 5
    property int tdpMax: 35
    property real powerNow: 0
    property real tempC: 0
    property bool boost: true
    property bool pcTdpEnabled: true
    property string fanMode: "normal"
    property int fanRpm: 0
    property bool busy: false
    property string errorText: ""
    property bool haveData: false

    readonly property string helper: "sudo -n /usr/local/bin/tdpctl "

    Plasmoid.icon: "speedometer"
    toolTipMainText: i18n("TDP Control")
    toolTipSubText: haveData
        ? i18n("Limit %1 W · drawing %2 W · %3 °C · fan %4", tdp, powerNow.toFixed(1), Math.round(tempC), fanMode)
        : i18n("Reading power limits…")

    switchWidth: Kirigami.Units.gridUnit * 14
    switchHeight: Kirigami.Units.gridUnit * 12

    Plasma5Support.DataSource {
        id: exec
        engine: "executable"
        connectedSources: []
        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            root.handleResult(data["exit code"], data["stdout"] || "", data["stderr"] || "")
        }
    }

    function run(args) { exec.connectSource(helper + args) }
    function refresh() { run("status") }
    function setTdp(w) {
        if (busy || w === tdp) return
        busy = true
        run("set-tdp " + Math.round(w))
    }
    function setBoost(on) {
        if (busy) return
        busy = true
        run("set-boost " + (on ? 1 : 0))
    }
    function setFan(mode) {
        if (busy || mode === fanMode) return
        busy = true
        run("set-fan " + mode)
    }
    function handleResult(code, stdout, stderr) {
        busy = false
        if (code !== 0) {
            errorText = stderr.trim().length ? stderr.trim() : i18n("tdpctl failed (exit %1)", code)
            return
        }
        try {
            const s = JSON.parse(stdout)
            tdp = s.tdp
            tdpMin = s.tdp_min
            tdpMax = s.tdp_max
            powerNow = s.stapm_w || 0
            tempC = s.temp_c || 0
            boost = s.boost === true
            pcTdpEnabled = s.pc_tdp_enabled !== false
            fanMode = s.fan_mode || "normal"
            fanRpm = s.fan_rpm || 0
            haveData = true
            errorText = ""
        } catch (e) {
            errorText = i18n("Unexpected output from tdpctl")
        }
    }

    Timer {
        interval: root.expanded ? 2000 : 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    compactRepresentation: MouseArea {
        id: compact
        Layout.minimumWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
        Layout.preferredWidth: Layout.minimumWidth
        hoverEnabled: true
        onClicked: root.expanded = !root.expanded
        RowLayout {
            id: row
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: "speedometer"
                Layout.fillHeight: true
                Layout.preferredWidth: height
                active: compact.containsMouse
            }
            PlasmaComponents3.Label {
                visible: Plasmoid.configuration.showWattsInPanel && root.haveData
                text: i18n("%1W", root.tdp)
                font: Kirigami.Theme.smallFont
            }
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        spacing: Kirigami.Units.smallSpacing

        // Header: current limit + live draw
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading {
                level: 3
                text: i18n("TDP limit")
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.Label {
                text: root.haveData ? i18n("%1 W", slider.pressed ? Math.round(slider.value) : root.tdp) : "—"
                font.bold: true
            }
        }

        PlasmaComponents3.Slider {
            id: slider
            Layout.fillWidth: true
            from: root.tdpMin
            to: root.tdpMax
            stepSize: 1
            snapMode: PlasmaComponents3.Slider.SnapAlways
            enabled: root.haveData && !root.busy
            // follow the live value unless the user is dragging
            Binding on value {
                when: !slider.pressed
                value: root.tdp
                restoreMode: Binding.RestoreNone
            }
            onPressedChanged: if (!pressed) root.setTdp(value)
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                text: i18n("%1 W", root.tdpMin)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.Label {
                text: i18n("%1 W", root.tdpMax)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }
        }

        // Presets
        PlasmaComponents3.Label {
            text: i18n("Presets")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            Layout.topMargin: Kirigami.Units.smallSpacing
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Kirigami.Units.smallSpacing
            columnSpacing: Kirigami.Units.smallSpacing
            Repeater {
                model: [
                    { name: Plasmoid.configuration.preset1Name, watts: Plasmoid.configuration.preset1Watts },
                    { name: Plasmoid.configuration.preset2Name, watts: Plasmoid.configuration.preset2Watts },
                    { name: Plasmoid.configuration.preset3Name, watts: Plasmoid.configuration.preset3Watts },
                    { name: Plasmoid.configuration.preset4Name, watts: Plasmoid.configuration.preset4Watts }
                ]
                delegate: PlasmaComponents3.Button {
                    required property var modelData
                    Layout.fillWidth: true
                    text: i18n("%1  ·  %2 W", modelData.name, modelData.watts)
                    checkable: true
                    checked: root.haveData && root.tdp === modelData.watts
                    enabled: root.haveData && !root.busy
                    onClicked: root.setTdp(modelData.watts)
                }
            }
        }

        // Boost toggle
        PlasmaComponents3.Switch {
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: i18n("CPU boost")
            checked: root.boost
            enabled: root.haveData && !root.busy
            onToggled: root.setBoost(checked)
        }

        // Fan mode
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            PlasmaComponents3.Label { text: i18n("Fan") }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.Button {
                text: i18n("Normal")
                checkable: true
                checked: root.fanMode === "normal"
                enabled: root.haveData && !root.busy
                onClicked: root.setFan("normal")
                PlasmaComponents3.ToolTip.text: i18n("Embedded controller's own fan curve")
                PlasmaComponents3.ToolTip.visible: hovered
            }
            PlasmaComponents3.Button {
                text: i18n("Quiet")
                checkable: true
                checked: root.fanMode === "quiet"
                enabled: root.haveData && !root.busy
                onClicked: root.setFan("quiet")
                PlasmaComponents3.ToolTip.text: i18n("Gentler curve: ~1200 rpm at idle, ramps up from 55 °C, full speed above 92 °C")
                PlasmaComponents3.ToolTip.visible: hovered
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; Layout.topMargin: Kirigami.Units.smallSpacing }

        // Live readout
        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon { source: "battery-profile"; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: width }
            PlasmaComponents3.Label {
                text: root.haveData
                    ? i18n("Drawing %1 W  ·  %2 °C  ·  fan %3 rpm", root.powerNow.toFixed(1), Math.round(root.tempC), root.fanRpm)
                    : i18n("Reading…")
                opacity: 0.8
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents3.BusyIndicator { running: root.busy; visible: root.busy; Layout.preferredHeight: Kirigami.Units.iconSizes.small; Layout.preferredWidth: height }
        }

        PlasmaComponents3.Label {
            visible: root.haveData && !root.pcTdpEnabled
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            text: i18n("PowerControl has its TDP limit switched off for the default profile; it will not enforce a limit in SteamOS mode until you turn it on there.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.errorText.length > 0
            type: Kirigami.MessageType.Error
            text: root.errorText
        }
    }
}
