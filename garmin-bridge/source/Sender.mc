import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;

// Collect what is newer than `since`, cut it into messages, transmit them one
// after another, and end with a summary. One message at a time: the next goes
// only when the last one completed, and a failure stops the run (the phone
// asks again from where its data ends, so nothing is lost).
//
// THE WIRE, one Dictionary per message:
//   {"k" => "stress" | "body_battery" | "spo2", "d" => [t, v, t, v, ...]}
//       t = epoch seconds, v = the watch's value (whole numbers)
//   {"k" => "steps_day", "d" => [t, steps, ...]}  t = the day's start
//   {"k" => "end", "n" => <messages sent before this>, "now" => <epoch s>,
//    "part" => <part number>}
(:background)
module Sender {
    // The longest look back, whatever the phone asks for. The watch keeps
    // only so much history, and a background run has about 30 seconds.
    const MAX_BACK_S = 172800;
    const CHUNK = 240;
    // A background run stops after this many messages; the phone's next ask
    // picks up from there.
    const MAX_BG_MESSAGES = 10;

    var status as String = "Ready";
    var onChange as Method? = null;
    var queue as Array<Dictionary> = [];
    var sent as Number = 0;
    var background as Boolean = false;
    var busy as Boolean = false;
    var newest as Number = 0;

    function lastSent() as Number {
        var v = Application.Storage.getValue("sent");
        return v instanceof Number ? v : 0;
    }

    function handle(data, inBackground as Boolean) as Void {
        var since = 0;
        if (data instanceof Dictionary) {
            var s = data["since"];
            if (s instanceof Number) {
                since = s;
            }
        }
        start(since, inBackground);
    }

    function start(since as Number, inBackground as Boolean) as Void {
        if (busy) {
            return;
        }
        busy = true;
        background = inBackground;
        sent = 0;
        newest = 0;
        setStatus("Reading...");
        queue = collect(since);
        sendNext();
    }

    function setStatus(s as String) as Void {
        status = s;
        var cb = onChange;
        if (cb != null) {
            cb.invoke();
        }
    }

    function sendNext() as Void {
        if (queue.size() == 0 || (background && sent >= MAX_BG_MESSAGES)) {
            var end = {
                "k" => "end",
                "n" => sent,
                "now" => Time.now().value(),
                "part" => System.getDeviceSettings().partNumber
            };
            queue = [];
            Communications.transmit(end, null, new EndListener());
            return;
        }
        var m = queue[0];
        queue = queue.slice(1, null);
        setStatus("Sending " + (sent + 1) + "...");
        Communications.transmit(m, null, new SendListener());
    }

    function sentOne() as Void {
        sent += 1;
        sendNext();
    }

    function finish(ok as Boolean) as Void {
        busy = false;
        if (ok && newest > 0 && !background) {
            Application.Storage.setValue("sent", newest);
        }
        setStatus(ok ? "Sent to phone" : "Phone not reachable");
        if (background) {
            Background.exit(null);
        }
    }

    function collect(since as Number) as Array<Dictionary> {
        var now = Time.now().value();
        var from = since;
        if (from < now - MAX_BACK_S) {
            from = now - MAX_BACK_S;
        }
        var out = [] as Array<Dictionary>;
        var period = new Time.Duration(now - from);
        var opts = {:period => period, :order => SensorHistory.ORDER_OLDEST_FIRST};
        if (SensorHistory has :getStressHistory) {
            series(out, "stress", SensorHistory.getStressHistory(opts), from);
        }
        if (SensorHistory has :getBodyBatteryHistory) {
            series(out, "body_battery", SensorHistory.getBodyBatteryHistory(opts), from);
        }
        if (SensorHistory has :getOxygenSaturationHistory) {
            series(out, "spo2", SensorHistory.getOxygenSaturationHistory(opts), from);
        }
        steps(out);
        return out;
    }

    function series(out as Array<Dictionary>, key as String, it, from as Number) as Void {
        if (it == null) {
            return;
        }
        var flat = [] as Array<Number>;
        var s = it.next();
        while (s != null) {
            var v = s.data;
            var when = s.when;
            if (v != null && when != null) {
                var t = when.value();
                if (t > from) {
                    flat.add(t);
                    flat.add(v.toNumber());
                    if (t > newest) {
                        newest = t;
                    }
                    if (flat.size() >= CHUNK) {
                        out.add({"k" => key, "d" => flat});
                        flat = [] as Array<Number>;
                    }
                }
            }
            s = it.next();
        }
        if (flat.size() > 0) {
            out.add({"k" => key, "d" => flat});
        }
    }

    // Today's total so far, and the days the watch still keeps.
    function steps(out as Array<Dictionary>) as Void {
        var flat = [] as Array<Number>;
        var info = ActivityMonitor.getInfo();
        if (info != null && info.steps != null) {
            flat.add(Time.today().value());
            flat.add(info.steps);
        }
        var hist = ActivityMonitor.getHistory();
        if (hist != null) {
            for (var i = 0; i < hist.size(); i++) {
                var h = hist[i];
                if (h != null && h.startOfDay != null && h.steps != null) {
                    flat.add(h.startOfDay.value());
                    flat.add(h.steps);
                }
            }
        }
        if (flat.size() > 0) {
            out.add({"k" => "steps_day", "d" => flat});
        }
    }
}

(:background)
class SendListener extends Communications.ConnectionListener {
    function initialize() {
        ConnectionListener.initialize();
    }

    function onComplete() as Void {
        Sender.sentOne();
    }

    function onError() as Void {
        Sender.finish(false);
    }
}

(:background)
class EndListener extends Communications.ConnectionListener {
    function initialize() {
        ConnectionListener.initialize();
    }

    function onComplete() as Void {
        Sender.finish(true);
    }

    function onError() as Void {
        Sender.finish(false);
    }
}
