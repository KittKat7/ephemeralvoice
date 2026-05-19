import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kittkatflutterlibrary/kittkatflutterlibrary.dart';

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './lang/en_us.dart' as en_us;


final record = AudioRecorder();
final player = AudioPlayer();
final _numOfDeterminationOptions = 5;
final random = Random(DateTime.now().millisecondsSinceEpoch);

late final SharedPreferences prefs;
final Map<String, dynamic> defaultSettings = {
  'theme': 0,
  'mode': 0,
  'loop': false
};
final Map<String, Type> settingsTypes = {
  'theme': int,
  'mode': int,
  'loop': bool,
};
Map<String, dynamic> settings = {};
late final AppTheme appTheme;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setLangMap(en_us.en_us);
  appTheme = AppTheme();
  Aspect.aspectWidth = 3;
  Aspect.aspectHeight = 4;
  await loadSettings();
  setColor(ThemeColors.values[getSetting('theme')], false);
  setMode(ThemeModes.values[getSetting('mode')], false);
  await record.hasPermission();
  runApp(ThemedWidget(widget: const MyApp(), theme: appTheme));
}

Future<void> loadSettings() async {
  prefs = await SharedPreferences.getInstance();
  String? settingsJson = prefs.getString('settings');
  if (settingsJson != null) {
    settings = jsonDecode(settingsJson);
  } else {
    settings = defaultSettings;
  }
  for (String k in defaultSettings.keys) {
    if (!settings.containsKey(k) || settings[k].runtimeType != settingsTypes[k]) {
      settings[k] = defaultSettings[k];
    }
  }
}

void saveSettings() {
  prefs.setString('settings', jsonEncode(settings));
}

void setSetting(String key, dynamic value) {
  if (!defaultSettings.containsKey(key)) return;
  if (value.runtimeType != settingsTypes[key]) {
    settings[key] = defaultSettings[key];
  } else {
    settings[key] = value;
  }
  saveSettings();
}

dynamic getSetting(String key) {
  if (defaultSettings.containsKey(key) && settings[key].runtimeType == settingsTypes[key]) {
    return settings[key];
  }
  return defaultSettings[key];
}

enum ThemeColors {
  red,
  orange,
  yellow,
  green,
  blue,
  purple
}

enum ThemeModes {
  auto,
  light,
  dark
}

void setColor(ThemeColors color, [bool updateSettings = true]) {
  Color c;
  switch(color) {
    case ThemeColors.orange:
      c = Colors.orange;
    case ThemeColors.yellow:
      c = Colors.yellow;
    case ThemeColors.green:
      c = Colors.green;
    case ThemeColors.blue:
      c = Colors.blue;
    case ThemeColors.purple:
      c = Colors.purple;
    default:
      c = Colors.red;
      color = ThemeColors.red;
  }
  appTheme.setColor(c);
  if (updateSettings) setSetting('theme', color.index);
}

void cycleColor() {
  int color = getSetting('theme');
  color = (color + 1) % ThemeColors.values.length;
  setColor(ThemeColors.values[color]);
}

void setMode(ThemeModes mode, [bool updateSettings = true]) {
  switch(mode) {
    case ThemeModes.light:
      appTheme.setLightMode();
    case ThemeModes.dark:
      appTheme.setDarkMode();
    default:
      appTheme.setSystemMode();
  }
  if (updateSettings) setSetting('mode', mode.index);
}

void cycleMode() {
  int mode = getSetting('mode');
  mode = (mode + 1) % ThemeModes.values.length;
  setMode(ThemeModes.values[mode]);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: getLang('titleApp'),
      home: const MyHomePage(),
      theme: appTheme.getThemeDataLight(context),
      darkTheme: appTheme.getThemeDataDark(context),
      themeMode: appTheme.getThemeMode(context),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(onPressed: () => SettingsPopup.show(context), icon: Icon(Icons.settings))
        ],
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(getLang("titleApp")),
      ),
      body: Center(
        child: Aspect(child: Column(
          mainAxisAlignment: .center,
          children: [
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(motivationSnack());
              },
              child: Text(
                getLang('titleApp'),
                style: Theme.of(context).textTheme.headlineMedium,
              )
            ),
            RecordWidget()
          ],
        )),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => HelpPopup.show(context),
        tooltip: getLang('pptHelp'),
        child: Icon(Icons.help),
      ),
    );
  }
}

enum RecordingStates {
  stopped,
  recording,
  playback,
}

class RecordWidget extends StatefulWidget {
  const RecordWidget({super.key});

  @override
  State<StatefulWidget> createState() => _RecordWidgetState();
}

