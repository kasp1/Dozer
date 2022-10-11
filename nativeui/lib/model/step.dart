import '../enums.dart';

class Step {
  String title;
  String output;
  String time;
  StepStatus status;
  Map<String, String> startVars = {};
  Map<String, String> endVars = {};

  Step(
      {required this.title,
      this.status = StepStatus.initial,
      this.output = '',
      this.time = ''});
}
