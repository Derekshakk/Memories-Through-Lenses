import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  LoginPage({super.key});

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "LOGIN",
            style: TextStyle(fontSize: 50),
          ),
          TextField(controller: emailController),
          TextField(
            controller: passwordController,
            obscureText: true,
          ),
          ElevatedButton(onPressed: () {}, child: Text("LOGIN")),
          TextButton(onPressed: () {}, child: Text("Forgot Password?")),
          TextButton(onPressed: () {}, child: Text("Need an account? SIGN UP")),
        ],
      ),
    ));
  }
}
