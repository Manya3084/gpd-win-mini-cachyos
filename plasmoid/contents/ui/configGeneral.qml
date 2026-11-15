import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_preset1Name: name1.text
    property alias cfg_preset1Watts: watts1.value
    property alias cfg_preset2Name: name2.text
    property alias cfg_preset2Watts: watts2.value
    property alias cfg_preset3Name: name3.text
    property alias cfg_preset3Watts: watts3.value
    property alias cfg_preset4Name: name4.text
    property alias cfg_preset4Watts: watts4.value
    property alias cfg_showWattsInPanel: showWatts.checked

    Kirigami.FormLayout {
        RowLayout { Kirigami.FormData.label: i18n("Preset 1:"); QQC2.TextField { id: name1 } QQC2.SpinBox { id: watts1; from: 5; to: 35 } QQC2.Label { text: "W" } }
        RowLayout { Kirigami.FormData.label: i18n("Preset 2:"); QQC2.TextField { id: name2 } QQC2.SpinBox { id: watts2; from: 5; to: 35 } QQC2.Label { text: "W" } }
        RowLayout { Kirigami.FormData.label: i18n("Preset 3:"); QQC2.TextField { id: name3 } QQC2.SpinBox { id: watts3; from: 5; to: 35 } QQC2.Label { text: "W" } }
        RowLayout { Kirigami.FormData.label: i18n("Preset 4:"); QQC2.TextField { id: name4 } QQC2.SpinBox { id: watts4; from: 5; to: 35 } QQC2.Label { text: "W" } }
        QQC2.CheckBox { id: showWatts; Kirigami.FormData.label: i18n("Panel:"); text: i18n("Show current limit next to the icon") }
    }
}
