import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/size_config.dart';

class LoginPage extends StatefulWidget {
  LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController emailController = TextEditingController();

  TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
      padding: const EdgeInsets.all(65.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "LOGIN",
            style: GoogleFonts.merriweather(fontSize: 50, color: Colors.black),
          ),
          TextField(
              decoration: const InputDecoration(
                hintText: "Email",
              ),
              controller: emailController),
          TextField(
            decoration: const InputDecoration(
              hintText: "Password",
            ),
            controller: passwordController,
            obscureText: true,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: SizeConfig.blockSizeHorizontal! * 80,
                child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                          const Color.fromARGB(255, 162, 210, 255)),
                    ),
                    onPressed: () {
                      Auth()
                          .login(emailController.text, passwordController.text)
                          .then((value) {
                        if (value) {
                          Navigator.pushNamed(context, "/home");
                        } else {
                          // snackbar
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text("Invalid email or password")));
                        }
                      });
                    },
                    child:
                        Text("LOGIN", style: TextStyle(color: Colors.black))),
              ),
              TextButton(
                  onPressed: () {},
                  child: Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Colors.black,
                      decoration: TextDecoration.underline,
                    ),
                  )),
            ],
          ),
          TextButton(
              onPressed: () {
                Navigator.pushNamed(context, "/signup");
              },
              child: Text("Need an account? SIGN UP",
                  style: TextStyle(
                      color: Colors.black,
                      decoration: TextDecoration.underline))),
        ],
      ),
    ));
  }
}
