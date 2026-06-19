import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.common

Item {
    id: root
    property Theme theme: Theme {}
    property bool active: false
    signal close()
    signal barRefreshRequested()

    property var weatherData: ({
        icon: "",
        temp: "--",
        feelsLike: "--",
        humidity: "--",
        wind: "--",
        windDir: "",
        condition: "Loading...",
        location: "",
        country: "",
        sunrise: "",
        sunset: "",
        pressure: "",
        uvIndex: "",
        visibility: "",
        cloudcover: "",
        precipMM: "",
        hourly: [],
        daily: []
    })

    clip: true
    implicitWidth: 380
    implicitHeight: contentLayout.implicitHeight + headerLayout.implicitHeight + 60

    Rectangle {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 16
        bottomRightRadius: 16
        color: theme.color
        border.color: theme.surface0
        border.width: 2

        // mask top border
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: theme.color
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            id: headerLayout
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Weather"
                color: theme.text
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
                Layout.fillWidth: true
            }

                Text {
                    text: "Refresh"
                    color: theme.blue
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            fetchProc.running = true
                            root.barRefreshRequested()
                        }
                    }
                }

            Text {
                text: "×"
                color: theme.subtext0
                font.pixelSize: theme.fontSize + 4

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.close()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.surface0
        }

        ColumnLayout {
            id: contentLayout
            Layout.fillWidth: true
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.weatherData.location !== ""

                Text {
                    text: root.weatherData.location + (root.weatherData.country ? ", " + root.weatherData.country : "")
                    color: theme.subtext1
                    font.pixelSize: theme.fontSize - 1
                    font.family: theme.font
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Text {
                    text: root.weatherData.icon
                    font.pixelSize: 48
                    font.family: theme.font
                }

                ColumnLayout {
                    spacing: 2

                    Text {
                        text: root.weatherData.temp + "°C"
                        color: theme.text
                        font.pixelSize: 36
                        font.bold: true
                        font.family: theme.font
                    }

                    Text {
                        text: root.weatherData.condition
                        color: theme.subtext1
                        font.pixelSize: theme.fontSize
                        font.family: theme.font
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.surface0
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 6
                columnSpacing: 12

                Repeater {
                    model: [
                        { icon: "🌡", label: "Feels like", value: root.weatherData.feelsLike + "°C" },
                        { icon: "💧", label: "Humidity", value: root.weatherData.humidity + "%" },
                        { icon: "💨", label: "Wind", value: (root.weatherData.windDir ? root.weatherData.windDir + " " : "") + root.weatherData.wind + " km/h" },
                        { icon: "🌡", label: "Pressure", value: root.weatherData.pressure + " hPa" },
                        { icon: "☀", label: "UV Index", value: root.weatherData.uvIndex },
                        { icon: "👁", label: "Visibility", value: root.weatherData.visibility + " km" },
                        { icon: "🌅", label: "Sunrise", value: root.weatherData.sunrise },
                        { icon: "🌇", label: "Sunset", value: root.weatherData.sunset }
                    ]
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: root.width / 2 - 20
                        spacing: 6

                        Text {
                            text: modelData.icon
                            font.pixelSize: theme.fontSize
                            font.family: theme.font
                        }

                        Text {
                            text: modelData.label
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }

                        Text {
                            text: modelData.value
                            color: theme.text
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.surface0
                visible: root.weatherData.hourly.length > 0
            }

            Text {
                text: "Hourly"
                color: theme.subtext1
                font.pixelSize: theme.fontSize
                font.bold: true
                font.family: theme.font
                visible: root.weatherData.hourly.length > 0
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.weatherData.hourly.length > 0

                Repeater {
                    model: root.weatherData.hourly
                    delegate: ColumnLayout {
                        Layout.preferredWidth: 56
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.time
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 2
                            font.family: theme.font
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.temp + "°"
                            color: theme.text
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: modelData.chanceofrain && modelData.chanceofrain > 0
                            text: "💧" + modelData.chanceofrain + "%"
                            color: theme.blue
                            font.pixelSize: theme.fontSize - 3
                            font.family: theme.font
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: theme.surface0
                visible: root.weatherData.daily.length > 0
            }

            Text {
                text: "Forecast"
                color: theme.subtext1
                font.pixelSize: theme.fontSize
                font.bold: true
                font.family: theme.font
                visible: root.weatherData.daily.length > 0
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.weatherData.daily.length > 0

                Repeater {
                    model: root.weatherData.daily
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: {
                                var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                                var d = new Date(modelData.date)
                                if (isNaN(d.getTime())) return modelData.date
                                return days[d.getDay()]
                            }
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.maxTemp + "°"
                            color: theme.text
                            font.pixelSize: theme.fontSize - 1
                            font.family: theme.font
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.minTemp + "°"
                            color: theme.subtext0
                            font.pixelSize: theme.fontSize - 2
                            font.family: theme.font
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: modelData.chanceofrain && modelData.chanceofrain > 0
                            text: "💧" + modelData.chanceofrain + "%"
                            color: theme.blue
                            font.pixelSize: theme.fontSize - 3
                            font.family: theme.font
                        }
                    }
                }
            }
        }
    }

    Process {
        id: fetchProc
        command: ["/bin/bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/weather-detail.sh"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.weatherData = JSON.parse(this.text)
                } catch (e) {
                    console.log("Failed to parse weather:", e)
                }
            }
        }
    }

    Timer {
        interval: 600000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!fetchProc.running) fetchProc.running = true
        }
    }
}
