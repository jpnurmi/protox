import QtQuick 2.12
import QtQuick.Dialogs 1.2

ColorDialog {
    id: colorDebugDialog
    property variant resultColor
    onAccepted: {
        console.log("You chose color: " + color)
        resultColor = color
    }
}
