/*
    SPDX-FileCopyrightText: 2016 David Edmundson <davidedmundson@kde.org>
    SPDX-FileCopyrightText: 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>
    SPDX-FileCopyrightText: 2023 ivan tkachenko <me@ratijas.tk>

    SPDX-License-Identifier: LGPL-2.0-or-later

    Vendored from plasma-workspace v6.0.0 lookandfeel/components/VirtualKeyboardLoader.qml.

    Plasma 6.8 dropped this type from org.kde.breeze.components, but the MacTahoe
    theme (based on an older Breeze theme) still instantiates it; when the type is
    missing the greeter logs "VirtualKeyboardLoader is not a type" and falls back
    to the embedded theme. Keep a local copy next to Main.qml so it resolves as a
    file-based type.

    This greeter always runs on Wayland, so pin source to the Wayland variant:
    that also avoids pulling in QtQuick.VirtualKeyboard (the X11 implementation).
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Templates as T
import org.kde.kirigami as Kirigami

Loader {
    id: loader

    required property Item screenRoot
    required property T.StackView mainStack
    required property /* MainBlock | Login */ Item mainBlock
    required property T.TextField passwordField

    readonly property bool keyboardActive: item?.active ?? false

    function showHide() {
        state = state === "hidden" ? "visible" : "hidden";
    }

    source: Qt.resolvedUrl("./VirtualKeyboard_wayland.qml")

    onKeyboardActiveChanged: {
        if (keyboardActive) {
            state = "visible";
            // Otherwise the password field loses focus and virtual keyboard
            // keystrokes get eaten
            passwordField.forceActiveFocus();
        } else {
            state = "hidden";
        }
    }

    // Usually, anchors on a top-level component is a bad idea, but this is a
    // tightly integrated component shared only between lock screen and SDDM
    anchors {
        left: parent.left
        right: parent.right
    }

    state: "hidden"

    states: [
        State {
            name: "visible"
            PropertyChanges {
                target: mainStack
                y: Math.min(0, screenRoot.height - loader.height - mainBlock.visibleBoundary)
            }
            PropertyChanges {
                target: loader
                y: screenRoot.height - loader.height
            }
        },
        State {
            name: "hidden"
            PropertyChanges {
                target: mainStack
                y: 0
            }
            PropertyChanges {
                target: loader
                y: screenRoot.height * 0.75
            }
        }
    ]

    transitions: [
        Transition {
            from: "hidden"
            to: "visible"
            SequentialAnimation {
                ScriptAction {
                    script: {
                        loader.item.activated = true;
                        Qt.inputMethod.show();
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: mainStack
                        property: "y"
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: loader
                        property: "y"
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.OutQuad
                    }
                }
            }
        },
        Transition {
            from: "visible"
            to: "hidden"
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation {
                        target: mainStack
                        property: "y"
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        target: loader
                        property: "y"
                        duration: Kirigami.Units.longDuration
                        easing.type: Easing.InQuad
                    }
                }
                ScriptAction {
                    script: {
                        loader.item.activated = false;
                        Qt.inputMethod.hide();
                    }
                }
            }
        }
    ]
}
