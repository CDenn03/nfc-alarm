import 'package:flutter/foundation.dart';

import '../models/nfc_tag.dart';
import '../services/native_channel.dart';

class TagProvider extends ChangeNotifier {
  TagProvider(this._channel);

  final NativeChannel _channel;

  List<NfcTag> _tags = const [];
  List<NfcTag> get tags => _tags;

  NfcStatus status = NfcStatus.ready;

  bool _loading = false;
  bool get loading => _loading;

  Object? _loadError;
  Object? get loadError => _loadError;

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _channel.getTags(),
        _channel.nfcAvailability(),
      ]);
      _tags = (results[0] as List<NfcTag>)
        ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
      status = results[1] as NfcStatus;
    } catch (error) {
      _loadError = error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    status = await _channel.nfcAvailability();
    notifyListeners();
  }

  Future<NfcTag> register({String? name, String? locationType}) async {
    final tag = await _channel.registerTag(
      name: name,
      locationType: locationType,
    );
    await load();
    return tag;
  }

  Future<NfcScan> scan() => _channel.scanTag();

  Future<void> cancel() => _channel.cancelNfc();

  Future<void> delete(String uuid) async {
    await _channel.deleteTag(uuid);
    await load();
  }

  Future<void> rename(String uuid, String name, String? locationType) async {
    await _channel.renameTag(uuid, name, locationType);
    await load();
  }

  Future<void> openNfcSettings() => _channel.openNfcSettings();
}
