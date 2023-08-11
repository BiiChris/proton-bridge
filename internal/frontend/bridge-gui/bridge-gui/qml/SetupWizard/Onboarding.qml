// Copyright (c) 2023 Proton AG
// This file is part of Proton Mail Bridge.
// Proton Mail Bridge is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// Proton Mail Bridge is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// You should have received a copy of the GNU General Public License
// along with Proton Mail Bridge. If not, see <https://www.gnu.org/licenses/>.
import QtQml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.impl
import "." as Proton

Item {
    id: root
    property var wizard

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 96

        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            colorScheme: wizard.colorScheme
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Two-step process")
            type: Label.LabelType.Heading
        }
        StepDescriptionBox {
            colorScheme: wizard.colorScheme
            description: qsTr("Connect Bridge to your Proton account")
            icon: "/qml/icons/ic-bridge.svg"
            iconSize: 48
            title: qsTr("Step 1")
        }
        StepDescriptionBox {
            colorScheme: wizard.colorScheme
            description: qsTr("Connect your email client to Bridge")
            icon: "/qml/icons/img-mail-clients.svg"
            iconSize: 64
            title: qsTr("Step 2")
        }
        Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            colorScheme: wizard.colorScheme
            text: qsTr("Let's start")

            onClicked: wizard.showLogin();
        }
    }
}