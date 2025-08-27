import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/view/login.dart';


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF379AE6);
    const textColor = Color(0xff171a1f);
    const backgroundColor = Color.fromARGB(255, 255, 255, 255);

    return MaterialApp(
      title: 'Transporte Deltrans',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        scaffoldBackgroundColor: backgroundColor,
        textTheme: Theme.of(context).textTheme.apply(
          fontFamily: 'Nexa',
          bodyColor: textColor,
          displayColor: textColor,
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
