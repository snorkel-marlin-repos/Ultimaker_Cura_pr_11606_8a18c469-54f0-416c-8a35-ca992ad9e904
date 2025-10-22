// Copyright (c) 2021 Ultimaker B.V.
// Cura is released under the terms of the LGPLv3 or higher.

import QtQuick 2.10
import QtQuick.Controls 2.3

import UM 1.5 as UM
import Cura 1.1 as Cura


//
// Cura-style TextField
//
TextField
{
    id: textField

    property alias leftIcon: iconLeft.source

    height: UM.Theme.getSize("setting_control").height

    hoverEnabled: true
    selectByMouse: true
    font: UM.Theme.getFont("default")
    color: UM.Theme.getColor("text")
    renderType: Text.NativeRendering
    selectionColor: UM.Theme.getColor("text_selection")
    leftPadding: iconLeft.visible ? iconLeft.width + UM.Theme.getSize("default_margin").width * 2 : UM.Theme.getSize("thin_margin").width

    states: [
        State
        {
            name: "disabled"
            when: !textField.enabled
            PropertyChanges { target: backgroundRectangle; color: UM.Theme.getColor("setting_control_disabled")}
        },
        State
        {
            name: "invalid"
            when: !textField.acceptableInput
            PropertyChanges { target: backgroundRectangle; color: UM.Theme.getColor("setting_validation_error_background")}
        },
        State
        {
            name: "hovered"
            when: textField.hovered || textField.activeFocus
            PropertyChanges { target: backgroundRectangle; liningColor: UM.Theme.getColor("border_main_light")}
        }
    ]

    background: UM.UnderlineBackground
    {
        id: backgroundRectangle
        //Optional icon added on the left hand side.
        UM.RecolorImage
        {
            id: iconLeft

            anchors
            {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: UM.Theme.getSize("default_margin").width
            }

            visible: source != ""
            height: UM.Theme.getSize("small_button_icon").height
            width: visible ? height : 0
            color: textField.color
        }
    }
}
