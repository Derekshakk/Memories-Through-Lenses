import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "LOGIN",
          style: TextStyle(fontSize: 50),
        ),
        TextField(),
        TextField(),
        ElevatedButton(onPressed: () {}, child: Text("LOGIN")),
        TextButton(onPressed: () {}, child: Text("Forgot Password?")),
        TextButton(onPressed: () {}, child: Text("Need an account? SIGN UP")),
      ],
    ));
  }
}
