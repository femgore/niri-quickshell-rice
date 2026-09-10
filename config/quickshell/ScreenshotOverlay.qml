import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root
    color: "transparent"

    WlrLayershell.namespace: "qs-screenshot-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    
    exclusionMode: ExclusionMode.Ignore 
    focusable: true
    screen: Quickshell.cursorScreen
    width: screen.width
    height: screen.height

    Caching { id: paths }

    Scaler { id: scaler; currentWidth: width }
    function s(val) { return scaler.s(val); }
    
    MatugenColors { id: _theme }
    property color dimColor: Qt.alpha(_theme.crust, 0.50)
    property color selectionTint: Qt.alpha(_theme.mauve, 0.05)
    property color handleColor: _theme.text
    property color accentColor: _theme.mauve

    property bool isEditMode: Quickshell.env("QS_SCREENSHOT_EDIT") === "true"
    property bool isClipboardOnly: Quickshell.env("QS_SCREENSHOT_CLIPBOARD_ONLY") === "true"
    property string freezePath: Quickshell.env("QS_SCREENSHOT_FREEZE_PATH") || ""
    
    property string cachedMode: Quickshell.env("QS_CACHED_MODE") || "false"
    property bool isVideoMode: cachedMode === "true"

    onIsVideoModeChanged: {
        Quickshell.execDetached([
            "bash",
            "-c",
            "echo '" + (root.isVideoMode ? "true" : "false")
            + "' > " + paths.getCacheDir("screenshot") + "/video_mode"
        ])

        // Keep the current selection when switching between
        // screenshot and recording modes.
        root.isMaximized =
        root.hasSelection
        && root.selX <= 1
        && root.selY <= 1
        && root.selW >= root.width - 2
        && root.selH >= root.height - 2
    }
    // --- Audio State Persistence ---
    property real deskVol: Quickshell.env("QS_DESK_VOL") ? parseFloat(Quickshell.env("QS_DESK_VOL")) : 1.0
    property bool deskMute: Quickshell.env("QS_DESK_MUTE") === "true"
    property real micVol: Quickshell.env("QS_MIC_VOL") ? parseFloat(Quickshell.env("QS_MIC_VOL")) : 1.0
    property bool micMute: Quickshell.env("QS_MIC_MUTE") === "true"
    property string micDevice: Quickshell.env("QS_MIC_DEV") || ""

    function saveAudioPrefs() {
        let data = `${deskVol},${deskMute},${micVol},${micMute},${micDevice}`
        Quickshell.execDetached(["bash", "-c", `echo '${data}' > ${paths.getStateDir("screenshot")}/audio_prefs`])
    }

    // --- Dynamic Mic Loader ---
    ListModel { id: micModel }
    
    Component.onCompleted: {
        let micData = Quickshell.env("QS_MIC_LIST") || ""
        if (micData.trim() !== "") {
            let lines = micData.trim().split('\n')
            for (let line of lines) {
                let parts = line.split('|')
                if (parts.length >= 2) {
                    micModel.append({ devName: parts[0], devDesc: parts.slice(1).join('|') })
                }
            }
        }
        
        if (root.micDevice === "" && micModel.count > 0) {
            root.micDevice = micModel.get(0).devName
            saveAudioPrefs()
        }
    }

    // --- Geometry State ---
    property string cachedGeom: Quickshell.env("QS_CACHED_GEOM") || ""
    property var cachedParts: cachedGeom.trim() !== "" ? cachedGeom.trim().split(",") : []
    property bool hasValidCache: cachedParts.length === 4 && parseFloat(cachedParts[2]) > 10

    property real startX: hasValidCache ? parseFloat(cachedParts[0]) : 0
    property real startY: hasValidCache ? parseFloat(cachedParts[1]) : 0
    property real endX: hasValidCache ? (parseFloat(cachedParts[0]) + parseFloat(cachedParts[2])) : 0
    property real endY: hasValidCache ? (parseFloat(cachedParts[1]) + parseFloat(cachedParts[3])) : 0
    
    // Fluid Geometry Snapping
    Behavior on startX { enabled: !root.isSelecting; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
    Behavior on startY { enabled: !root.isSelecting; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
    Behavior on endX { enabled: !root.isSelecting; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
    Behavior on endY { enabled: !root.isSelecting; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

    property bool hasSelection: hasValidCache
    property bool isSelecting: false
    property bool isMaximized: false
    property real preStartX: 0
    property real preStartY: 0
    property real preEndX: 0
    property real preEndY: 0

    property real selX: Math.min(startX, endX)
    property real selY: Math.min(startY, endY)
    property real selW: Math.abs(endX - startX)
    property real selH: Math.abs(endY - startY)
    
    property string geometryString: `${Math.round(selX + screen.x)},${Math.round(selY + screen.y)} ${Math.round(selW)}x${Math.round(selH)}`
    property int interactionMode: 0
    property real anchorX: 0; property real anchorY: 0
    property real initX: 0; property real initY: 0
    property real initW: 0; property real initH: 0

    // --- QR Scanner State ---
    property bool isScanningQr: false
    property bool showQrPopup: false
    property bool isQrSuccess: false
    ListModel { id: qrModel }

    // --- Censor Drawing State ---
    property bool drawMode: false
    property string drawTool: "brush"
    property string drawColor: "#000000"
    property bool smartColor: false
    property bool showColorPicker: false
    property real pickerHue: 0
    property real pickerSat: 0
    property real pickerValue: 0
    property real pickerAlpha: 1
    property bool syncingColorInputs: false
    property int brushSize: 28
    property real drawAnchorX: 0
    property real drawAnchorY: 0
    property var currentShape: null
    property var annotations: []
    property real smartSampleX: 0
    property real smartSampleY: 0

    function globalX(x) { return Math.round(root.screen.x + x); }
    function globalY(y) { return Math.round(root.screen.y + y); }
    function shellQuote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'"; }
    function clampUnit(value) { return Math.max(0, Math.min(1, Number(value) || 0)); }
    function clampByte(value) { return Math.max(0, Math.min(255, Math.round(Number(value) || 0))); }
    function hexByte(value) {
        let text = root.clampByte(value).toString(16);
        return text.length === 1 ? "0" + text : text;
    }

    function hslToRgb(h, s, l) {
        h = ((Number(h) % 360) + 360) % 360;
        s = root.clampUnit(s);
        l = root.clampUnit(l);
        let c = (1 - Math.abs(2 * l - 1)) * s;
        let x = c * (1 - Math.abs((h / 60) % 2 - 1));
        let m = l - c / 2;
        let r = 0, g = 0, b = 0;
        if (h < 60) { r = c; g = x; }
        else if (h < 120) { r = x; g = c; }
        else if (h < 180) { g = c; b = x; }
        else if (h < 240) { g = x; b = c; }
        else if (h < 300) { r = x; b = c; }
        else { r = c; b = x; }
        return {
            r: Math.round((r + m) * 255),
            g: Math.round((g + m) * 255),
            b: Math.round((b + m) * 255)
        };
    }

    function rgbToHsl(r, g, b) {
        r = root.clampByte(r) / 255;
        g = root.clampByte(g) / 255;
        b = root.clampByte(b) / 255;
        let max = Math.max(r, g, b);
        let min = Math.min(r, g, b);
        let h = 0;
        let l = (max + min) / 2;
        let d = max - min;
        let s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1));
        if (d !== 0) {
            if (max === r) h = 60 * (((g - b) / d) % 6);
            else if (max === g) h = 60 * (((b - r) / d) + 2);
            else h = 60 * (((r - g) / d) + 4);
        }
        return { h: (h + 360) % 360, s: s, l: l };
    }

    function hsvToRgb(h, s, v) {
        h = ((Number(h) % 360) + 360) % 360;
        s = root.clampUnit(s);
        v = root.clampUnit(v);
        let c = v * s;
        let x = c * (1 - Math.abs((h / 60) % 2 - 1));
        let m = v - c;
        let r = 0, g = 0, b = 0;
        if (h < 60) { r = c; g = x; }
        else if (h < 120) { r = x; g = c; }
        else if (h < 180) { g = c; b = x; }
        else if (h < 240) { g = x; b = c; }
        else if (h < 300) { r = x; b = c; }
        else { r = c; b = x; }
        return {
            r: Math.round((r + m) * 255),
            g: Math.round((g + m) * 255),
            b: Math.round((b + m) * 255)
        };
    }

    function rgbToHsv(r, g, b) {
        r = root.clampByte(r) / 255;
        g = root.clampByte(g) / 255;
        b = root.clampByte(b) / 255;
        let max = Math.max(r, g, b);
        let min = Math.min(r, g, b);
        let d = max - min;
        let h = 0;
        if (d !== 0) {
            if (max === r) h = 60 * (((g - b) / d) % 6);
            else if (max === g) h = 60 * (((b - r) / d) + 2);
            else h = 60 * (((r - g) / d) + 4);
        }
        return { h: (h + 360) % 360, s: max === 0 ? 0 : d / max, v: max };
    }

    function colorPartsFromHex(value) {
        let text = String(value || "").trim();
        if (text[0] === "#") text = text.slice(1);
        if (text.length === 3 || text.length === 4) {
            let expanded = "";
            for (let i = 0; i < text.length; i++) expanded += text[i] + text[i];
            text = expanded;
        }
        if (!/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(text)) return null;
        return {
            r: parseInt(text.slice(0, 2), 16),
            g: parseInt(text.slice(2, 4), 16),
            b: parseInt(text.slice(4, 6), 16),
            a: text.length === 8 ? parseInt(text.slice(6, 8), 16) / 255 : 1
        };
    }

    function colorToHex(r, g, b, a) {
        let alpha = root.clampUnit(a);
        let base = "#" + root.hexByte(r) + root.hexByte(g) + root.hexByte(b);
        return alpha >= 0.995 ? base : base + root.hexByte(alpha * 255);
    }

    function applyPickerColor() {
        let rgb = root.hsvToRgb(root.pickerHue, root.pickerSat, root.pickerValue);
        root.drawColor = root.colorToHex(rgb.r, rgb.g, rgb.b, root.pickerAlpha);
        root.smartColor = false;
    }

    function syncPickerFromColor(color) {
        let parts = root.colorPartsFromHex(color);
        if (!parts) return;
        let hsv = root.rgbToHsv(parts.r, parts.g, parts.b);
        root.pickerHue = hsv.h;
        root.pickerSat = hsv.s;
        root.pickerValue = hsv.v;
        root.pickerAlpha = parts.a;
    }

    function rgbaTextForColor(color) {
        let parts = root.colorPartsFromHex(color);
        if (!parts) return "rgba(0, 0, 0, 1)";
        return "rgba(" + parts.r + ", " + parts.g + ", " + parts.b + ", " + Number(parts.a.toFixed(2)) + ")";
    }

    function hslTextForColor(color) {
        let parts = root.colorPartsFromHex(color);
        if (!parts) return "hsl(0, 0%, 0%)";
        let hsl = root.rgbToHsl(parts.r, parts.g, parts.b);
        return "hsl(" + Math.round(hsl.h) + ", " + Math.round(hsl.s * 100) + "%, " + Math.round(hsl.l * 100) + "%)";
    }

    function setColorFromText(value) {
        let text = String(value || "").trim();
        let parts = root.colorPartsFromHex(text);
        if (!parts) {
            let rgba = text.match(/^rgba?\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)(?:\s*,\s*([0-9.]+))?\s*\)$/i);
            if (rgba) {
                parts = {
                    r: root.clampByte(rgba[1]),
                    g: root.clampByte(rgba[2]),
                    b: root.clampByte(rgba[3]),
                    a: rgba[4] === undefined ? 1 : root.clampUnit(rgba[4])
                };
            }
        }
        if (!parts) {
            let hsl = text.match(/^hsla?\(\s*([0-9.]+)\s*,\s*([0-9.]+)%\s*,\s*([0-9.]+)%(?:\s*,\s*([0-9.]+))?\s*\)$/i);
            if (hsl) {
                let rgb = root.hslToRgb(Number(hsl[1]), Number(hsl[2]) / 100, Number(hsl[3]) / 100);
                parts = {
                    r: rgb.r,
                    g: rgb.g,
                    b: rgb.b,
                    a: hsl[4] === undefined ? 1 : root.clampUnit(hsl[4])
                };
            }
        }
        if (!parts) return false;
        root.drawColor = root.colorToHex(parts.r, parts.g, parts.b, parts.a);
        root.syncPickerFromColor(root.drawColor);
        root.smartColor = false;
        return true;
    }

    function addAnnotation(shape) {
        let next = root.annotations.slice();
        next.push(shape);
        root.annotations = next;
        annotationCanvas.requestPaint();
    }

    function undoAnnotation() {
        if (root.annotations.length === 0) return;
        let next = root.annotations.slice(0, root.annotations.length - 1);
        root.annotations = next;
        annotationCanvas.requestPaint();
    }

    function clearAnnotations() {
        root.annotations = [];
        root.currentShape = null;
        annotationCanvas.requestPaint();
    }

    function annotationFilePath() {
        if (root.annotations.length === 0) return "";
        let path = paths.getRunDir("screenshot") + "/annotations-" + Date.now() + ".json";
        let json = JSON.stringify(root.annotations);
        Quickshell.execDetached(["bash", "-c", "printf %s " + root.shellQuote(json) + " > " + root.shellQuote(path)]);
        return path;
    }

    function requestSmartColor(x, y) {
        if (!root.smartColor || root.freezePath === "") return;
        root.smartSampleX = root.globalX(x);
        root.smartSampleY = root.globalY(y);
        smartColorTimer.restart();
    }

    Timer {
        id: smartColorTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (smartColorProcess.running || root.freezePath === "") return;
            smartColorProcess.command = [
                "python3",
                Quickshell.env("HOME") + "/.config/niri/scripts/screenshot_annotate.py",
                "sample",
                "--image", root.freezePath,
                "--x", String(root.smartSampleX),
                "--y", String(root.smartSampleY)
            ];
            smartColorProcess.running = true;
        }
    }

    Process {
        id: smartColorProcess
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                let color = this.text.trim();
                if (/^#[0-9a-fA-F]{6}$/.test(color)) root.drawColor = color;
            }
        }
    }

    onDrawColorChanged: root.syncPickerFromColor(root.drawColor)

    function saveCache() {
        if (root.hasSelection && !root.isVideoMode) {
            let data = Math.round(root.selX) + "," + Math.round(root.selY) + "," + Math.round(root.selW) + "," + Math.round(root.selH);
            Quickshell.execDetached(["bash", "-c", "echo '" + data + "' > " + paths.getCacheDir("screenshot") + "/geometry"]);
        }
    }

    ParallelAnimation {
        id: maximizeAnim
        property real targetStartX; property real targetStartY
        property real targetEndX; property real targetEndY

        NumberAnimation { target: root; property: "startX"; to: maximizeAnim.targetStartX; duration: 250; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "startY"; to: maximizeAnim.targetStartY; duration: 250; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "endX"; to: maximizeAnim.targetEndX; duration: 250; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "endY"; to: maximizeAnim.targetEndY; duration: 250; easing.type: Easing.InOutQuad }
        onFinished: root.saveCache()
    }

    function toggleMaximize() {
        if (!isMaximized) {
            preStartX = root.startX; preStartY = root.startY;
            preEndX = root.endX; preEndY = root.endY;
            maximizeAnim.targetStartX = 0; maximizeAnim.targetStartY = 0;
            maximizeAnim.targetEndX = root.width; maximizeAnim.targetEndY = root.height;
            isMaximized = true;
        } else {
            maximizeAnim.targetStartX = preStartX; maximizeAnim.targetStartY = preStartY;
            maximizeAnim.targetEndX = preEndX; maximizeAnim.targetEndY = preEndY;
            isMaximized = false;
        }
        maximizeAnim.restart();
    }

    // --- Keyboard Shortcuts ---
    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
    Shortcut { sequence: "Return"; onActivated: { if (root.hasSelection) root.executeCapture(root.isEditMode && !root.isVideoMode, root.isVideoMode) } }
    Shortcut { sequence: "Tab"; onActivated: root.isVideoMode = !root.isVideoMode }
    Shortcut { sequence: "Left"; onActivated: root.isVideoMode = false }
    Shortcut { sequence: "Right"; onActivated: root.isVideoMode = true }
    Shortcut { sequence: "F11"; onActivated: root.toggleMaximize() }
    Shortcut { sequence: "D"; onActivated: root.drawMode = !root.drawMode }
    Shortcut { sequence: "Ctrl+Z"; onActivated: root.undoAnnotation() }

    // --- Animated Revealer for Fluid Transitions ---
    component AnimWrap: Item {
        property bool isShown: false
        property real contentWidth: 0
        property real rightPadding: s(3) // Reducción de padding lateral para los íconos
        property real targetWidth: contentWidth + rightPadding
        
        width: isShown ? targetWidth : 0
        height: parent.height
        opacity: isShown ? 1.0 : 0.0
        clip: true
        
        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuart } }
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutQuart } }
        
        default property alias content: internalWrapper.children
        Item { 
            id: internalWrapper
            width: contentWidth 
            height: parent.height 
        }
    }

    // --- Global Reusable Toolbar Button (Matte Edition) ---
    component ToolbarBtn: Rectangle {
        id: tBtn
        property string iconTxt: ""
        property string label: ""
        property bool isDanger: false
        signal clicked()

        height: s(36)
        width: label !== "" ? (txt.implicitWidth + s(36)) : s(36)
        radius: s(18)
        
        // Idle is a solid base color, full matte filled-look
        color: tBtn.isDanger ? _theme.red : (maBtn.containsMouse ? _theme.surface1 : _theme.surface0)
        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.centerIn: parent; spacing: s(6)
            Text { 
                font.family: "Iosevka Nerd Font"
                text: tBtn.iconTxt
                color: tBtn.isDanger ? _theme.crust : _theme.text
                font.pixelSize: s(18) 
            }
            Text { 
                id: txt
                visible: tBtn.label !== ""
                font.family: "JetBrains Mono"
                font.weight: Font.DemiBold
                text: tBtn.label
                color: tBtn.isDanger ? _theme.crust : _theme.text
                font.pixelSize: s(13) 
            }
        }
        MouseArea { 
            id: maBtn
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tBtn.clicked() 
        }
    }

    Image {
        visible: root.freezePath !== ""
        source: root.freezePath !== "" ? "file://" + root.freezePath : ""
        x: -root.screen.x
        y: -root.screen.y
        fillMode: Image.Pad
        cache: false
        z: 0
    }

    Item {
        anchors.fill: parent
        z: 1
        Rectangle {
            anchors.fill: parent
            color: root.dimColor
            opacity: (!root.isSelecting && !root.hasSelection) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Text {
                anchors.centerIn: parent
                text: root.isVideoMode ? "Select region to record" : "Select region to capture"
                font.family: "JetBrains Mono"; font.weight: Font.DemiBold; font.pixelSize: s(24); color: _theme.text
            }
        }
        Item {
            anchors.fill: parent
            opacity: (root.isSelecting || root.hasSelection) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Rectangle { x: 0; y: 0; width: parent.width; height: root.selY; color: root.dimColor } 
            Rectangle { x: 0; y: root.selY + root.selH; width: parent.width; height: parent.height - (root.selY + root.selH); color: root.dimColor }
            Rectangle { x: 0; y: root.selY; width: root.selX; height: root.selH; color: root.dimColor } 
            Rectangle { x: root.selX + root.selW; y: root.selY; width: parent.width - (root.selX + root.selW); height: root.selH; color: root.dimColor } 
        }
    }

    Rectangle {
        visible: root.isSelecting || root.hasSelection
        x: root.selX; y: root.selY; width: root.selW; height: root.selH
        color: (root.showQrPopup && root.isQrSuccess) ? Qt.alpha(_theme.green, 0.15) : (root.isVideoMode ? Qt.alpha(_theme.red, 0.05) : root.selectionTint)
        border.color: (root.showQrPopup && root.isQrSuccess) ? _theme.green : (root.isVideoMode ? _theme.red : root.accentColor)
        border.width: s(4)
        z: 5
    }

    Canvas {
        id: annotationCanvas
        anchors.fill: parent
        z: 12
        visible: root.annotations.length > 0 || root.currentShape !== null

        function paintShape(ctx, shape) {
            if (!shape) return;
            ctx.save();
            ctx.fillStyle = shape.color || "#000000";
            ctx.strokeStyle = shape.color || "#000000";
            ctx.lineWidth = shape.size || root.brushSize;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            if (shape.tool === "rect" || shape.tool === "pixelate") {
                ctx.globalAlpha = shape.tool === "pixelate" ? 0.45 : 1.0;
                ctx.fillRect(shape.x - root.screen.x, shape.y - root.screen.y, shape.w, shape.h);
                if (shape.tool === "pixelate") {
                    ctx.globalAlpha = 0.9;
                    ctx.strokeRect(shape.x - root.screen.x, shape.y - root.screen.y, shape.w, shape.h);
                }
            } else if (shape.tool === "ellipse") {
                let x = shape.x - root.screen.x;
                let y = shape.y - root.screen.y;
                ctx.beginPath();
                ctx.ellipse(x + shape.w / 2, y + shape.h / 2, Math.abs(shape.w / 2), Math.abs(shape.h / 2), 0, 0, Math.PI * 2);
                ctx.fill();
            } else if (shape.tool === "brush") {
                let pts = shape.points || [];
                if (pts.length === 1) {
                    let p = pts[0];
                    let r = (shape.size || root.brushSize) / 2;
                    ctx.beginPath();
                    ctx.arc(p.x - root.screen.x, p.y - root.screen.y, r, 0, Math.PI * 2);
                    ctx.fill();
                } else if (pts.length > 1) {
                    ctx.beginPath();
                    ctx.moveTo(pts[0].x - root.screen.x, pts[0].y - root.screen.y);
                    for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i].x - root.screen.x, pts[i].y - root.screen.y);
                    ctx.stroke();
                }
            }
            ctx.restore();
        }

        onPaint: {
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            for (let i = 0; i < root.annotations.length; i++) paintShape(ctx, root.annotations[i]);
            paintShape(ctx, root.currentShape);
        }
    }

    Repeater {
        model: qrModel
        delegate: Rectangle {
            visible: opacity > 0
            opacity: (root.showQrPopup && model.qSuccess && model.qW > 0) ? 1.0 : 0.0
            property real pad: (root.showQrPopup && model.qSuccess) ? s(5) : 0
            x: model.qW > 0 ? (model.qX - pad) : model.qX
            y: model.qH > 0 ? (model.qY - pad) : model.qY
            width: model.qW > 0 ? (model.qW + (pad * 2)) : 0
            height: model.qH > 0 ? (model.qH + (pad * 2)) : 0
            color: Qt.alpha(_theme.green, 0.25)
            border.color: _theme.green
            border.width: s(3)
            radius: s(8)
            z: 34
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
            Behavior on pad { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
        }
    }

    component Handle: Rectangle {
        width: s(20); height: s(20); radius: s(10)
        color: root.handleColor; border.color: root.accentColor; border.width: s(4)
        visible: (root.hasSelection || root.isSelecting) && !root.isScanningQr && !root.showQrPopup; z: 10
    }
    Handle { x: root.selX - width / 2; y: root.selY - height / 2 } 
    Handle { x: root.selX + root.selW - width / 2; y: root.selY - height / 2 } 
    Handle { x: root.selX - width / 2; y: root.selY + root.selH - height / 2 } 
    Handle { x: root.selX + root.selW - width / 2; y: root.selY + root.selH - height / 2 } 

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 20 
        enabled: !root.drawMode

        function getInteractionMode(mx, my, mods) {
            if (!root.hasSelection) return 1; 
            if (mods & Qt.ShiftModifier) return 2; 
            let margin = s(20) 
            let onLeftLine = Math.abs(mx - root.selX) <= margin; 
            let onRightLine = Math.abs(mx - (root.selX + root.selW)) <= margin
            let onTopLine = Math.abs(my - root.selY) <= margin; 
            let onBottomLine = Math.abs(my - (root.selY + root.selH)) <= margin
            let withinX = mx >= (root.selX - margin) && mx <= (root.selX + root.selW + margin);
            let withinY = my >= (root.selY - margin) && my <= (root.selY + root.selH + margin);

            if (onTopLine && onLeftLine) return 3; 
            if (onTopLine && onRightLine) return 5;
            if (onBottomLine && onLeftLine) return 8; 
            if (onBottomLine && onRightLine) return 10;
            if (onTopLine && withinX) return 4; 
            if (onBottomLine && withinX) return 9;
            if (onLeftLine && withinY) return 6; 
            if (onRightLine && withinY) return 7;
            return 1;
        }

        onPositionChanged: (mouse) => {
            let mode = root.isSelecting ? root.interactionMode : getInteractionMode(mouse.x, mouse.y, mouse.modifiers)
            switch(mode) {
                case 2: cursorShape = Qt.ClosedHandCursor; break;
                case 3: case 10: cursorShape = Qt.SizeFDiagCursor; break;
                case 5: case 8: cursorShape = Qt.SizeBDiagCursor; break;
                case 4: case 9: cursorShape = Qt.SizeVerCursor; break;
                case 6: case 7: cursorShape = Qt.SizeHorCursor; break;
                default: cursorShape = Qt.CrossCursor; break;
            }

            if (!root.isSelecting) return;
            let dx = mouse.x - root.anchorX; let dy = mouse.y - root.anchorY
            let clamp = (val, min, max) => Math.max(min, Math.min(max, val))

            if (root.interactionMode === 1) { 
                root.endX = clamp(mouse.x, 0, root.width); root.endY = clamp(mouse.y, 0, root.height)
            } else if (root.interactionMode === 2) { 
                let targetX = clamp(root.initX + dx, 0, root.width - root.initW); let targetY = clamp(root.initY + dy, 0, root.height - root.initH)
                root.startX = targetX; root.startY = targetY; root.endX = targetX + root.initW; root.endY = targetY + root.initH;
            } else { 
                let nx = root.initX, ny = root.initY, nw = root.initW, nh = root.initH
                if ([3, 6, 8].includes(root.interactionMode)) { nx = clamp(root.initX + dx, 0, root.initX + root.initW - 10); nw = root.initW + (root.initX - nx) }
                if ([5, 7, 10].includes(root.interactionMode)) { nw = clamp(root.initW + dx, 10, root.width - root.initX) }
                if ([3, 4, 5].includes(root.interactionMode)) { ny = clamp(root.initY + dy, 0, root.initY + root.initH - 10); nh = root.initH + (root.initY - ny) }
                if ([8, 9, 10].includes(root.interactionMode)) { nh = clamp(root.initH + dy, 10, root.height - root.initY) }
                root.startX = nx; root.startY = ny; root.endX = nx + nw; root.endY = ny + nh;
            }
        }

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) { Qt.quit(); return; }

            root.isScanningQr = false;
            root.showQrPopup = false;
            qrWaitTimer.stop();

            maximizeAnim.stop() 
            root.interactionMode = getInteractionMode(mouse.x, mouse.y, mouse.modifiers)
            root.isSelecting = true
            if (root.interactionMode !== 1) root.isMaximized = false;
            root.anchorX = mouse.x; root.anchorY = mouse.y
            root.initX = root.selX; root.initY = root.selY; root.initW = root.selW; root.initH = root.selH;

            if (root.interactionMode === 1) {
                let clamp = (val, min, max) => Math.max(min, Math.min(max, val))
                let clampedX = clamp(mouse.x, 0, root.width); let clampedY = clamp(mouse.y, 0, root.height)
                root.startX = clampedX; root.startY = clampedY; root.endX = clampedX; root.endY = clampedY;
                root.hasSelection = false; root.isMaximized = false
            }
        }

        onReleased: {
            if (root.isSelecting) {
                root.isSelecting = false
                if (root.selW > 10 && root.selH > 10) {
                    root.hasSelection = true; root.saveCache()
                } else { root.hasSelection = false }
            }
        }
    }

    MouseArea {
        id: drawArea
        visible: root.drawMode && root.freezePath !== "" && root.hasSelection && !root.isVideoMode && !root.isScanningQr && !root.showQrPopup
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor
        z: 25

        function insideSelection(x, y) {
            return x >= root.selX && x <= root.selX + root.selW && y >= root.selY && y <= root.selY + root.selH;
        }

        function clampX(x) { return Math.max(root.selX, Math.min(root.selX + root.selW, x)); }
        function clampY(y) { return Math.max(root.selY, Math.min(root.selY + root.selH, y)); }

        function makeShape(x, y) {
            let gx = root.globalX(Math.min(root.drawAnchorX, x));
            let gy = root.globalY(Math.min(root.drawAnchorY, y));
            let gw = Math.abs(x - root.drawAnchorX);
            let gh = Math.abs(y - root.drawAnchorY);
            return { tool: root.drawTool, color: root.drawColor, x: gx, y: gy, w: Math.round(gw), h: Math.round(gh), size: root.brushSize };
        }

        onPositionChanged: (mouse) => {
            root.requestSmartColor(mouse.x, mouse.y);
            if (!pressed || root.currentShape === null) return;
            let x = clampX(mouse.x);
            let y = clampY(mouse.y);
            if (root.drawTool === "brush") {
                let pts = root.currentShape.points.slice();
                pts.push({ x: root.globalX(x), y: root.globalY(y) });
                root.currentShape = { tool: "brush", color: root.drawColor, points: pts, size: root.brushSize };
            } else {
                root.currentShape = makeShape(x, y);
            }
            annotationCanvas.requestPaint();
        }

        onPressed: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.drawMode = false;
                return;
            }
            if (!insideSelection(mouse.x, mouse.y)) return;
            root.requestSmartColor(mouse.x, mouse.y);
            root.drawAnchorX = clampX(mouse.x);
            root.drawAnchorY = clampY(mouse.y);
            if (root.drawTool === "brush") {
                root.currentShape = {
                    tool: "brush",
                    color: root.drawColor,
                    points: [{ x: root.globalX(root.drawAnchorX), y: root.globalY(root.drawAnchorY) }],
                    size: root.brushSize
                };
            } else {
                root.currentShape = makeShape(root.drawAnchorX, root.drawAnchorY);
            }
            annotationCanvas.requestPaint();
        }

        onReleased: {
            if (root.currentShape === null) return;
            let shape = root.currentShape;
            root.currentShape = null;
            if (shape.tool === "brush" || Math.abs(shape.w) > 2 || Math.abs(shape.h) > 2) {
                root.addAnnotation(shape);
            } else {
                annotationCanvas.requestPaint();
            }
        }
    }

    // --- Main Bottom Toolbar (Smooth Matte Rounded Rect) ---
    Item {
        id: toolbar
        z: 30 
        
        // Fully expanded total height
        property real totalHeight: s(120)
        property bool fitsOutsideBottom: (root.selY + root.selH + totalHeight + s(15)) <= root.height

        visible: root.hasSelection && !root.isSelecting && !root.isScanningQr && !root.showQrPopup
        
        width: Math.max(toolbarRow.width + s(64), s(340))
        height: totalHeight 

        x: Math.max(s(10), Math.min(parent.width - width - s(10), root.selX + (root.selW / 2) - (width / 2)))
        y: fitsOutsideBottom ? (root.selY + root.selH + s(15)) : 
           ((root.selY - height - s(15)) >= 0 ? (root.selY - height - s(15)) : (root.height - height - s(15)))

        // The Smooth Translucent Matte Background
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 0.85)
            border.color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.08)
            border.width: s(1)
            radius: s(24)
        }

        component AudioControl: RowLayout {
            property string iconOn: ""
            property string iconOff: ""
            property real volumeValue: 1.0
            property bool mutedValue: false
            property bool hasDropdown: false
            
            signal volumeUpdate(real newVol)
            signal muteUpdate(bool newMute)
            signal dropdownClicked()

            spacing: s(4)

            Rectangle {
                width: s(30); height: s(30); radius: s(15)
                // Filled, solid matte-look on idle
                color: maIcon.containsMouse ? _theme.surface2 : _theme.surface0
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    font.family: "Iosevka Nerd Font"
                    text: parent.parent.mutedValue ? parent.parent.iconOff : parent.parent.iconOn
                    color: parent.parent.mutedValue ? _theme.red : _theme.text
                    font.pixelSize: s(16)
                }
                MouseArea {
                    id: maIcon; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: parent.parent.muteUpdate(!parent.parent.mutedValue)
                }
            }

            Slider {
                Layout.preferredWidth: s(60)
                from: 0.0; to: 1.0; value: parent.volumeValue
                onValueChanged: parent.volumeUpdate(value)

                background: Rectangle {
                    x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                    implicitWidth: s(60); implicitHeight: s(4)
                    width: parent.availableWidth; height: implicitHeight
                    radius: s(2)
                    color: _theme.surface2
                    Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; color: parent.parent.parent.mutedValue ? _theme.subtext0 : _theme.mauve; radius: s(2) }
                }
                handle: Rectangle {
                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                    implicitWidth: s(12); implicitHeight: s(12); radius: s(6)
                    color: parent.parent.parent.mutedValue ? _theme.subtext0 : _theme.mauve
                }
            }

            Rectangle {
                visible: parent.hasDropdown
                width: s(20); height: s(30); color: "transparent"
                Text {
                    anchors.centerIn: parent
                    font.family: "Iosevka Nerd Font"
                    // Correcting dropdown icon orientation base on position relative to fitsOutsideBottom
                    text: toolbar.fitsOutsideBottom ? "󰅃" : "󰅀" 
                    color: _theme.text
                    font.pixelSize: s(16)
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.parent.dropdownClicked() }
            }
        }

        component DrawToolButton: Rectangle {
            id: drawToolBtn
            property string iconTxt: ""
            property bool active: false
            signal clicked()

            width: s(30)
            height: s(30)
            radius: s(15)
            color: active ? root.drawColor : (drawToolMa.containsMouse ? _theme.surface2 : _theme.surface0)
            border.color: active ? _theme.text : "transparent"
            border.width: active ? s(2) : 0
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                font.family: "Iosevka Nerd Font"
                text: drawToolBtn.iconTxt
                color: drawToolBtn.active ? _theme.crust : _theme.text
                font.pixelSize: s(16)
            }

            MouseArea {
                id: drawToolMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: drawToolBtn.clicked()
            }
        }

        component ColorSwatch: Rectangle {
            id: colorSwatch
            property string value: "#000000"

            width: s(22)
            height: s(22)
            radius: s(11)
            color: value
            border.color: root.drawColor.toLowerCase() === value.toLowerCase() ? _theme.text : _theme.surface2
            border.width: root.drawColor.toLowerCase() === value.toLowerCase() ? s(3) : s(1)

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.drawColor = colorSwatch.value;
                    root.smartColor = false;
                    root.showColorPicker = false;
                }
            }
        }

        component ColorInput: TextField {
            id: colorInput
            property string labelTxt: ""

            width: parent ? parent.width : s(180)
            height: s(32)
            color: _theme.text
            selectedTextColor: _theme.crust
            selectionColor: _theme.mauve
            font.family: "JetBrains Mono"
            font.pixelSize: s(11)
            leftPadding: s(48)
            rightPadding: s(8)
            verticalAlignment: TextInput.AlignVCenter
            background: Rectangle {
                color: _theme.surface0
                radius: s(8)
                border.color: activeFocus ? _theme.mauve : _theme.surface2
                border.width: s(1)
            }
            Text {
                x: s(10)
                anchors.verticalCenter: parent.verticalCenter
                text: colorInput.labelTxt
                color: _theme.subtext0
                font.pixelSize: s(10)
                font.family: "JetBrains Mono"
            }
            onAccepted: root.setColorFromText(text)
            onEditingFinished: root.setColorFromText(text)
        }

        Rectangle {
            id: micDropdown
            visible: false
            width: s(280)
            height: micModel.count === 0 ? s(40) : Math.min(s(180), micModel.count * s(36))
            x: -s(140) 
            // Correcting dropdown positioning
            y: toolbar.fitsOutsideBottom ? (toolbar.height + s(8)) : (-height - s(8))
            color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 0.95)
            border.color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.08)
            border.width: s(1)
            radius: s(12)
            z: 50

            Text {
                visible: micModel.count === 0
                anchors.centerIn: parent
                text: "No Microphones (Install pulseaudio)"
                color: _theme.subtext0
                font.pixelSize: s(12)
            }

            ListView {
                visible: micModel.count > 0
                anchors.fill: parent; anchors.margins: s(4)
                model: micModel
                clip: true
                delegate: Rectangle {
                    width: ListView.view.width; height: s(32); radius: s(6)
                    color: maList.containsMouse ? _theme.surface0 : "transparent"
                    RowLayout {
                        anchors.fill: parent; anchors.margins: s(6)
                        Text { text: model.devDesc; color: root.micDevice === model.devName ? _theme.mauve : _theme.text; font.pixelSize: s(12); elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    MouseArea { 
                        id: maList; anchors.fill: parent; hoverEnabled: true; 
                        onClicked: { root.micDevice = model.devName; root.saveAudioPrefs(); micDropdown.visible = false } 
                    }
                }
            }
        }

        Rectangle {
            id: colorPickerPanel
            visible: root.showColorPicker && root.drawMode && !root.isVideoMode
            width: s(372)
            height: s(292)
            property real preferredX: toolbarRow.x + s(230)
            property real preferredY: toolbar.fitsOutsideBottom ? (-height - s(8)) : (toolbar.height + s(8))
            x: Math.max(-toolbar.x + s(8), Math.min(root.width - toolbar.x - width - s(8), preferredX))
            y: Math.max(-toolbar.y + s(8), Math.min(root.height - toolbar.y - height - s(8), preferredY))
            color: Qt.rgba(_theme.base.r, _theme.base.g, _theme.base.b, 0.96)
            border.color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.10)
            border.width: s(1)
            radius: s(16)
            z: 80

            MouseArea { anchors.fill: parent }

            Row {
                anchors.fill: parent
                anchors.margins: s(14)
                spacing: s(14)

                Row {
                    width: s(186)
                    height: s(196)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: s(10)

                    Item {
                        width: s(156)
                        height: s(156)
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: svBase
                            anchors.fill: parent
                            color: {
                                let rgb = root.hsvToRgb(root.pickerHue, 1, 1);
                                return Qt.rgba(rgb.r / 255, rgb.g / 255, rgb.b / 255, 1);
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: "#ffffff" }
                                GradientStop { position: 1; color: "transparent" }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: "#000000" }
                            }
                        }

                        Rectangle {
                            width: s(14)
                            height: s(14)
                            radius: s(7)
                            x: root.pickerSat * parent.width - width / 2
                            y: (1 - root.pickerValue) * parent.height - height / 2
                            color: "transparent"
                            border.color: _theme.text
                            border.width: s(2)
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            function pick(mx, my) {
                                root.pickerSat = root.clampUnit(mx / width);
                                root.pickerValue = root.clampUnit(1 - my / height);
                                root.applyPickerColor();
                            }
                            onPressed: (mouse) => pick(mouse.x, mouse.y)
                            onPositionChanged: (mouse) => { if (pressed) pick(mouse.x, mouse.y) }
                        }
                    }

                    Item {
                        width: s(20)
                        height: s(156)
                        anchors.verticalCenter: parent.verticalCenter

                        Canvas {
                            id: hueStrip
                            anchors.fill: parent
                            onPaint: {
                                let ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                for (let y = 0; y < height; y++) {
                                    let rgb = root.hsvToRgb((y / Math.max(1, height - 1)) * 360, 1, 1);
                                    ctx.fillStyle = "rgb(" + rgb.r + "," + rgb.g + "," + rgb.b + ")";
                                    ctx.fillRect(0, y, width, 1);
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width + s(8)
                            height: s(8)
                            radius: s(4)
                            x: -s(4)
                            y: (root.pickerHue / 360) * parent.height - height / 2
                            color: "transparent"
                            border.color: _theme.text
                            border.width: s(2)
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            function pick(my) {
                                root.pickerHue = root.clampUnit(my / height) * 360;
                                root.applyPickerColor();
                            }
                            onPressed: (mouse) => pick(mouse.y)
                            onPositionChanged: (mouse) => { if (pressed) pick(mouse.y) }
                        }
                    }
                }

                Column {
                    width: s(144)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: s(10)

                    Text {
                        text: "Color"
                        color: _theme.text
                        font.family: "JetBrains Mono"
                        font.weight: Font.DemiBold
                        font.pixelSize: s(12)
                    }

                    Column {
                        width: parent.width
                        spacing: s(4)
                        Text { text: "Alpha"; color: _theme.subtext0; font.pixelSize: s(10); font.family: "JetBrains Mono" }
                        Slider {
                            width: parent.width
                            height: s(24)
                            from: 0
                            to: 1
                            value: root.pickerAlpha
                            onMoved: {
                                root.pickerAlpha = value;
                                root.applyPickerColor();
                            }
                        }
                    }

                    ColorInput {
                        labelTxt: "HEX"
                        text: root.drawColor
                    }
                    ColorInput {
                        labelTxt: "RGBA"
                        text: root.rgbaTextForColor(root.drawColor)
                    }
                    ColorInput {
                        labelTxt: "HSL"
                        text: root.hslTextForColor(root.drawColor)
                    }
                }
            }
        }

        Rectangle {
            id: brushSizePanel
            visible: root.drawMode && root.drawTool === "brush" && !root.isVideoMode
            width: s(128)
            height: s(36)
            property real brushCenterX: toolbarRow.x + brushToolsWrap.x + brushToolsRow.x + brushToolButton.x + brushToolButton.width / 2
            x: brushCenterX - width / 2
            y: toolbarRow.y + toolbarRow.height + s(10)
            color: Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.90)
            border.color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.08)
            border.width: s(1)
            radius: s(12)
            z: 70

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: s(12)
                anchors.rightMargin: s(12)
                spacing: s(8)

                Rectangle {
                    Layout.preferredWidth: Math.max(s(7), Math.min(s(20), s(root.brushSize)))
                    Layout.preferredHeight: Layout.preferredWidth
                    radius: width / 2
                    color: root.drawColor
                    border.color: _theme.text
                    border.width: s(1)
                }

                Item {
                    id: brushSizeSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: s(22)
                    property int minValue: 4
                    property int maxValue: 72
                    property real ratio: (root.brushSize - minValue) / (maxValue - minValue)
                    function setFromX(localX) {
                        let next = minValue + root.clampUnit(localX / width) * (maxValue - minValue);
                        root.brushSize = Math.round(next);
                    }

                    Rectangle {
                        width: parent.width
                        height: s(4)
                        anchors.verticalCenter: parent.verticalCenter
                        radius: s(2)
                        color: _theme.surface2
                        Rectangle {
                            width: brushSizeSlider.ratio * parent.width
                            height: parent.height
                            radius: parent.radius
                            color: _theme.mauve
                        }
                    }

                    Rectangle {
                        width: s(14)
                        height: s(14)
                        radius: s(7)
                        x: brushSizeSlider.ratio * (brushSizeSlider.width - width)
                        anchors.verticalCenter: parent.verticalCenter
                        color: _theme.mauve
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => brushSizeSlider.setFromX(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) brushSizeSlider.setFromX(mouse.x) }
                    }
                }

                Text {
                    Layout.preferredWidth: s(30)
                    text: root.brushSize + "px"
                    color: _theme.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: s(10)
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        // Top Content: The Action Tools
        Row {
            id: toolbarRow
            anchors.top: parent.top
            anchors.topMargin: s(12)
            anchors.horizontalCenter: parent.horizontalCenter
            height: root.s(36)
            spacing: 0

            // Tab Switcher with Morphing Animation (Stretchy Mauve Pill)
            Item {
                // Width is slightly bigger to handle reducced icon padding on right
                width: s(110) + s(3); height: parent.height
                
                Rectangle {
                    width: s(110); height: s(36); radius: s(18) 
                    color: _theme.surface0
                    
                    Rectangle {
                        id: activeHighlight
                        y: s(2)
                        height: parent.height - s(4)
                        radius: s(16) 
                        color: _theme.mauve
                        z: 0

                        property bool curVideoMode: root.isVideoMode
                        onCurVideoModeChanged: {
                            // Morph duration/easing when going right vs left
                            if (curVideoMode) { // Moving right
                                rightAnim.duration = 200; leftAnim.duration = 350;
                            } else { // Moving left
                                leftAnim.duration = 200; rightAnim.duration = 350;
                            }
                        }

                        property real targetLeft: curVideoMode ? (parent.width / 2) : s(2)
                        property real targetRight: targetLeft + (parent.width / 2) - s(2)

                        property real actualLeft: targetLeft
                        property real actualRight: targetRight

                        Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

                        x: actualLeft
                        width: actualRight - actualLeft
                    }
                    
                    Row {
                        anchors.fill: parent
                        z: 1
                        Item {
                            width: parent.width / 2; height: parent.height
                            Text { anchors.centerIn: parent; font.family: "Iosevka Nerd Font"; text: "󰄄"; color: !root.isVideoMode ? _theme.crust : _theme.text; font.pixelSize: s(16) }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isVideoMode = false }
                        }
                        Item {
                            width: parent.width / 2; height: parent.height
                            Text { anchors.centerIn: parent; font.family: "Iosevka Nerd Font"; text: ""; color: root.isVideoMode ? _theme.crust : _theme.text; font.pixelSize: s(16) }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.isVideoMode = true }
                        }
                    }
                }
            }

            // Video Controls
            AnimWrap {
                isShown: root.isVideoMode; contentWidth: s(2)
                Rectangle { width: s(2); height: s(16); anchors.verticalCenter: parent.verticalCenter; color: _theme.surface0; radius: s(1) }
            }

            AnimWrap {
                isShown: root.isVideoMode; contentWidth: s(94)
                AudioControl { 
                    id: deskAudio; width: parent.width; height: parent.height
                    iconOn: "󰓃"; iconOff: "󰓄" 
                    volumeValue: root.deskVol; mutedValue: root.deskMute
                    onVolumeUpdate: (v) => { root.deskVol = v; root.saveAudioPrefs() }
                    onMuteUpdate: (m) => { root.deskMute = m; root.saveAudioPrefs() }
                }
            }
            
            AnimWrap {
                isShown: root.isVideoMode; contentWidth: s(118)
                AudioControl { 
                    id: micAudio; width: parent.width; height: parent.height
                    iconOn: "󰍬"; iconOff: "󰍭"; hasDropdown: true
                    volumeValue: root.micVol; mutedValue: root.micMute
                    onVolumeUpdate: (v) => { root.micVol = v; root.saveAudioPrefs() }
                    onMuteUpdate: (m) => { root.micMute = m; root.saveAudioPrefs() }
                    onDropdownClicked: { micDropdown.visible = !micDropdown.visible; micDropdown.x = mapToItem(toolbar, 0, 0).x - s(120) }
                }
            }

            // Image Controls
            AnimWrap {
                isShown: !root.isVideoMode; contentWidth: s(2)
                Rectangle { width: s(2); height: s(16); anchors.verticalCenter: parent.verticalCenter; color: _theme.surface0; radius: s(1) }
            }

            AnimWrap {
                isShown: !root.isVideoMode && root.freezePath !== ""; contentWidth: s(36)
                ToolbarBtn {
                    iconTxt: root.drawMode ? "󰸞" : "󰏪"
                    onClicked: root.drawMode = !root.drawMode
                }
            }

            AnimWrap {
                isShown: !root.isVideoMode && root.drawMode; contentWidth: s(2)
                Rectangle { width: s(2); height: s(16); anchors.verticalCenter: parent.verticalCenter; color: _theme.surface0; radius: s(1) }
            }

            AnimWrap {
                id: brushToolsWrap
                isShown: !root.isVideoMode && root.drawMode; contentWidth: s(132)
                Row {
                    id: brushToolsRow
                    height: parent.height
                    spacing: s(4)
                    anchors.verticalCenter: parent.verticalCenter
                    DrawToolButton { id: brushToolButton; iconTxt: "󰝥"; active: root.drawTool === "brush"; onClicked: root.drawTool = "brush" }
                    DrawToolButton { iconTxt: "󰹞"; active: root.drawTool === "rect"; onClicked: root.drawTool = "rect" }
                    DrawToolButton { iconTxt: "󰺕"; active: root.drawTool === "ellipse"; onClicked: root.drawTool = "ellipse" }
                    DrawToolButton { iconTxt: "󰕕"; active: root.drawTool === "pixelate"; onClicked: root.drawTool = "pixelate" }
                }
            }

            AnimWrap {
                isShown: !root.isVideoMode && root.drawMode; contentWidth: s(168)
                Row {
                    height: parent.height
                    spacing: s(5)
                    anchors.verticalCenter: parent.verticalCenter
                    ColorSwatch { value: "#000000" }
                    ColorSwatch { value: "#ffffff" }
                    ColorSwatch { value: "#ff3b30" }
                    ColorSwatch { value: "#ffd60a" }
                    ColorSwatch { value: "#34c759" }
                    DrawToolButton {
                        iconTxt: "󰏘"
                        active: root.showColorPicker
                        onClicked: {
                            root.showColorPicker = !root.showColorPicker;
                            if (root.showColorPicker) root.syncPickerFromColor(root.drawColor);
                        }
                    }
                }
            }

            AnimWrap {
                isShown: !root.isVideoMode && root.drawMode; contentWidth: s(108)
                Row {
                    height: parent.height
                    spacing: s(4)
                    anchors.verticalCenter: parent.verticalCenter
                    DrawToolButton {
                        iconTxt: "󰈈"
                        active: root.smartColor
                        onClicked: root.smartColor = !root.smartColor
                    }
                    DrawToolButton { iconTxt: "󰕌"; active: false; onClicked: root.undoAnnotation() }
                    DrawToolButton { iconTxt: "󰃢"; active: false; onClicked: root.clearAnnotations() }
                }
            }

            AnimWrap {
                isShown: !root.isVideoMode; contentWidth: s(36)
                ToolbarBtn { iconTxt: "⿻"; onClicked: root.performQrScan() }
            }

            AnimWrap {
                isShown: !root.isVideoMode; contentWidth: s(2)
                Rectangle { width: s(2); height: s(16); anchors.verticalCenter: parent.verticalCenter; color: _theme.surface0; radius: s(1) }
            }
            
            AnimWrap {
                isShown: !root.isVideoMode; contentWidth: s(36)
                ToolbarBtn { iconTxt: root.isMaximized ? "" : ""; onClicked: root.toggleMaximize() }
            }

            // Universal Close Button
            Item {
                width: s(2) + s(3) + s(36); height: parent.height // Widened width for reducced padding on right
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height
                    spacing: s(3) // Reducción de padding lateral para los íconos en top part
                    Rectangle { width: s(2); height: s(16); anchors.verticalCenter: parent.verticalCenter; color: _theme.surface0; radius: s(1);}
                    ToolbarBtn { 
                        anchors.verticalCenter: parent.verticalCenter
                        iconTxt: "󰅖"; isDanger: true; onClicked: Qt.quit() 
                    }
                }
            }
        }

        // Bottom Content: Center Capture Layout with Dynamic Gradient Lines
        Item {
            id: captureSection
            anchors.bottom: parent.bottom
            anchors.bottomMargin: s(12)
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: s(56) // Aumento ligero de altura para el capture circle más grande
            z: 10

            // Smooth Left Line + Hover Wave
            Rectangle {
                id: leftLineBase
                height: s(4) // Líneas horizontales más gruesas
                radius: s(2) // Radio escalado
                color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.1) // Subtle structural line
                anchors.left: parent.left
                anchors.leftMargin: s(24)
                anchors.right: actionBtnContainer.left
                anchors.rightMargin: s(16)
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                // Stretchy gradient 'wave'
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    // Stretches left when hovered
                    width: actionArea.containsMouse ? parent.width : 0
                    radius: s(2)
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.InOutExpo } }
                    
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.isVideoMode ? _theme.red : root.accentColor }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }

            // Central Capture Circle (Slightly Bigger)
            Item {
                id: actionBtnContainer
                width: s(56) // Círculo 'capture' un poco más grande
                height: width
                anchors.centerIn: parent
                z: 20
                
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.color: root.isVideoMode ? Qt.alpha(_theme.red, 0.4) : Qt.alpha(_theme.surface1, 0.8)
                    border.width: s(2)
                    Behavior on border.color { ColorAnimation { duration: 250 } }
                }

                Rectangle {
                    // Círculo interno escalado
                    width: actionArea.pressed ? s(32) : (actionArea.containsMouse ? s(40) : s(36))
                    height: width
                    radius: width / 2
                    anchors.centerIn: parent
                    color: root.isVideoMode ? _theme.red : root.accentColor
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
                }

                MouseArea {
                    id: actionArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.executeCapture(false, root.isVideoMode)
                }
            }

            // Smooth Right Line + Hover Wave
            Rectangle {
                id: rightLineBase
                height: s(4) // Líneas horizontales más gruesas
                radius: s(2) // Radio escalado
                color: Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.1)
                anchors.right: parent.right
                anchors.rightMargin: s(24)
                anchors.left: actionBtnContainer.right
                anchors.leftMargin: s(16)
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                // Stretchy gradient 'wave'
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    // Stretches right when hovered
                    width: actionArea.containsMouse ? parent.width : 0
                    radius: s(2)
                    Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.InOutExpo } }
                    
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: root.isVideoMode ? _theme.red : root.accentColor }
                    }
                }
            }
        }
    }

    // --- QR Popup and Backend Hooks ---
    Repeater {
        model: qrModel
        delegate: Rectangle {
            id: qrPopupItem
            visible: opacity > 0
            opacity: (root.showQrPopup && !root.isSelecting) ? 1.0 : 0.0
            
            x: model.qTargetX
            y: model.qTargetY + (model.fitsTop ? (1.0 - opacity) * s(15) : -(1.0 - opacity) * s(15))
            
            width: qrPopupLayout.implicitWidth + s(32)
            height: s(52)
            radius: s(26)
            color: _theme.base
            border.color: model.qSuccess ? _theme.green : _theme.red
            border.width: s(2)

            property bool isHovered: maHover.containsMouse
            scale: isHovered ? 1.0 : model.qBaseScale
            z: isHovered ? 100 : (40 - index)
            transformOrigin: Item.Center

            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuart } }
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }

            MouseArea { id: maHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

            RowLayout {
                id: qrPopupLayout
                anchors.centerIn: parent
                spacing: s(8)

                Text {
                    text: model.qText
                    color: model.qSuccess ? _theme.text : _theme.red
                    font.family: "JetBrains Mono"
                    font.pixelSize: s(13)
                    font.weight: Font.DemiBold
                    Layout.maximumWidth: s(400)
                    Layout.leftMargin: s(8)
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                }

                Rectangle { visible: model.qSuccess; width: s(2); Layout.fillHeight: true; Layout.topMargin: s(10); Layout.bottomMargin: s(10); color: _theme.surface0; radius: s(1) }

                ToolbarBtn {
                    visible: model.qSuccess
                    iconTxt: "󰆏"
                    onClicked: {
                        Quickshell.execDetached(["bash", "-c", `echo -n '${model.qText.replace(/'/g, "'\\''")}' | wl-copy`]);
                        root.showQrPopup = false;
                    }
                }

                ToolbarBtn {
                    visible: model.qSuccess && (model.qText.startsWith("http://") || model.qText.startsWith("https://"))
                    iconTxt: "󰌹"
                    onClicked: {
                        Quickshell.execDetached(["xdg-open", model.qText]);
                        Qt.quit();
                    }
                }

                Rectangle { width: s(2); Layout.fillHeight: true; Layout.topMargin: s(10); Layout.bottomMargin: s(10); color: _theme.surface0; radius: s(1) }
                ToolbarBtn { iconTxt: "󰅖"; isDanger: true; onClicked: root.showQrPopup = false }
            }
        }
    }

    Process {
        id: qrReaderProcess
        property string accumulated: ""
        command: ["cat", paths.getRunDir("screenshot") + "/qr_result"]
        stdout: SplitParser { splitMarker: ""; onRead: data => qrReaderProcess.accumulated += data }
        
        onExited: (exitCode) => {
            let res = qrReaderProcess.accumulated.trim()
            qrReaderProcess.accumulated = ""
            root.isScanningQr = false
            qrModel.clear()
    
            if (exitCode !== 0 || res === "") {
                qrModel.append({ 
                    qX: root.selX + (root.selW / 2), qY: root.selY + (root.selH / 2), qW: 0, qH: 0, 
                    qText: "Scan timed out or failed.", qSuccess: false,
                    qTargetX: root.selX + (root.selW / 2) - s(100), qTargetY: root.selY + (root.selH / 2),
                    qBaseScale: 1.0, fitsTop: false 
                })
                root.isQrSuccess = false
                root.showQrPopup = true
                return
            }

            let lines = res.split('\n');
            let anySuccess = false;
            let qrs = [];

            for (let i = 0; i < lines.length; i++) {
                let line = lines[i].trim();
                if (line === "") continue;
                let delimiterIdx = line.indexOf('|||');
                if (delimiterIdx === -1) continue;

                let coordStr = line.substring(0, delimiterIdx);
                let actualText = line.substring(delimiterIdx + 3).replace(/\\n/g, '\n').replace(/\\\\/g, '\\');
                let coords = coordStr.split(',');

                if (coords.length === 4 && !isNaN(parseInt(coords[0]))) {
                    let x = parseInt(coords[0]); let y = parseInt(coords[1]); let w = parseInt(coords[2]); let h = parseInt(coords[3]);
                    
                    let successState = !(actualText === "NOT_FOUND" || actualText.startsWith("ERROR:"));
                    if (successState) anySuccess = true;
                    let cleanText = successState ? actualText.replace(/^QR-Code:/, "") : (actualText === "NOT_FOUND" ? "No QR code found." : actualText);
                    
                    let estTextWidth = Math.min(s(400), cleanText.length * s(8.5));
                    let pw = estTextWidth + (successState ? s(140) : s(40)); 
                    let ph = s(52);
                    let absX = root.selX + x; let absY = root.selY + y;
                    let cx = absX + (w / 2);
                    let fitsTop = (absY - ph - s(15)) >= root.selY;
                    let idealX = cx - (pw / 2);
                    let targetX = Math.max(s(10), Math.min(root.width - pw - s(10), idealX));
                    let targetY = fitsTop ? (absY - ph - s(15)) : (absY + h + s(15));

                    qrs.push({ qX: absX, qY: absY, qW: w, qH: h, qText: cleanText, qSuccess: successState, pw: pw, ph: ph, targetX: targetX, targetY: targetY, cx: targetX + (pw / 2), cy: targetY + (ph / 2), scale: 1.0, fitsTop: fitsTop });
                }
            }

            for (let pass = 0; pass < 5; pass++) {
                for (let i = 0; i < qrs.length; i++) {
                    for (let j = i + 1; j < qrs.length; j++) {
                        let A = qrs[i]; let B = qrs[j];
                        let dx = Math.abs(A.cx - B.cx); let dy = Math.abs(A.cy - B.cy);
                        let req_x = (A.pw * A.scale + B.pw * B.scale) / 2 + s(10);
                        let req_y = (A.ph * A.scale + B.ph * B.scale) / 2 + s(10);
                        
                        if (dx < req_x && dy < req_y) {
                            let factorX = dx > 0 ? (dx - s(10)) * 2 / (A.pw + B.pw) : 0;
                            let factorY = dy > 0 ? (dy - s(10)) * 2 / (A.ph + B.ph) : 0;
                            let maxFactor = Math.max(factorX, factorY);
                            maxFactor = Math.max(0.35, maxFactor); 
                            A.scale = Math.min(A.scale, maxFactor); B.scale = Math.min(B.scale, maxFactor);
                        }
                    }
                }
            }

            if (qrs.length === 0) {
                qrModel.append({ 
                    qX: root.selX + (root.selW / 2), qY: root.selY + (root.selH / 2), qW: 0, qH: 0, 
                    qText: "No QR code found.", qSuccess: false,
                    qTargetX: root.selX + (root.selW / 2) - s(100), qTargetY: root.selY + (root.selH / 2),
                    qBaseScale: 1.0, fitsTop: false 
                });
            } else {
                for (let i = 0; i < qrs.length; i++) {
                    qrModel.append({ qX: qrs[i].qX, qY: qrs[i].qY, qW: qrs[i].qW, qH: qrs[i].qH, qText: qrs[i].qText, qSuccess: qrs[i].qSuccess, qTargetX: qrs[i].targetX, qTargetY: qrs[i].targetY, qBaseScale: qrs[i].scale, fitsTop: qrs[i].fitsTop });
                }
            }

            root.isQrSuccess = anySuccess;
            root.showQrPopup = true
            Quickshell.execDetached(["bash", "-c", "rm -f " + paths.getRunDir("screenshot") + "/qr_result"])
        }
    }
    
    Timer {
        id: qrWaitTimer
        interval: 1200  
        repeat: false
        onTriggered: qrReaderProcess.running = true
    }
    
    function performQrScan() {
        Quickshell.execDetached(["bash", "-c", "rm -f " + paths.getRunDir("screenshot") + "/qr_result"])
        root.isScanningQr = true; root.showQrPopup = false; qrModel.clear()
        let cmd = `bash ~/.config/niri/scripts/screenshot.sh --geometry "${root.geometryString}" --scan-qr`
        Quickshell.execDetached(["bash", "-c", cmd])
        qrWaitTimer.start()
    }   
    
    Timer {
        id: captureTimer
        property string pendingCmd: ""
        interval: 200
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["bash", "-c", pendingCmd])
            Qt.quit()
        }
    }
    
    function executeCapture(openEditor, isRecord) {
        let cmd = `bash ~/.config/niri/scripts/screenshot.sh --geometry "${root.geometryString}"`
        if (root.freezePath !== "" && !isRecord) cmd += ` --freeze-path "${root.freezePath}"`
        if (!isRecord && root.annotations.length > 0) {
            let annotationsPath = root.annotationFilePath();
            if (annotationsPath !== "") cmd += ` --annotations "${annotationsPath}"`
        }
        if (root.isClipboardOnly && !isRecord) cmd += " --clipboard-only"
        if (isRecord) {
            cmd += " --record"
            cmd += ` --desk-vol ${root.deskVol} --desk-mute ${root.deskMute}`
            cmd += ` --mic-vol ${root.micVol} --mic-mute ${root.micMute}`
            if (root.micDevice !== "") cmd += ` --mic-dev "${root.micDevice}"`
        }
        if (openEditor) cmd += " --edit"
    
        root.visible = false
        captureTimer.pendingCmd = cmd
        captureTimer.start()
    }
}
