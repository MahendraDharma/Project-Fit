// ProjectFit Bridge — the watch side.
//
// Garmin Connect keeps the watch's own Bluetooth link; this app rides beside
// it through Connect IQ. It reads what the watch already measured (stress,
// Body Battery, SpO2, daily steps) from SensorHistory / ActivityMonitor and
// transmits it to the ProjectFit phone app, which stores it with "Garmin" as
// its source. Nothing on the watch is changed.
//
// Two ways a send starts:
//   * the phone asks ({"cmd": "pull", "since": <epoch s>}) — in the
//     background service when the app is closed, or in the open app;
//   * the person opens the app on the watch — it sends what is newer than
//     the last send it finished.
import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background)
class BridgeApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new BridgeService()];
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        // So a pull from the phone reaches the watch while this app is closed.
        if (Background has :registerForPhoneAppMessageEvent) {
            Background.registerForPhoneAppMessageEvent();
        }
        Communications.registerForPhoneAppMessages(method(:onPhone));
        var view = new BridgeView();
        Sender.onChange = view.method(:changed);
        Sender.start(Sender.lastSent(), false);
        return [view];
    }

    function onPhone(msg as Communications.PhoneAppMessage) as Void {
        Sender.handle(msg.data, false);
    }
}
