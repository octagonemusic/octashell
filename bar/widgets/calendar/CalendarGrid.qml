import QtQuick
import qs.theme

Item {
    id: root

    property date currentDate: new Date()
    property date liveTime: new Date()
    property int displayMonth: currentDate.getMonth()
    property int displayYear: currentDate.getFullYear()

    property int selectedDay: currentDate.getDate()
    property int selectedMonth: currentDate.getMonth()
    property int selectedYear: currentDate.getFullYear()

    property bool isMonthYearView: false

    property bool isWindowVisible: true

    property int activeCellIndex: {
        if (displayMonth === selectedMonth && displayYear === selectedYear) {
            let firstDay = new Date(displayYear, displayMonth, 1).getDay();
            return firstDay + selectedDay - 1;
        }
        return -1;
    }

    property int lastValidIndex: activeCellIndex !== -1 ? activeCellIndex : 0
    onActiveCellIndexChanged: {
        if (activeCellIndex !== -1) {
            lastValidIndex = activeCellIndex;
        }
    }

    signal requestClose

    // Wheel/Scroll Logic
    WheelHandler {
        id: swipeHandler
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        orientation: Qt.Horizontal | Qt.Vertical

        property real accumulateX: 0
        property real accumulateY: 0

        onActiveChanged: {
            if (!active) {
                accumulateX = 0;
                accumulateY = 0;
            }
        }

        onWheel: event => {
            if (swipeAnim.running)
                return;

            let isTrackpad = (event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0);
            accumulateX += isTrackpad ? event.pixelDelta.x : event.angleDelta.x;
            accumulateY += isTrackpad ? event.pixelDelta.y : event.angleDelta.y;

            let threshold = isTrackpad ? 40 : 120;

            if (Math.abs(accumulateX) > Math.abs(accumulateY)) {
                if (accumulateX > threshold) {
                    triggerSwipe(-1);
                    accumulateX = 0;
                } else if (accumulateX < -threshold) {
                    triggerSwipe(1);
                    accumulateX = 0;
                }
            } else {
                if (accumulateY > threshold) {
                    triggerSwipe(-1);
                    accumulateY = 0;
                } else if (accumulateY < -threshold) {
                    triggerSwipe(1);
                    accumulateY = 0;
                }
            }
        }
    }

    focus: true

    // Timers & Init
    Timer {
        interval: 1000
        running: root.isWindowVisible
        repeat: true
        onTriggered: root.liveTime = new Date()
    }

    Component.onCompleted: generateCalendar()

    onIsWindowVisibleChanged: {
        if (isWindowVisible) {
            let d = new Date();
            root.liveTime = d;

            selectedDay = d.getDate();
            selectedMonth = d.getMonth();
            selectedYear = d.getFullYear();
            displayMonth = selectedMonth;
            displayYear = selectedYear;
            isMonthYearView = false;
            swipeTransform.x = 0;
            generateCalendar();
        }
    }

    // Core Logic Functions
    function generateCalendar() {
        calendarModel.clear();
        let firstDay = new Date(displayYear, displayMonth, 1).getDay();
        let daysInMonth = new Date(displayYear, displayMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(displayYear, displayMonth, 0).getDate();

        for (let i = 0; i < 42; i++) {
            if (i < firstDay) {
                calendarModel.append({
                    dayText: (daysInPrevMonth - firstDay + i + 1).toString(),
                    isCurrentMonth: false,
                    isToday: false
                });
            } else if (i >= firstDay && i < firstDay + daysInMonth) {
                let dayNum = i - firstDay + 1;
                let isTodayCheck = (dayNum === currentDate.getDate() && displayMonth === currentDate.getMonth() && displayYear === currentDate.getFullYear());
                calendarModel.append({
                    dayText: dayNum.toString(),
                    isCurrentMonth: true,
                    isToday: isTodayCheck
                });
            } else {
                calendarModel.append({
                    dayText: (i - firstDay - daysInMonth + 1).toString(),
                    isCurrentMonth: false,
                    isToday: false
                });
            }
        }
    }

    function syncSelection() {
        root.selectedMonth = root.displayMonth;
        root.selectedYear = root.displayYear;
        let maxDays = new Date(root.displayYear, root.displayMonth + 1, 0).getDate();
        if (root.selectedDay > maxDays)
            root.selectedDay = maxDays;
    }

    function moveSelection(daysOffset) {
        let d = new Date(selectedYear, selectedMonth, selectedDay + daysOffset);
        let oldMonth = selectedMonth;
        let oldYear = selectedYear;

        selectedDay = d.getDate();
        selectedMonth = d.getMonth();
        selectedYear = d.getFullYear();

        if (selectedMonth !== oldMonth || selectedYear !== oldYear) {
            let isForward = d.getTime() > new Date(oldYear, oldMonth, 15).getTime();
            if (!swipeAnim.running) {
                triggerSwipe(isForward ? 1 : -1);
            } else {
                displayMonth = selectedMonth;
                displayYear = selectedYear;
                generateCalendar();
            }
        }
    }

    function jumpToToday() {
        currentDate = new Date();
        selectedDay = currentDate.getDate();
        selectedMonth = currentDate.getMonth();
        selectedYear = currentDate.getFullYear();

        if (displayMonth !== selectedMonth || displayYear !== selectedYear) {
            displayMonth = selectedMonth;
            displayYear = selectedYear;
            swipeTransform.x = 0;
            viewsContainer.scale = 0.8;
            generateCalendar();
            bounceIn.start();
        }
    }

    function triggerSwipe(direction) {
        if (!swipeAnim.running) {
            swipeAnim.direction = direction;
            swipeAnim.start();
        }
    }

    // Keyboard Logic
    Keys.onPressed: event => {
        let isShift = event.modifiers & Qt.ShiftModifier;
        if (isMonthYearView) {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                if (isShift)
                    displayYear--;
                else
                    displayMonth = (displayMonth - 1 + 12) % 12;
                syncSelection();
                generateCalendar();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                if (isShift)
                    displayYear++;
                else
                    displayMonth = (displayMonth + 1) % 12;
                syncSelection();
                generateCalendar();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                displayMonth = (displayMonth - 4 + 12) % 12;
                syncSelection();
                generateCalendar();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                displayMonth = (displayMonth + 4) % 12;
                syncSelection();
                generateCalendar();
                event.accepted = true;
            } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Equal || event.key === Qt.Key_Plus) {
                displayYear++;
                syncSelection();
                generateCalendar();
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Minus) {
                displayYear--;
                syncSelection();
                generateCalendar();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Space || event.key === Qt.Key_Escape) {
                isMonthYearView = false;
                event.accepted = true;
            }
        } else {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                moveSelection(-1);
                event.accepted = true;
            }
            if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                moveSelection(1);
                event.accepted = true;
            }
            if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                moveSelection(-7);
                event.accepted = true;
            }
            if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                moveSelection(7);
                event.accepted = true;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
                isMonthYearView = true;
                event.accepted = true;
            }
            if (event.key === Qt.Key_T) {
                jumpToToday();
                event.accepted = true;
            }
            if (event.key === Qt.Key_Escape) {
                requestClose();
                event.accepted = true;
            }
        }
    }

    // Animations
    SequentialAnimation {
        id: swipeAnim
        property int direction: 1

        NumberAnimation {
            target: swipeTransform
            property: "x"
            to: swipeAnim.direction * -382
            duration: 120
            easing.type: Easing.InSine
        }
        ScriptAction {
            script: {
                displayMonth += swipeAnim.direction;
                if (displayMonth < 0) {
                    displayMonth = 11;
                    displayYear--;
                } else if (displayMonth > 11) {
                    displayMonth = 0;
                    displayYear++;
                }
                syncSelection();
                generateCalendar();
                swipeTransform.x = swipeAnim.direction * 382;
            }
        }
        NumberAnimation {
            target: swipeTransform
            property: "x"
            to: 0
            duration: 250
            easing.type: Easing.OutBack
            easing.overshoot: 1.05
        }
    }

    NumberAnimation {
        id: bounceIn
        target: viewsContainer
        property: "scale"
        from: 0.8
        to: 1
        duration: 250
        easing.type: Easing.OutBack
        easing.overshoot: 1.05
    }

    // Data Models
    ListModel {
        id: calendarModel
    }

    // Layout
    Row {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 32

        ClockPane {
            liveTime: root.liveTime
            selectedDay: root.selectedDay
            selectedMonth: root.selectedMonth
            selectedYear: root.selectedYear
            height: parent.height

            isWindowVisible: root.isWindowVisible
        }

        Item {
            width: 382
            height: parent.height

            CalendarHeader {
                id: headerItem
                width: parent.width
                z: 2
                isMonthYearView: root.isMonthYearView
                displayMonth: root.displayMonth
                displayYear: root.displayYear

                onToggleView: root.isMonthYearView = !root.isMonthYearView
                onJumpToToday: root.jumpToToday()
                onPreviousClicked: root.triggerSwipe(-1)
                onNextClicked: root.triggerSwipe(1)
            }

            Item {
                id: viewsContainer
                width: parent.width + 20
                height: 380
                anchors.top: headerItem.bottom
                anchors.topMargin: 24
                clip: true

                DaysView {
                    anchors.fill: parent
                    opacity: root.isMonthYearView ? 0 : 1
                    scale: root.isMonthYearView ? 0.95 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.05
                        }
                    }

                    transform: Translate {
                        id: swipeTransform
                        x: 0
                    }

                    model: calendarModel
                    activeCellIndex: root.activeCellIndex
                    lastValidIndex: root.lastValidIndex
                    selectedDay: root.selectedDay
                    selectedMonth: root.selectedMonth
                    selectedYear: root.selectedYear
                    displayMonth: root.displayMonth
                    displayYear: root.displayYear

                    onDaySelected: day => {
                        root.selectedDay = day;
                        root.selectedMonth = root.displayMonth;
                        root.selectedYear = root.displayYear;
                    }
                }

                MonthYearSelector {
                    anchors.fill: parent
                    opacity: root.isMonthYearView ? 1 : 0
                    scale: root.isMonthYearView ? 1 : 0.95
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.05
                        }
                    }

                    displayYear: root.displayYear
                    displayMonth: root.displayMonth

                    onPreviousYear: {
                        root.displayYear--;
                        root.syncSelection();
                        root.generateCalendar();
                    }
                    onNextYear: {
                        root.displayYear++;
                        root.syncSelection();
                        root.generateCalendar();
                    }
                    onMonthSelected: index => {
                        root.displayMonth = index;
                        root.syncSelection();
                        root.generateCalendar();
                        root.isMonthYearView = false;
                    }
                }
            }
        }
    }
}
