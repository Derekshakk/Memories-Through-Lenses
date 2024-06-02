import 'package:flutter/material.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:url_launcher/url_launcher.dart';

class SignupPage extends StatefulWidget {
  SignupPage({super.key});

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw "Could not launch $url";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
      padding: const EdgeInsets.all(50.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Text(
            "SIGNUP",
            style: TextStyle(fontSize: 50),
          ),
          TextField(
            decoration: const InputDecoration(
              hintText: "First Name",
            ),
          ),
          TextField(
            decoration: const InputDecoration(
              hintText: "Last Name",
            ),
          ),
          TextField(
            controller: widget.emailController,
            decoration: const InputDecoration(
              hintText: "Email",
            ),
          ),
          TextField(
            controller: widget.passwordController,
            decoration: const InputDecoration(
              hintText: "Password",
            ),
            obscureText: true,
          ),
          TextField(
            decoration: const InputDecoration(
              hintText: "Confirm Password",
            ),
            obscureText: true,
          ),
          Column(
            children: [
              SizedBox(
                width: 300,
                child: ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                        const Color.fromARGB(255, 162, 210, 255)),
                  ),
                  onPressed: () {
                    Auth()
                        .signUp(widget.emailController.text,
                            widget.passwordController.text)
                        .then((value) {
                      Navigator.pushNamed(context, "/home");
                    });
                  },
                  child: const Text("SIGNUP",
                      style: TextStyle(color: Colors.black)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Already have an account? LOGIN",
                  style: TextStyle(
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      _launchURL("https://www.google.com/");
                    },
                    child: const Text("Privacy Policy",
                        style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline)),
                  ),
                  const Text(" & "),
                  TextButton(
                    onPressed: () {
                      _launchURL("https://www.youtube.com/");
                    },
                    child: const Text("Terms of Service",
                        style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    ));
  }
}
