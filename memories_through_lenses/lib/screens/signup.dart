import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:memories_through_lenses/components/eula_popup.dart';

class SignupPage extends StatefulWidget {
  SignupPage({super.key});

  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmController = TextEditingController();
  TextEditingController firstNameController = TextEditingController();
  TextEditingController lastNameController = TextEditingController();

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  @override
  void initState() {
    super.initState();
    _showEulaPopup();
  }

  void _showEulaPopup() {
    Future.delayed(Duration.zero, () {
      showDialog(
        context: context,
        barrierDismissible:
            false, // Prevents the user from dismissing the EULA without interacting
        builder: (BuildContext context) {
          return EulaPopup();
        },
      );
    });
  }

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
            controller: widget.firstNameController,
            decoration: const InputDecoration(
              hintText: "First Name",
            ),
          ),
          TextField(
            controller: widget.lastNameController,
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
            controller: widget.confirmController,
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
                        .signUp(
                      widget.emailController.text,
                      widget.passwordController.text,
                      "${widget.firstNameController.text} ${widget.lastNameController.text}",
                    )
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
                      _launchURL(
                          "https://doc-hosting.flycricket.io/memolens-privacy-policy/8e0f366b-f0ab-4d84-9b7f-f348601fd1dc/privacy");
                    },
                    child: const Text("Privacy Policy",
                        style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline)),
                  ),
                  const Text(" & "),
                  TextButton(
                    onPressed: () {
                      _launchURL(
                          "https://doc-hosting.flycricket.io/memolens-terms-of-use/1dd0cb99-4095-49a1-99c5-76221ca02879/terms");
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
