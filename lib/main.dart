import 'package:flutter/material.dart';
import 'package:kittkatflutterlibrary/kittkatflutterlibrary.dart';

import './lang/en_us.dart' as en_us;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setLangMap(en_us.en_us);
  AppTheme appTheme = AppTheme();
  Aspect.aspectWidth = 3;
  Aspect.aspectHeight = 4;
  runApp(ThemedWidget(widget: const MyApp(), theme: appTheme));
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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(getLang("titleApp")),
      ),
      body: Center(
        child: Aspect(child: Column(
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '# TODO',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Row(mainAxisSize: .min, children: [
              IconButton(onPressed: (){}, icon: Icon(Icons.play_arrow)), // TODO
            ],)
          ],
        )),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (){},
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

}

