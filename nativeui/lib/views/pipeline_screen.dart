import 'dart:convert';
import 'dart:ui';

import 'package:dozer/debounce.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Page;
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:clipboard/clipboard.dart';

import 'package:dozer/enums.dart';
import 'package:dozer/model/step.dart';
import 'package:dozer/model/pipeline.dart';
import 'package:dozer/model/theme.dart';
import 'package:dozer/views/widgets/link_pane_item.dart';

class PipelineScreen extends StatefulWidget {
  const PipelineScreen({Key? key}) : super(key: key);

  @override
  _PipelineScreenState createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> with WindowListener {
  WebSocketChannel connection = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8220/'),
  );

  final viewKey = GlobalKey();

  final key = GlobalKey();

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();

    Pipeline pipeline = Provider.of<Pipeline>(context, listen: false);

    connection.stream.listen(
        (data) {
          if (pipeline.executionStatus != ExecutionStatus.progress) {
            pipeline.executionStatus = ExecutionStatus.progress;
          }

          Map<String, dynamic> json = jsonDecode(data);

          if (json.containsKey('recap')) {
            List<dynamic> recap = json['recap'] as List<dynamic>;
            List<Step> steps = [];

            for (final recapStep in recap) {
              StepStatus status = pipeline.strToStepStatus(recapStep['status']);

              Step step = Step(
                  title: recapStep['title'],
                  status: status,
                  output: recapStep['output']);

              if (status == StepStatus.progress) {
                pipeline.title = recapStep['title'];
              }

              if (status == StepStatus.failure) {
                pipeline.executionStatus = ExecutionStatus.failure;
              }

              if (recapStep.containsKey('totalTime')) {
                step.time = recapStep['totalTime'];
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
            }

            pipeline.steps = steps;
          }

          if (json.containsKey('step') && json.containsKey('output')) {
            var index = json['step'];
            pipeline.appendOutput(index, json['output']);
          }

          if (json.containsKey('step') && json.containsKey('status')) {
            var index = json['step'];
            StepStatus status = pipeline.strToStepStatus(json['status']);

            if (status == StepStatus.failure) {
              pipeline.executionStatus = ExecutionStatus.failure;
            }

            if (json.containsKey('totalTime')) {
              pipeline.updateStatus(
                  stepIndex: index, status: status, time: json['totalTime']);
            } else {
              pipeline.updateStatus(stepIndex: index, status: status);
            }
          }
        },
        onError: (error) => print(error),
        onDone: () async {
          await Future.delayed(const Duration(seconds: 1));

          if (pipeline.finished) {
            if (pipeline.executionStatus != ExecutionStatus.failure) {
              pipeline.executionStatus = ExecutionStatus.success;
            }
          } else {
            pipeline.executionStatus = ExecutionStatus.disconnected;
          }
        });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    connection.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();
    final pipeline = context.watch<Pipeline>();
    final theme = FluentTheme.of(context);
    final Debounce _debounce = Debounce(const Duration(milliseconds: 400));

    return NavigationView(
        key: viewKey,
        transitionBuilder: ((child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            )),
        appBar: NavigationAppBar(
          automaticallyImplyLeading: false,
          title: () {
            if (kIsWeb) {
              return Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(pipeline.title),
              );
            }

            return DragToMoveArea(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(pipeline.title),
              ),
            );
          }(),
          actions: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            executionStatusNotification(pipeline.executionStatus),
            Tooltip(
                message: 'Automatically follow pipeline progress.',
                child: IconButton(
                    icon: pipeline.followExecution
                        ? Icon(FluentIcons.pinned_solid, color: Colors.blue)
                        : Icon(FluentIcons.pinned,
                            color: theme.iconTheme.color),
                    onPressed: () => pipeline.toggleFollowExecution())),
            Tooltip(
                message: 'Copy output or filtered output.',
                child: IconButton(
                    icon: const Icon(FluentIcons.copy),
                    onPressed: () => FlutterClipboard.copy(
                        pipeline.filteredOuptut(
                            pipeline[pipeline.selectedStep].output)))),
            if (pipeline.length > 0)
              if (pipeline[pipeline.selectedStep].startVars.isNotEmpty)
                Tooltip(
                    message: 'Environment variables the process started with.',
                    child: IconButton(
                        icon: const Icon(FluentIcons.align_horizontal_left),
                        onPressed: () => showVariablesDialog(context,
                            title: 'Starting Variables',
                            vars: pipeline[pipeline.selectedStep].startVars))),
            if (pipeline.length > 0)
              if (pipeline[pipeline.selectedStep].endVars.isNotEmpty)
                Tooltip(
                    message: 'Environment variables the process finished with.',
                    child: IconButton(
                        icon: const Icon(FluentIcons.align_horizontal_right),
                        onPressed: () => showVariablesDialog(context,
                            title: 'Finishing Variables',
                            vars: pipeline[pipeline.selectedStep].endVars))),
            Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: IconButton(
                    icon: Tooltip(
                        message: 'Switch between dark and light mode.',
                        child: Icon(FluentTheme.of(context).brightness.isDark
                            ? FluentIcons.sunny
                            : FluentIcons.clear_night)),
                    onPressed: () {
                      if (appTheme.mode == ThemeMode.light) {
                        appTheme.mode = ThemeMode.dark;
                      } else {
                        appTheme.mode = ThemeMode.light;
                      }
                    })),
            SizedBox(
                width: 100.0,
                child: TextBox(
                  placeholder: 'Filter',
                  expands: false,
                  autocorrect: false,
                  enableSuggestions: true,
                  onChanged: (value) {
                    _debounce(() {
                      pipeline.filter = value;
                    });
                  },
                )),
            if (!kIsWeb) const WindowButtons(),
          ]),
        ),
        pane: NavigationPane(
          selected: () {
            return pipeline.selectedStep;
          }(),
          onChanged: (i) {
            setState(() => pipeline.selectedStep = i);
          },
          header: SizedBox(
            height: kOneLineTileHeight,
            child: ShaderMask(
              shaderCallback: (rect) {
                final color = appTheme.color.resolveFromReverseBrightness(
                  theme.brightness,
                  level: theme.brightness == Brightness.light ? 0 : 2,
                );
                return LinearGradient(
                  colors: [
                    color,
                    color,
                  ],
                ).createShader(rect);
              },
              child: Row(children: [
                FluentTheme.of(context).brightness.isDark
                    ? Image.asset('assets/logo-light100.png')
                    : Image.asset('assets/logo-dark100.png')
              ]),
            ),
          ),
          displayMode: PaneDisplayMode.compact,
          indicator: () {
            switch (appTheme.indicator) {
              case NavigationIndicators.end:
                return const EndNavigationIndicator();
              case NavigationIndicators.sticky:
              default:
                return const StickyNavigationIndicator();
            }
          }(),
          items: List<NavigationPaneItem>.generate(
              pipeline.length,
              (index) => PaneItem(
                  title: Text(pipeline[index].title),
                  infoBadge: pipeline[index].time.isNotEmpty
                      ? Text(pipeline[index].time,
                          style: const TextStyle(fontSize: 8))
                      : null,
                  icon: chooseIcon(pipeline[index].status),
                  body: ScaffoldPage.scrollable(
                    scrollController: pipeline.scrollC,
                    children: [
                      SelectableText(
                          pipeline[index].output.isEmpty
                              ? 'Waiting for output...'
                              : pipeline.filteredOuptut(pipeline[index].output),
                          style: const TextStyle(fontSize: 12))
                    ],
                  ))),
          footerItems: [
            PaneItemSeparator(),
            LinkPaneItem(
              icon: const Icon(FluentIcons.documentation),
              title: const Text('Documentation'),
              link: 'https://github.com/kasp1/Dozer',
              body: const SizedBox.shrink(),
            ),
            LinkPaneItem(
              icon: const Icon(FluentIcons.chat),
              title: const Text('Discord'),
              link: 'https://discord.gg/JJDxmpVT6v',
              body: const SizedBox.shrink(),
            ),
          ],
        ));
  }

  @override
  void onWindowClose() async {
    bool _isPreventClose = await windowManager.isPreventClose();
    if (_isPreventClose) {
      showDialog(
        context: context,
        builder: (_) {
          return ContentDialog(
            title: const Text('Confirm close'),
            content: const Text('Are you sure you want to close this window?'),
            actions: [
              FilledButton(
                child: const Text('Yes'),
                onPressed: () {
                  Navigator.pop(context);
                  windowManager.destroy();
                },
              ),
              Button(
                child: const Text('No'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    }
  }

  Widget chooseIcon(StepStatus status) {
    switch (status) {
      case StepStatus.initial:
        return const Icon(FluentIcons.location_dot);
      case StepStatus.progress:
        return const RotatedBox(
          quarterTurns: 2,
          child: Icon(FluentIcons.skype_arrow),
        );
      case StepStatus.success:
        return Icon(FluentIcons.skype_check, color: Colors.teal);
      case StepStatus.failure:
        return const Icon(FluentIcons.status_circle_error_x,
            color: Colors.warningPrimaryColor);
    }
  }

  Widget executionStatusNotification(ExecutionStatus status) {
    switch (status) {
      case ExecutionStatus.success:
        return Padding(
            padding: const EdgeInsets.only(left: 10, right: 10),
            child: Tooltip(
                message: 'The pipeline succeeded.',
                child: Icon(FluentIcons.skype_check, color: Colors.teal)));
      case ExecutionStatus.progress:
        return const SizedBox(width: 0, child: Text(''));
      case ExecutionStatus.disconnected:
        return const SizedBox(
            width: 100,
            child: Text('Disconnected.',
                style: TextStyle(color: Colors.warningPrimaryColor)));
      case ExecutionStatus.connecting:
        return const SizedBox(width: 100, child: Text('Connecting...'));
      case ExecutionStatus.failure:
        return const Padding(
            padding: EdgeInsets.only(left: 10, right: 10),
            child: Tooltip(
                message: 'The pipeline failed.',
                child: Icon(FluentIcons.error_badge12,
                    color: Colors.warningPrimaryColor)));
    }
  }

  void showVariablesDialog(BuildContext context,
      {required String title, required Map<String, String> vars}) async {
    await showDialog<String>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(title),
        content: Column(
          children: [
            const Padding(
                padding: EdgeInsets.only(bottom: 30),
                child: Text(
                  'Only selected variables are displayed below: OS, TMP, HOME, JAVA_HOME, PROCESSOR_ARCHITECTURE, and variables added by pipeline steps.',
                  style: TextStyle(color: Color.fromARGB(255, 128, 128, 128)),
                )),
            Table(
              children: List<TableRow>.generate(
                vars.length,
                (index) => TableRow(
                  children: [
                    TableCell(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          vars.keys.toList()[index],
                          style: const TextStyle(
                              fontSize: 11,
                              fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ),
                    ),
                    TableCell(
                      child: Text(vars.values.toList()[index],
                          style: const TextStyle(
                              fontSize: 11,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
    setState(() {});
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = FluentTheme.of(context);

    return SizedBox(
      width: 138,
      height: 50,
      child: WindowCaption(
        brightness: theme.brightness,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
