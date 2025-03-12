import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/services/database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:memories_through_lenses/components/eula_popup.dart';
import 'package:memories_through_lenses/shared/singleton.dart';

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
  String schoolSelection = "";
  final Singleton _singleton = Singleton();
  List<DropdownMenuItem<String>> schools = [
    DropdownMenuItem(
      child: Text("Select School"),
      value: "",
    ),
    DropdownMenuItem(
      child: Text("Sage Hill School"),
      value: "Sage Hill School",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _showEulaPopup();
    Database().getSchools().then((value) {
      print("TESTING: $value");
      schools.clear();
      schools.add(const DropdownMenuItem(
        value: "",
        child: Text("Select School"),
      ));
      setState(() {
        for (Map<String, dynamic> school in value) {
          schools.add(DropdownMenuItem(
            child: Text(school["name"]),
            value: school["id"],
          ));
        }
        _singleton.schoolData = value;
      });
    });
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

  bool canSignUp() {
    return widget.emailController.text.isNotEmpty &&
        widget.passwordController.text.isNotEmpty &&
        widget.confirmController.text.isNotEmpty &&
        widget.firstNameController.text.isNotEmpty &&
        widget.lastNameController.text.isNotEmpty &&
        widget.passwordController.text == widget.confirmController.text &&
        schoolSelection.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    print(schools);
    return Scaffold(
        body: Padding(
      padding: const EdgeInsets.all(50.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(
              "SIGNUP",
              style: GoogleFonts.merriweather(fontSize: 50, color: Colors.black),
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
            DropdownButton(
              items: schools.isNotEmpty
                  ? schools
                  : [
                      const DropdownMenuItem(
                          value: "", child: Text("Select School"))
                    ],
              onChanged: (String? value) {
                setState(() {
                  schoolSelection = value!;
                });
              },
              value: schoolSelection.isEmpty && schools.isNotEmpty
                  ? schools.first.value
                  : schoolSelection,
            ),
            Column(
              children: [
                SizedBox(
                  width: 300,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(
                          const Color.fromARGB(255, 162, 210, 255)),
                    ),
                    // ternary expression: (expression) ? (if true) : (if false)
                    onPressed: canSignUp()
                        ? () {
                            Auth()
                                .signUp(
                              widget.emailController.text,
                              widget.passwordController.text,
                              "${widget.firstNameController.text} ${widget.lastNameController.text}",
                              schoolSelection,
                            )
                                .then((value) {
                              Navigator.pushNamed(context, "/");
                            });
                          }
                        : null,
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
      ),
    ));
  }
}
