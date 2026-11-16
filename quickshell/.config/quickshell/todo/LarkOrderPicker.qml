import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import "LarkLogic.js" as L

// "Create a Lark task" view of the todo panel. Top: the task's title and content in
// editable fields — OpenCode reviews them in the background and its rewrite replaces
// the text unless the user already typed (then it is only offered). Below: the open
// orders (search + list) or the "new order" form (title, BU, Loại dự án).
// Clicking an order / "Create order + task" hands the text that is in the two fields
// at that moment (finalTitle / finalContent) to LarkData, which creates the records
// and the local todo (so that still completes if the panel is closed meanwhile).
Item {
    id: root
    property Theme theme: ThemeStore
    property var source: null            // DataProviders.larkData
    property string originalTitle: ""
    property string originalContent: ""
    // yyyymmdd used for "Ngày thực hiện" and "Ngày bắt đầu task".
    property int dateKey: 0
    // Local todo's due (null when none); only the date goes to Lark.
    property var dueKey: null
    property var dueMinutes: null
    signal cancelled()
    // A create request was handed to LarkData from this picker.
    signal sent()

    readonly property string finalTitle: titleField.text.replace(/\s+/g, " ").trim()
    readonly property string finalContent: contentField.text.trim()
    readonly property bool canSend: finalTitle !== "" && source !== null && !source.busy

    // The user typed in a field since it was last filled programmatically.
    property bool edited: false
    // Which text the fields were last filled with: "original" | "ai".
    property string filledWith: "original"
    property bool _filling: false
    property bool formOpen: false
    property string bu: ""
    property string project: ""

    function task() {
        return { title: finalTitle, content: finalContent, dateKey: dateKey,
                 dueKey: dueKey, dueMinutes: dueMinutes }
    }

    // Sending now: the text in the fields is final, a late review must not touch it.
    function freeze() { if (source.reviewing) source.cancelReview() }

    readonly property var shown: source ? L.filterOrders(source.orders, searchField.text) : []

    implicitHeight: col.implicitHeight

    function fill(title, content, which) {
        _filling = true
        titleField.text = title
        contentField.text = content
        _filling = false
        edited = false
        filledWith = which
    }

    function open() {
        fill(originalTitle, originalContent, "original")
        searchField.text = ""
        formOpen = false
        bu = ""
        project = ""
        if (source) {
            source.resetAttempt()
            source.refresh()
            source.startReview(originalTitle, originalContent)
        }
        searchField.forceActiveFocus()
    }

    function pick(orderId) {
        if (!canSend || orderId === "") return
        freeze()
        root.sent()
        source.submit(task(), orderId)
    }

    function createOrder() {
        if (!canSend || !L.validOrderForm(orderTitleField.text, bu, project)) return
        freeze()
        root.sent()
        source.submitWithNewOrder(task(), orderTitleField.text, bu, project)
    }

    function retry() {
        if (!canSend) return
        if (source.lastOrderId !== "") { freeze(); root.sent(); source.retry(task()) }
        else source.refresh()
    }

    function toggleForm() {
        formOpen = !formOpen
        if (formOpen) {
            orderTitleField.text = finalTitle
            orderTitleField.forceActiveFocus()
        } else {
            searchField.forceActiveFocus()
        }
    }

    Connections {
        target: root.source
        enabled: root.visible
        function onReviewChanged() {
            // A hand edit made before the review landed always wins.
            if (root.source.review && !root.edited)
                root.fill(root.source.review.title, root.source.review.content, "ai")
        }
        function onOrderCreated(id, title, bu, project) {
            // The order exists now: leave the form so it cannot be created again.
            root.formOpen = false
            root.bu = ""
            root.project = ""
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 8

        // ── header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            IconButton {
                theme: root.theme
                text: Glyphs.prev
                onClicked: root.cancelled()
            }

            Text {
                text: "Lark task"
                color: theme.text
                font.pixelSize: theme.fontSize + 1
                font.bold: true
                font.family: theme.font
            }

            Item { Layout.fillWidth: true }

            // The one date sent as both "Ngày thực hiện" and "Ngày bắt đầu task".
            Badge {
                visible: root.dateKey !== 0
                theme: root.theme
                text: String(root.dateKey % 100).padStart(2, "0") + "/"
                      + String(Math.floor(root.dateKey / 100) % 100).padStart(2, "0") + "/"
                      + Math.floor(root.dateKey / 10000)
                clr: theme.subtext0
            }
        }

        // ── task text (what will be sent) ──
        TextField {
            id: titleField
            Layout.fillWidth: true
            implicitHeight: 32
            placeholderText: "Task title"
            color: theme.text
            placeholderTextColor: theme.overlay0
            font.pixelSize: theme.fontSize
            font.family: theme.fontUi
            selectByMouse: true
            leftPadding: 10
            rightPadding: 10
            background: Rectangle {
                radius: theme.radiusMd
                color: theme.surface0
                border.color: titleField.activeFocus ? theme.blue : "transparent"
                border.width: 1
            }
            onTextChanged: if (!root._filling) root.edited = true
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.min(Math.max(contentField.implicitHeight, 32),
                                     6 * contentMetrics.height + contentField.topPadding + contentField.bottomPadding)
            radius: theme.radiusMd
            color: theme.surface0
            border.color: contentField.activeFocus ? theme.blue : "transparent"
            border.width: 1

            FontMetrics { id: contentMetrics; font: contentField.font }

            Flickable {
                id: contentFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: contentField.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                function ensureVisible(r) {
                    if (contentY >= r.y) contentY = r.y
                    else if (contentY + height <= r.y + r.height) contentY = r.y + r.height - height
                }

                TextArea {
                    id: contentField
                    width: contentFlick.width
                    placeholderText: "Content (optional)"
                    textFormat: TextEdit.PlainText
                    color: theme.text
                    placeholderTextColor: theme.overlay0
                    font.pixelSize: theme.fontSizeMin
                    font.family: theme.fontUi
                    wrapMode: TextEdit.Wrap
                    selectByMouse: true
                    leftPadding: 10
                    rightPadding: 10
                    topPadding: 8
                    bottomPadding: 8
                    background: null
                    onCursorRectangleChanged: contentFlick.ensureVisible(cursorRectangle)
                    onTextChanged: if (!root._filling) root.edited = true
                }
            }
        }

        // ── review status + switch between the original and the AI text ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi
                color: theme.overlay1
                text: {
                    var s = root.source
                    if (!s) return ""
                    if (s.reviewing) return "OpenCode is reviewing…"
                    if (s.reviewError !== "") return "Review failed — using your text"
                    if (!s.review) return ""
                    if (root.edited) return "Edited by you"
                    return root.filledWith === "ai" ? "Reviewed by OpenCode" : "Your original text"
                }
            }

            Badge {
                readonly property bool showsAi: root.filledWith === "ai" && !root.edited
                visible: !!(root.source && root.source.review)
                theme: root.theme
                text: showsAi ? "Use original" : "Use AI text"
                clickable: true
                clr: theme.blue
                implicitHeight: 22
                onClicked: {
                    if (showsAi) root.fill(root.originalTitle, root.originalContent, "original")
                    else root.fill(root.source.review.title, root.source.review.content, "ai")
                }
            }
        }

        // ── order: search + list ──
        TextField {
            id: searchField
            visible: !root.formOpen
            Layout.fillWidth: true
            implicitHeight: 30
            placeholderText: "Search order…"
            color: theme.text
            placeholderTextColor: theme.overlay0
            font.pixelSize: theme.fontSize
            font.family: theme.fontUi
            selectByMouse: true
            leftPadding: 10
            rightPadding: 10
            background: Rectangle {
                radius: theme.radiusMd
                color: theme.surface0
                border.color: searchField.activeFocus ? theme.blue : "transparent"
                border.width: 1
            }
        }

        Item {
            visible: !root.formOpen
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 80
            implicitHeight: 260

            ListView {
                id: orderList
                anchors.fill: parent
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.shown
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: orderRow
                    required property var modelData
                    width: ListView.view.width
                    height: 40
                    radius: theme.radiusSm
                    color: rowMa.containsMouse && root.canSend ? theme.surface0 : "transparent"
                    opacity: root.canSend ? 1 : 0.5

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBottom
                            text: orderRow.modelData.title
                            textFormat: Text.PlainText
                            color: theme.text
                            font.pixelSize: theme.fontSize
                            font.family: theme.fontUi
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignTop
                            text: [orderRow.modelData.bu, orderRow.modelData.project, orderRow.modelData.status]
                                  .filter(function (s) { return s !== "" }).join(" · ")
                            textFormat: Text.PlainText
                            color: theme.subtext0
                            font.pixelSize: theme.fontSizeMin
                            font.family: theme.fontUi
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.canSend
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(orderRow.modelData.id)
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: orderList.count === 0
                text: root.source && root.source.loading ? "Loading…"
                    : searchField.text.trim() !== "" ? "No matching order" : "No open order"
                color: theme.subtext0
                font.pixelSize: theme.fontSize
                font.family: theme.fontUi
            }
        }

        // ── new order form ──
        ColumnLayout {
            visible: root.formOpen
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: orderTitleField
                Layout.fillWidth: true
                implicitHeight: 30
                placeholderText: "Order title"
                color: theme.text
                placeholderTextColor: theme.overlay0
                font.pixelSize: theme.fontSize
                font.family: theme.fontUi
                selectByMouse: true
                leftPadding: 10
                rightPadding: 10
                background: Rectangle {
                    radius: theme.radiusMd
                    color: theme.surface0
                    border.color: orderTitleField.activeFocus ? theme.blue : "transparent"
                    border.width: 1
                }
            }

            Repeater {
                model: [
                    { label: "BU", options: root.source ? root.source.buOptions : [], isBu: true },
                    { label: "Loại dự án", options: root.source ? root.source.projectOptions : [], isBu: false }
                ]

                delegate: ColumnLayout {
                    id: group
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: group.modelData.label
                        color: theme.subtext0
                        font.pixelSize: theme.fontSizeMin
                        font.family: theme.fontUi
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 4

                        Repeater {
                            model: group.modelData.options

                            delegate: Badge {
                                required property string modelData
                                readonly property bool on: (group.modelData.isBu ? root.bu : root.project) === modelData
                                theme: root.theme
                                text: modelData
                                clickable: true
                                solid: on
                                clr: on ? theme.highlight : theme.subtext0
                                implicitHeight: 22
                                onClicked: {
                                    if (group.modelData.isBu) root.bu = on ? "" : modelData
                                    else root.project = on ? "" : modelData
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── error; Retry reuses the order of the failed attempt, or reloads the list ──
        RowLayout {
            visible: !!(root.source && root.source.error !== "")
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.source ? root.source.error : ""
                textFormat: Text.PlainText
                color: theme.red
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi
                wrapMode: Text.Wrap
            }

            Badge {
                theme: root.theme
                text: root.source && root.source.lastOrderId !== "" ? "Retry" : "Reload"
                clickable: root.canSend
                clr: theme.red
                implicitHeight: 22
                onClicked: root.retry()
            }
        }

        // ── bottom: toggle the form / create the order ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Badge {
                theme: root.theme
                text: root.formOpen ? "Back to orders" : "  New order"   // nf-fa-plus
                clickable: true
                clr: theme.subtext0
                implicitHeight: 24
                onClicked: root.toggleForm()
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                visible: !!(root.source && root.source.busy)
                text: "Creating…"
                color: theme.overlay1
                font.pixelSize: theme.fontSizeMin
                font.family: theme.fontUi
            }

            Item { Layout.fillWidth: true; visible: !(root.source && root.source.busy) }

            Badge {
                readonly property bool ready: root.canSend
                    && L.validOrderForm(orderTitleField.text, root.bu, root.project)
                visible: root.formOpen
                theme: root.theme
                text: "Create order + task"
                clickable: ready
                opacity: ready ? 1 : 0.45
                solid: ready
                clr: ready ? theme.highlight : theme.subtext0
                implicitHeight: 24
                onClicked: root.createOrder()
            }
        }
    }
}
