import 'package:dozer/enums.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dozer/debounce.dart';
import 'dart:convert';
import 'outputs.dart';
import 'step.dart';

class Pipeline extends GetxController {
  RxString title = 'Dozer'.obs;
  Rx<ExecutionStatus> executionStatus = ExecutionStatus.connecting.obs;
  RxBool followExecution = true.obs;
  RxInt selectedStep = 0.obs;
  RxList<Step> steps = <Step>[].obs;
  final stepOutputs = Get.put(Outputs());

  ScrollController scrollC =
      ScrollController(initialScrollOffset: 0.0, keepScrollOffset: true);
  RxString filter = ''.obs;
  final Debounce _debounce = Debounce(const Duration(milliseconds: 50));

  final WebSocketChannel connection = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8220/'),
  );

  @override
  void onInit() {
    connection.stream.listen(
        (data) {
          if (executionStatus.value != ExecutionStatus.progress) {
            executionStatus.value = ExecutionStatus.progress;
          }

          Map<String, dynamic> json = jsonDecode(data);

          if (json.containsKey('recap')) {
            List<dynamic> recap = json['recap'] as List<dynamic>;
            List<Step> steps = [];
            List<String> outputs = [];

            for (final recapStep in recap) {
              StepStatus status = strToStepStatus(recapStep['status']);

              Step step = Step(
                  title: recapStep['title'], status: status.obs, time: ''.obs);

              if (status == StepStatus.progress) {
                title.value = recapStep['title'];
              }

              if (status == StepStatus.failure) {
                executionStatus.value = ExecutionStatus.failure;
              }

              if (recapStep.containsKey('totalTime')) {
                step.time.value = recapStep['totalTime'];
              }

              Map<String, dynamic> vars = {};

              if (recapStep.containsKey('startVars')) {
                vars = recapStep['startVars'] as Map<String, dynamic>;

                vars.forEach((key, value) {
                  step.startVars[key] = value as String;
                });
              }

              if (recapStep.containsKey('endVars')) {
                vars = recapStep['endVars'] as Map<String, dynamic>;

                vars.forEach((key, value) {
                  step.endVars[key] = value as String;
                });
              }

              steps.add(step);
              outputs.add(recapStep['output']);
            }

            this.steps.assignAll(steps);
            stepOutputs.steps.assignAll(outputs);
          }

          if (json.containsKey('step') && json.containsKey('output')) {
            var index = json['step'];
            appendOutput(index, json['output']);
          }

          if (json.containsKey('step') && json.containsKey('status')) {
            var index = json['step'];
            StepStatus status = strToStepStatus(json['status']);

            if (status == StepStatus.failure) {
              executionStatus.value = ExecutionStatus.failure;
            }

            if (json.containsKey('totalTime')) {
              updateStatus(
                  stepIndex: index, status: status, time: json['totalTime']);
            } else {
              updateStatus(stepIndex: index, status: status);
            }
          }
        },
        onError: (error) => print(error),
        onDone: () async {
          await Future.delayed(const Duration(seconds: 1));

          if (finished) {
            if (executionStatus.value != ExecutionStatus.failure) {
              executionStatus.value = ExecutionStatus.success;
            }
          } else {
            executionStatus.value = ExecutionStatus.disconnected;
          }
        });

    super.onInit();

    print('Init finished.');
  }

  bool get finished {
    for (Step step in steps) {
      if (step.time.isEmpty) {
        return false;
      }
    }

    return true;
  }

  void appendOutput(int stepIndex, String output) {
    stepOutputs.steps[stepIndex] += output;

    if (followExecution.value) {
      for (Step step in steps) {
        if (step.status.value == StepStatus.progress) {
          selectedStep.value = steps.indexOf(step);
        }
      }

      _debounce(() {
        scrollC.jumpTo(scrollC.position.maxScrollExtent);
      });
    }
  }

  void setTotalTime(int stepIndex, String time) {
    steps[stepIndex].time.value = time;
  }

  void updateStatus(
      {required int stepIndex, required StepStatus status, String time = ''}) {
    steps[stepIndex].status.value = status;
    steps[stepIndex].time.value = time;

    if (status == StepStatus.progress) {
      title.value = steps[stepIndex].title;

      if (followExecution.value) {
        selectedStep.value = stepIndex;
      }
    }
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
    if (filter.value.isEmpty) {
      return output;
    }

    List<String> lines = output.split('\n');
    List<String> filteredLines = [];

    RegExp regexp = RegExp(RegExp.escape(filter.value), caseSensitive: false);

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
