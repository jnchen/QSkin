import QtQuick 2.11
import QtQuick.Window 2.2
import QtQuick.Controls 2.11
Window {
    visible: true
    width: 200
    height: 200
    Calendar { }
    Timer { running: true; interval: 30; onTriggered: Qt.quit(0) }
}
