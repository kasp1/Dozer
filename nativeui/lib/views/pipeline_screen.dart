import 'dart:ui';

import 'package:dozer/debounce.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Page;
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:clipboard/clipboard.dart';
import 'package:get/get.dart';

import 'package:dozer/enums.dart';
import 'package:dozer/model/pipeline.dart';
import 'package:dozer/model/theme.dart';
import 'package:dozer/views/widgets/link_pane_item.dart';
import 'package:dozer/model/outputs.dart';

class PipelineScreen extends StatelessWidget with WindowListener {
  PipelineScreen({Key? key}) : super(key: key) {
    windowManager.addListener(this);
  }

  late BuildContext widgetContext;
  final viewKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    widgetContext = context;

    final appTheme = context.watch<AppTheme>();

    final pipeline = Get.put(Pipeline());
    final outputs = Get.put(Outputs());

    final theme = FluentTheme.of(context);
    final Debounce _debounce = Debounce(const Duration(milliseconds: 400));

    return GetX<Pipeline>(
        builder: (_) => NavigationView(
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
                    child: Text(pipeline.title.value),
                  );
                }

                return DragToMoveArea(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(pipeline.title.value),
                  ),
                );
              }(),
              actions: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                executionStatusNotification(pipeline.executionStatus.value),
                Tooltip(
                    message: 'Automatically follow pipeline progress.',
                    child: IconButton(
                        icon: pipeline.followExecution.value
                            ? Icon(FluentIcons.pinned_solid, color: Colors.blue)
                            : Icon(FluentIcons.pinned,
                                color: theme.iconTheme.color),
                        onPressed: () => pipeline.followExecution.value =
                            !pipeline.followExecution.value)),
                Tooltip(
                    message: 'Copy output or filtered output.',
                    child: IconButton(
                        icon: const Icon(FluentIcons.copy),
                        onPressed: () => FlutterClipboard.copy(
                            pipeline.filteredOuptut(
                                outputs.steps[pipeline.selectedStep.value])))),
                if (pipeline.steps.isNotEmpty)
                  if (pipeline
                      .steps[pipeline.selectedStep.value].startVars.isNotEmpty)
                    Tooltip(
                        message:
                            'Environment variables the process started with.',
                        child: IconButton(
                            icon: const Icon(FluentIcons.align_horizontal_left),
                            onPressed: () => showVariablesDialog(context,
                                title: 'Starting Variables',
                                vars: pipeline
                                    .steps[pipeline.selectedStep.value]
                                    .startVars))),
                if (pipeline.steps.isNotEmpty)
                  if (pipeline
                      .steps[pipeline.selectedStep.value].endVars.isNotEmpty)
                    Tooltip(
                        message:
                            'Environment variables the process finished with.',
                        child: IconButton(
                            icon:
                                const Icon(FluentIcons.align_horizontal_right),
                            onPressed: () => showVariablesDialog(context,
                                title: 'Finishing Variables',
                                vars: pipeline
                                    .steps[pipeline.selectedStep.value]
                                    .endVars))),
                Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: IconButton(
                        icon: Tooltip(
                            message: 'Switch between dark and light mode.',
                            child: Icon(
                                FluentTheme.of(context).brightness.isDark
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
                          pipeline.filter.value = value;
                        });
                      },
                    )),
                if (!kIsWeb) const WindowButtons(),
              ]),
            ),
            pane: NavigationPane(
              selected: () {
                return pipeline.selectedStep.value;
              }(),
              onChanged: (i) {
                pipeline.selectedStep.value = i;
              },
              header: SizedBox(
                height: kOneLineTileHeight,
                child: ShaderMask(
                  shaderCallback: (rect) {
                    final color = appTheme.color.defaultBrushFor(
                      theme.brightness,
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
                  pipeline.steps.length,
                  (index) => PaneItem(
                      title: Text(pipeline.steps[index].title),
                      infoBadge: Text(pipeline.steps[index].time.value,
                          style: const TextStyle(fontSize: 8)),
                      icon: chooseIcon(pipeline.steps[index].status.value),
                      body: ScaffoldPage.scrollable(
                        scrollController: pipeline.scrollC,
                        children: [
                          GetX<Outputs>(
                              builder: (_) => SelectableText(
                                  outputs.steps[pipeline.selectedStep.value]
                                          .isEmpty
                                      ? 'Waiting for output...'
                                      : pipeline.filteredOuptut(outputs
                                          .steps[pipeline.selectedStep.value]),
                                  style: const TextStyle(fontSize: 12)))
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
                  link: 'https://discord.gg/NvxaZCVku8',
                  body: const SizedBox.shrink(),
                ),
              ],
            )));
  }

  @override
  void onWindowClose() async {
    bool _isPreventClose = await windowManager.isPreventClose();
    if (_isPreventClose) {
      showDialog(
        context: widgetContext,
        builder: (_) {
          return ContentDialog(
            title: const Text('Confirm close'),
            content: const Text('Are you sure you want to close this window?'),
            actions: [
              FilledButton(
                child: const Text('Yes'),
                onPressed: () {
                  Navigator.pop(widgetContext);
                  windowManager.destroy();
                },
              ),
              Button(
                child: const Text('No'),
                onPressed: () {
                  Navigator.pop(widgetContext);
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
        content: LayoutBuilder(builder:
            (BuildContext context, BoxConstraints viewportConstraints) {
          return SingleChildScrollView(
              child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewportConstraints.maxHeight,
                  ),
                  child: Column(
                    children: [
                      const Padding(
                          padding: EdgeInsets.only(bottom: 30),
                          child: Text(
                            'Only selected variables are displayed below: OS, TMP, HOME, JAVA_HOME, PROCESSOR_ARCHITECTURE, and variables added by pipeline steps.',
                            style: TextStyle(
                                color: Color.fromARGB(255, 128, 128, 128)),
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
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ]),
                                  ),
                                ),
                              ),
                              TableCell(
                                child: Text(vars.values.toList()[index],
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontFeatures: [
                                          FontFeature.tabularFigures()
                                        ])),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )));
        }),
        actions: [
          FilledButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);

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
