import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// One line of status: what the send is doing.
class BridgeView extends WatchUi.View {
    function initialize() {
        View.initialize();
    }

    function changed() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 - 30, Graphics.FONT_SMALL, "ProjectFit",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h / 2 + 10, Graphics.FONT_TINY, Sender.status,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
