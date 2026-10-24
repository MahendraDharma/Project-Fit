// The profile picture: one photo the user picks from this phone, copied into
// the app's own documents folder and shown wherever the avatar is. Never
// uploaded, never part of an export's health data.
//
// Only the FILE NAME is stored. iOS moves the app's container on every update,
// so an absolute path saved today points nowhere after the next install.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../state/prefs.dart';

const String kProfilePhotoPref = 'profile.photo_file';

class ProfilePhoto {
  ProfilePhoto._();

  /// The current photo, or null. Every avatar listens to this.
  static final ValueNotifier<File?> current = ValueNotifier<File?>(null);

  /// Resolve the stored name against this install's documents folder.
  static Future<void> load() async {
    final name = Prefs.getString(kProfilePhotoPref, '');
    if (name.isEmpty) return;
    try {
      final f = File(p.join((await getApplicationDocumentsDirectory()).path, name));
      current.value = f.existsSync() ? f : null;
    } catch (e) {
      debugPrint('[profile_photo] load: $e');
    }
  }

  /// Ask for a photo and keep a copy. Returns false when nothing was picked.
  static Future<bool> pick() async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      final path = picked?.files.single.path;
      if (path == null) return false;
      final dir = await getApplicationDocumentsDirectory();
      // A new name each time, so an image cache keyed on the path shows the
      // new picture instead of the old one.
      final name = 'profile_photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(path)}';
      final copy = await File(path).copy(p.join(dir.path, name));
      await _forgetFile();
      Prefs.setString(kProfilePhotoPref, name);
      current.value = copy;
      return true;
    } catch (e) {
      debugPrint('[profile_photo] pick: $e');
      return false;
    }
  }

  static Future<void> remove() async {
    await _forgetFile();
    Prefs.setString(kProfilePhotoPref, '');
    current.value = null;
  }

  static Future<void> _forgetFile() async {
    final old = current.value;
    if (old != null && old.existsSync()) {
      try {
        await old.delete();
      } catch (_) {}
    }
  }
}
