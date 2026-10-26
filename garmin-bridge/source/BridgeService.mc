import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// The phone asked while the app was closed: send, then let the background
// process end (Sender calls Background.exit when its queue is done).
(:background)
class BridgeService extends System.ServiceDelegate {
    function initialize() {
        ServiceDelegate.initialize();
    }

    function onPhoneAppMessage(msg as Communications.PhoneAppMessage) as Void {
        Sender.handle(msg.data, true);
    }
}
