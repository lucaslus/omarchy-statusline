import QtQuick
Rectangle {
    id: root
    property var value: null
    property color ink: "#ffffff"
    radius: 2
    color: Qt.alpha(ink, 0.16)
    Rectangle {
        width: root.width * Math.max(0, Math.min(100, root.value || 0)) / 100
        height: root.height
        radius: root.radius
        color: root.ink
        Behavior on width { NumberAnimation { duration: 250 } }
    }
}
