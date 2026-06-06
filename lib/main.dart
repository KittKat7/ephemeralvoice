// Dart imports
import 'dart:async';
import 'dart:convert';
import 'dart:math';
// Flutter imports
import 'package:flutter/material.dart';
// Package imports
import 'package:kittkatflutterlibrary/kittkatflutterlibrary.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
// Local imports
import './lang/en_us.dart' as en_us;

// GLOBAL FINAL VARIABLES
/// The AudioRecorder instance.
final record = AudioRecorder();
/// The AudioPlayer instance.
final player = AudioPlayer();
/// How many motivational quotes are there.
final _numOfDeterminationOptions = 5;
/// The Random instance, used for accessing determination messages.
final random = Random(DateTime.now().millisecondsSinceEpoch);
/// The SharedPreferences instance.
late final SharedPreferences prefs;

// APP SETTINGS
/// Default settings.
final Map<String, dynamic> defaultSettings = {
  'theme': 0,
  'mode': 0,
  'loop': false
};
/// The types for all settings.
final Map<String, Type> settingsTypes = {
  'theme': int,
  'mode': int,
  'loop': bool,
};
/// The settings map used by the app.
Map<String, dynamic> settings = {};
/// The AppTheme instance.
late final AppTheme appTheme;

// ENUMS
/// The list of available theme colors for the app.
enum ThemeColors {
  red,
  orange,
  yellow,
  green,
  blue,
  purple
}
/// List of available theme modes for the app.
enum ThemeModes {
  auto,
  light,
  dark
}
/// The recording states for the app.
enum RecordingStates {
  idle,
  recording,
  playback,
}

// Functions
/// Main method, runs things :D
void main() async {
  // Initiate flutter bindings
  WidgetsFlutterBinding.ensureInitialized();
  // Set the aspect ratio
  Aspect.aspectWidth = 3;
  Aspect.aspectHeight = 4;
  // Load app settings
  await loadSettings();
  // Set the app language
  setLangMap(en_us.en_us);
  // Set the app theming settings
  appTheme = AppTheme();
  setColor(ThemeColors.values[getSetting('theme')], false);
  setMode(ThemeModes.values[getSetting('mode')], false);
  // Run the app!
  runApp(ThemedWidget(widget: const MyApp(), theme: appTheme));
}

/// Loads the settings from SharedPreferences. These loaded settings are placed
/// into the [settings] instance.
Future<void> loadSettings() async {
  // Access the preferences and get the json string
  prefs = await SharedPreferences.getInstance();
  String? settingsJson = prefs.getString('settings');
  // If there are settings, load them, otherwise, load defaults.
  if (settingsJson != null) {
    settings = jsonDecode(settingsJson);
  } else {
    settings = defaultSettings;
  }
  // Go through all the loaded settings and check the type. If the type is
  // wrong, load the default instead.
  for (String k in defaultSettings.keys) {
    if (!settings.containsKey(k) || settings[k].runtimeType != settingsTypes[k]) {
      settings[k] = defaultSettings[k];
    }
  }
}

/// Save app settings to preferences.
void saveSettings() {
  prefs.setString('settings', jsonEncode(settings));
}

/// Set a specific setting, and check its type. If the type is wrong, use the
/// default. Once the settings have been updated, save them.
void setSetting(String key, dynamic value) {
  if (!defaultSettings.containsKey(key)) return;
  if (value.runtimeType != settingsTypes[key]) {
    settings[key] = defaultSettings[key];
  } else {
    settings[key] = value;
  }
  saveSettings();
}

/// Get a specific setting, if the setting is present and has the correct type,
/// return it, otherwise, return the default setting, or null if it does not
/// exist.
dynamic getSetting(String key) {
  if (defaultSettings.containsKey(key) && settings[key].runtimeType == settingsTypes[key]) {
    return settings[key];
  }
  return defaultSettings[key];
}

/// Set the app theme color.
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

/// Cycle the app theme color to the next available color.
void cycleColor() {
  int color = getSetting('theme');
  color = (color + 1) % ThemeColors.values.length;
  setColor(ThemeColors.values[color]);
}

/// Set the app theme mode.
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

/// Cycle the app theme mode.
void cycleMode() {
  int mode = getSetting('mode');
  mode = (mode + 1) % ThemeModes.values.length;
  setMode(ThemeModes.values[mode]);
}

/// The actual app class.
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

/// The home page widget.
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

/// The recording widget - Really, the main widget for the app.
class RecordWidget extends StatefulWidget {
  const RecordWidget({super.key});

  @override
  State<StatefulWidget> createState() => _RecordWidgetState();
}
/// State for the recording widget.
class _RecordWidgetState extends State<RecordWidget> {
  // Recording state variables
  RecordingStates state = RecordingStates.idle;
  String? path;
  Duration duration = Duration();
  Duration currentDuration = Duration();
  DateTime _start = DateTime.now();
  Timer? _timer;
  String _durationString = "";

  // Initializing the state
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

  /// Updates the duration for the recording and refresh the state
  void updateDuration(Duration d) {
    setState(() {
      duration = d;
      _durationString = getLang('pptDuration', [(duration.inMilliseconds / 1000).toStringAsFixed(1)]);
    });
  }

  /// Starts recording
  Future<void> startRecord() async {
    if (state != RecordingStates.idle) await stopRecord();
    if (!(await record.hasPermission())) {
      MicPopup.show(context);
      return;
    }
  
    await record.start(RecordConfig(encoder: .opus), path: "recording");

    _start = DateTime.now();

    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        updateDuration(DateTime.now().difference(_start));
    });

    WakelockPlus.enable();
    setState(() {
      state = RecordingStates.recording;
    });
  }

  /// Stops the recording or playback
  Future<void> stopRecord() async {
    if (state == RecordingStates.recording) {
      _timer?.cancel();
      _timer = null;

      path = await record.stop();
      await Future.delayed(const Duration(milliseconds: 200));

      WakelockPlus.disable();
      setState(() {
        state = RecordingStates.idle;
      });
    }
    else if (state == RecordingStates.playback) {
      await player.stop();
      WakelockPlus.disable();
      setState(() {
        state = RecordingStates.idle;
      });
    }
  }

  /// Start playback
  Future<void> startPlayback() async {
    if (state != RecordingStates.idle) await stopRecord();
    if (state == RecordingStates.playback || path == null) return;
    await player.play(UrlSource(path!));
    WakelockPlus.enable();
    setState(() {
      state = RecordingStates.playback;
    });
  }

  /// Toggle between looping or play once.
  Future<void> toggleLoop() async {
    final newMode = player.releaseMode == ReleaseMode.loop
        ? ReleaseMode.stop
        : ReleaseMode.loop;

    setSetting('loop', newMode == ReleaseMode.loop);

    await player.setReleaseMode(newMode);

    setState(() {});
  }

  // Build the widget
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
          icon: Icon(state == RecordingStates.idle? Icons.stop_circle: Icons.stop_circle_outlined)),
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

/// A popup that is shown when mic permissions are disabled.
class MicPopup extends StatelessWidget {
  const MicPopup({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return MicPopup();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Aspect(child: AlertDialog(
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(getLang('btnClose')))
      ],
      title: Text(getLang('hdrMicDisabled')),
      content: SingleChildScrollView(child: Marked(getLang('txtMicDisabled')))));
  }
}

/// A help popup to tell you helpfull stuff.
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

/// A popup to allow you to change settings.
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
/// The state for the settings popup.
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

/// A snack to keep you motivated!
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

