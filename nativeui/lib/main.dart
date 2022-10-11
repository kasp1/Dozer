import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:fluent_ui/fluent_ui.dart' hide Page;
import 'package:flutter/foundation.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:provider/provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:url_launcher/link.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:window_manager/window_manager.dart';

import 'enums.dart';
import 'model/pipeline.dart';
import 'model/step.dart';
import 'model/theme.dart';

const String appTitle = 'Dozer';

/// Checks if the current environment is a desktop environment.
bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // if it's not on the web, windows or android, load the accent color
  if (!kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.android,
      ].contains(defaultTargetPlatform)) {
    SystemTheme.accentColor.load();
  }

  setPathUrlStrategy();

  if (isDesktop) {
    await flutter_acrylic.Window.initialize();
    await WindowManager.instance.ensureInitialized();
    windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setSize(const Size(800, 600));
      await windowManager.setMinimumSize(const Size(350, 600));
      await windowManager.center();
      await windowManager.show();
      await windowManager.setPreventClose(true);
      await windowManager.setSkipTaskbar(false);
    });
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppTheme>(create: (_) => AppTheme()),
        ChangeNotifierProvider<Pipeline>(create: (_) => Pipeline())
      ],
      builder: (context, _) {
        final appTheme = context.watch<AppTheme>();
        return FluentApp(
          title: appTitle,
          themeMode: appTheme.mode,
          debugShowCheckedModeBanner: false,
          color: appTheme.color,
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            accentColor: appTheme.color,
            visualDensity: VisualDensity.standard,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen() ? 2.0 : 0.0,
            ),
          ),
          theme: ThemeData(
            accentColor: appTheme.color,
            visualDensity: VisualDensity.standard,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen() ? 2.0 : 0.0,
            ),
          ),
          locale: appTheme.locale,
          builder: (context, child) {
            return Directionality(
              textDirection: appTheme.textDirection,
              child: NavigationPaneTheme(
                data: NavigationPaneThemeData(
                  backgroundColor: appTheme.windowEffect !=
                          flutter_acrylic.WindowEffect.disabled
                      ? Colors.transparent
                      : null,
                ),
                child: child!,
              ),
            );
          },
          initialRoute: '/',
          routes: {'/': (context) => const MyHomePage()},
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  bool value = false;
  WebSocketChannel connection = WebSocketChannel.connect(
    Uri.parse('ws://localhost:8220/'),
  );

  final viewKey = GlobalKey();

  final key = GlobalKey();

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();

    connection.stream.listen(
      (data) {
        Map<String, dynamic> json = jsonDecode(data);

        if (json.containsKey('recap')) {
          List<dynamic> recap = json['recap'] as List<dynamic>;
          List<Step> steps = [];

          for (final recapStep in recap) {
            StepStatus status = StepStatus.initial;

            switch (recapStep['status']) {
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

            Step step = Step(
                title: recapStep['title'],
                status: status,
                output: recapStep['output']);

            // Output stepOutput = step.body as Output;
            // stepOutput.state.content = recapStep['output'];

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

          Provider.of<Pipeline>(context, listen: false).steps = steps;
        }

        if (json.containsKey('step') && json.containsKey('output')) {
          var index = json['step'];
          Provider.of<Pipeline>(context, listen: false)
              .appendOutput(index, json['output']);
        }
      },
      onError: (error) => print(error),
      onDone: () => print('Disconnected'),
    );
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
    return Consumer<Pipeline>(builder: (context, pipeline, child) {
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
                return const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(appTitle),
                );
              }
              return const DragToMoveArea(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(appTitle),
                ),
              );
            }(),
            actions: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ToggleButton(
                  child: const Text('Follow'),
                  checked: pipeline.followExecution,
                  onChanged: (v) => pipeline.toggleFollowExecution()),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8.0),
                child: ToggleSwitch(
                  content: const Text('Dark'),
                  checked: FluentTheme.of(context).brightness.isDark,
                  onChanged: (v) {
                    if (v) {
                      appTheme.mode = ThemeMode.dark;
                    } else {
                      appTheme.mode = ThemeMode.light;
                    }
                  },
                ),
              ),
              const SizedBox(
                  width: 100.0,
                  child: TextBox(
                    placeholder: 'Filter',
                    expands: false,
                    autocorrect: false,
                    enableSuggestions: true,
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
                child: FluentTheme.of(context).brightness.isDark
                    ? Image.asset('assets/logo-light100.png')
                    : Image.asset('assets/logo-dark100.png'),
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
                      padding: const EdgeInsets.all(5),
                      children: [
                        RichText(
                          text: TextSpan(
                            text: pipeline[index].output,
                            style: DefaultTextStyle.of(context).style,
                            children: const <TextSpan>[
                              TextSpan(
                                  text: 'bold',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: ' world!'),
                            ],
                          ),
                        )
                      ],
                    ))),
            footerItems: [
              PaneItemSeparator(),
              _LinkPaneItemAction(
                icon: const Icon(FluentIcons.documentation),
                title: const Text('Documentation'),
                link: 'https://github.com/kasp1/Dozer',
                body: const SizedBox.shrink(),
              ),
              _LinkPaneItemAction(
                icon: const Icon(FluentIcons.chat),
                title: const Text('Discord'),
                link: 'https://discord.gg/JJDxmpVT6v',
                body: const SizedBox.shrink(),
              ),
            ],
          ));
    });
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

  chooseIcon(StepStatus status) {
    switch (status) {
      case StepStatus.initial:
        return const Icon(FluentIcons.location_dot);
      case StepStatus.progress:
        return const RotatedBox(
          quarterTurns: 2,
          child: Icon(FluentIcons.skype_arrow),
        );
      case StepStatus.success:
        return const Icon(FluentIcons.skype_check);
      case StepStatus.failure:
        return const Icon(FluentIcons.status_circle_error_x);
    }
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

class _LinkPaneItemAction extends PaneItem {
  _LinkPaneItemAction({
    required super.icon,
    required this.link,
    required super.body,
    super.title,
  });

  final String link;

  @override
  Widget build(
    BuildContext context,
    bool selected,
    VoidCallback? onPressed, {
    PaneDisplayMode? displayMode,
    bool showTextOnTop = true,
    bool? autofocus,
    int? itemIndex,
  }) {
    return Link(
      uri: Uri.parse(link),
      builder: (context, followLink) => super.build(
        context,
        selected,
        followLink,
        displayMode: displayMode,
        showTextOnTop: showTextOnTop,
        itemIndex: itemIndex,
        autofocus: autofocus,
      ),
    );
  }
}
