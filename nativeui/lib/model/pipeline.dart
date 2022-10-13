import 'package:dozer/enums.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'step.dart';

class Pipeline with ChangeNotifier {
  String _title = 'Dozer';
  ExecutionStatus _executionStatus = ExecutionStatus.connecting;
  bool followExecution = true;
  int selectedStep = 0;
  List<Step> _steps = [];
  ScrollController scrollC =
      ScrollController(initialScrollOffset: 0.0, keepScrollOffset: true);
  String _filter = '';

  String get title => _title;

  int get length => _steps.length;

  set steps(List<Step> steps) {
    _steps = steps;
    notifyListeners();
  }

  set title(String title) {
    _title = title;
    notifyListeners();
  }

  set filter(String filter) {
    _filter = filter;
    notifyListeners();
  }

  ExecutionStatus get executionStatus => _executionStatus;

  set executionStatus(ExecutionStatus status) {
    _executionStatus = status;
    notifyListeners();
  }

  bool get finished {
    for (Step step in _steps) {
      if (step.time.isEmpty) {
        return false;
      }
    }

    return true;
  }

  void toggleFollowExecution() {
    followExecution = !followExecution;

    notifyListeners();
  }

  Step operator [](int index) => _steps[index];

  void appendOutput(int stepIndex, String output) {
    _steps[stepIndex].output += output;

    if (followExecution) {
      for (Step step in _steps) {
        if (step.status == StepStatus.progress) {
          selectedStep = _steps.indexOf(step);
        }
      }
    }

    notifyListeners();

    if (followExecution) {
      scrollC.jumpTo(scrollC.position.maxScrollExtent);
    }
  }

  void setTotalTime(int stepIndex, String time) {
    _steps[stepIndex].time = time;
    notifyListeners();
  }

  void updateStatus(
      {required int stepIndex, required StepStatus status, String time = ''}) {
    _steps[stepIndex].status = status;
    _steps[stepIndex].time = time;

    if (status == StepStatus.progress) {
      _title = _steps[stepIndex].title;

      if (followExecution) {
        selectedStep = stepIndex;
      }
    }

    notifyListeners();
  }

  StepStatus strToStepStatus(String str) {
    StepStatus status = StepStatus.initial;

    switch (str) {
      case 'progress':
        status = StepStatus.progress;
        break;
      case 'failure':
        status = StepStatus.failure;
        break;
      case 'success':
        status = StepStatus.success;
        break;
      default:
        status = StepStatus.initial;
    }

    return status;
  }

  String filteredOuptut(String output) {
    if (_filter.isEmpty) {
      return output;
    }

    List<String> lines = output.split('\n');
    List<String> filteredLines = [];

    RegExp regexp = RegExp(RegExp.escape(_filter), caseSensitive: false);

    for (String line in lines) {
      if (regexp.hasMatch(line)) {
        filteredLines.add(line);
      }
    }

    if (filteredLines.isEmpty) {
      filteredLines.add('Nothing seems to match the filter.');
    }

    return filteredLines.join('\n');
  }
}
