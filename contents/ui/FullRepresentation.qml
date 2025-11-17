import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.extras 2.0 as PlasmaExtras

ColumnLayout {
    Layout.minimumWidth: 250
    Layout.minimumHeight: 300
    spacing: 10
    
    PlasmaExtras.Heading {
        level: 3
        text: "Prayer Times"
        Layout.alignment: Qt.AlignHCenter
    }
    
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: "gray"
    }
    
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        
        Repeater {
            model: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
            
            RowLayout {
                Layout.fillWidth: true
                
                Rectangle {
                    width: 4
                    height: parent.height
                    color: modelData === root.nextPrayer ? "#4CAF50" : "transparent"
                }
                
                PlasmaComponents3.Label {
                    text: modelData
                    font.bold: modelData === root.nextPrayer
                    Layout.preferredWidth: 80
                }
                
                PlasmaComponents3.Label {
                    text: root.prayerTimes[modelData] || "--:--"
                    font.bold: modelData === root.nextPrayer
                    Layout.alignment: Qt.AlignRight
                }
                
                Item { Layout.fillWidth: true }
            }
        }
    }
    
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: "gray"
    }
    
    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 10
        spacing: 5
        
        PlasmaComponents3.Label {
            text: "Next: " + root.nextPrayer
            font.bold: true
            font.pixelSize: 14
        }
        
        PlasmaComponents3.Label {
            text: "Time: " + root.nextPrayerTime
            font.pixelSize: 12
        }
        
        PlasmaComponents3.Label {
            text: "In: " + root.formatCountdown(root.secondsUntilNext)
            font.pixelSize: 12
            color: root.secondsUntilNext <= (root.notificationMinutes * 60) ? "#ff6b6b" : "lightgray"
        }
    }
    
    Item { Layout.fillHeight: true }
    
    PlasmaComponents3.Button {
        text: "Configure"
        Layout.alignment: Qt.AlignHCenter
        onClicked: plasmoid.action("configure").trigger()
    }
}
