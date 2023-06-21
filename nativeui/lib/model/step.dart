import '../enums.dart';
import 'package:get/get.dart';

class Step {
  String title;
  RxString time;
  Rx<StepStatus> status;
  RxMap<String, String> startVars = <String, String>{}.obs;
  RxMap<String, String> endVars = <String, String>{}.obs;

  Step({required this.title, required this.status, required this.time});
}
