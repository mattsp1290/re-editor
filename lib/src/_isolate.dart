part of re_editor;

typedef IsolateRunnable<Req, Res> = Res Function(Req req);
typedef IsolateCallback<Res> = void Function(Res res);

class _IsolateTasker<Req, Res> {
  final String name;
  late bool _closed;

  late IsolateManager<Res, Req>? _isolateManager;
  Timer? _webTimer;
  VoidCallback? _pendingWebTask;
  bool _webFrameScheduled = false;

  _IsolateTasker(this.name, IsolateRunnable<Req, Res> runnable) {
    _closed = false;
    _isolateManager = IsolateManager.create(
      runnable,
      concurrent: 1, // one is enough
    );
  }

  void run(Req req, IsolateCallback<Res> callback) {
    if (_closed) {
      return;
    }
    if (kIsWeb) {
      // isolate_manager's web fallback runs on the UI thread. Let the source
      // edit paint before parsing, retaining only the latest queued analysis.
      _webTimer?.cancel();
      _pendingWebTask = () => _compute(req, callback);
      if (!_webFrameScheduled) {
        _webFrameScheduled = true;
        SchedulerBinding.instance.addPostFrameCallback((_) {
          _webFrameScheduled = false;
          if (_closed) return;
          _webTimer = Timer(const Duration(milliseconds: 16), () {
            final task = _pendingWebTask;
            _pendingWebTask = null;
            if (!_closed) task?.call();
          });
        });
        SchedulerBinding.instance.ensureVisualUpdate();
      }
      return;
    }
    _compute(req, callback);
  }

  void _compute(Req req, IsolateCallback<Res> callback) {
    _isolateManager?.compute(req, callback: (message) async {
      if (_closed) {
        return false;
      }
      callback(message);
      return true;
    });
  }

  void close() {
    _closed = true;
    _webTimer?.cancel();
    _pendingWebTask = null;
    _isolateManager?.stop();
    _isolateManager = null;
  }
}