class _RecordWidgetState extends State<RecordWidget> {
  RecordingStates state = RecordingStates.stopped;
  String? path;
  Duration duration = Duration();
  Duration currentDuration = Duration();
  DateTime _start = DateTime.now();
  Timer? _timer;
  String _durationString = "";

  @override
  initState() {
    super.initState();
    player.onDurationChanged.listen((Duration d) {
      updateDuration(d);
    });
    player.onPositionChanged.listen((Duration d) {
      setState(() => currentDuration = d);
    });
    _durationString = getLang('pptDuration', [duration.inMilliseconds]);
    player.setReleaseMode(getSetting('loop') ? .loop : .stop);
  }

  void updateDuration(Duration d) {
    setState(() {
      duration = d;
      _durationString = getLang('pptDuration', [(duration.inMilliseconds / 1000).toStringAsFixed(1)]);
    });
  }

  Future<void> startRecord() async {
    if (state != RecordingStates.stopped) await stopRecord();
    await record.start(RecordConfig(encoder: .opus), path: "recording");

    _start = DateTime.now();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        updateDuration(DateTime.now().difference(_start));
    });

    setState(() {
      state = RecordingStates.recording;
    });
  }

  Future<void> stopRecord() async {
    if (state == RecordingStates.recording) {
      _timer?.cancel();
      _timer = null;

      path = await record.stop();
      await Future.delayed(const Duration(milliseconds: 200));

      setState(() {
        state = RecordingStates.stopped;
      });
    }
    else if (state == RecordingStates.playback) {
      await player.stop();
      setState(() {
        state = RecordingStates.stopped;
      });
    }
  }

  Future<void> startPlayback() async {
    if (state != RecordingStates.stopped) await stopRecord();
    if (state == RecordingStates.playback || path == null) return;
    await player.play(UrlSource(path!));
    setState(() {
      state = RecordingStates.playback;
    });
  }

  Future<void> toggleLoop() async {
    final newMode = player.releaseMode == ReleaseMode.loop
        ? ReleaseMode.stop
        : ReleaseMode.loop;

    setSetting('loop', newMode == ReleaseMode.loop);

    await player.setReleaseMode(newMode);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Total duration display
      Text(_durationString),
      // Progress bar
      LinearProgressIndicator(value: currentDuration.inMilliseconds / duration.inMilliseconds),
      // Control buttons
      Row(mainAxisSize: .min, children: [
        IconButton(
          onPressed: () => startRecord(),
          icon: Icon(state == RecordingStates.recording? Icons.mic: Icons.mic_off_outlined)),
        IconButton(
          onPressed: () => stopRecord(),
          icon: Icon(state == RecordingStates.stopped? Icons.stop_circle: Icons.stop_circle_outlined)),
        IconButton(
          onPressed: () => startPlayback(),
          icon: Icon(state == RecordingStates.playback? Icons.play_arrow: Icons.play_arrow_outlined)), 
        IconButton(
          onPressed: toggleLoop,
          icon: Icon(player.releaseMode == ReleaseMode.loop? Icons.loop: Icons.one_x_mobiledata)), 
      ]),
    ]);
  }
}

class HelpPopup extends StatelessWidget {
  const HelpPopup({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return HelpPopup();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Aspect(child: AlertDialog(
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(getLang('btnClose')))
      ],
      title: Text(getLang('hdrHelp')),
      content: SingleChildScrollView(child: Marked(getLang('txtHelp')))));
  }

}

class SettingsPopup extends StatefulWidget {
  const SettingsPopup({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return SettingsPopup();
      },
    );
  }
  
  @override
  State<StatefulWidget> createState() => _SettingsPupopState();
}

class _SettingsPupopState extends State<SettingsPopup> {
  @override
  Widget build(BuildContext context) {
    return Aspect(child: AlertDialog(
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(getLang('btnClose')))
      ],
      title: Text(getLang('hdrSettings')),
      content: Column(mainAxisSize: .min, children: [
        Row(children: [
          Expanded(child: ElevatedButton(onPressed: () => setState(() => cycleColor()), child: Text(getLang('btnSettingsTheme', [getLang('btnSettingsTheme-C${getSetting('theme')}')]))))]),
        Row(children: [Expanded(child: ElevatedButton(onPressed: () => setState(() => cycleMode()), child: Text(getLang('btnSettingsMode', [getLang('btnSettingsMode-M${getSetting('mode')}')]))))])
      ])));
  }
}

SnackBar motivationSnack() {
  return SnackBar(
    content: Text(getLang('determination-${random.nextInt(_numOfDeterminationOptions)}')),
    action: SnackBarAction(
      label: getLang('btnClose'),
      onPressed: () {
        // Some code to undo the change.
      },
    )
  );
}

