import 'package:example/enums.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'step.dart';

class Pipeline with ChangeNotifier {
  bool followExecution = true;
  int selectedStep = 0;
  List<Step> _steps = [];
  ScrollController scrollC =
      ScrollController(initialScrollOffset: 0.0, keepScrollOffset: true);

  get length => _steps.length;

  set steps(steps) {
    _steps = steps;
    notifyListeners();
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
}
