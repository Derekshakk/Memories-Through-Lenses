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


  String schoolSelection = "Sage Hill School";
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
        widget.passwordController.text == widget.confirmController.text;
  }

  String getMissingFields() {
    List<String> missingFields = [];
    
    if (widget.firstNameController.text.isEmpty) {
      missingFields.add("First Name");
    }
    if (widget.lastNameController.text.isEmpty) {
      missingFields.add("Last Name");
    }
    if (widget.emailController.text.isEmpty) {
      missingFields.add("Email");
    }
    if (widget.passwordController.text.isEmpty) {
      missingFields.add("Password");
    }
    if (widget.confirmController.text.isEmpty) {
      missingFields.add("Confirm Password");
    }
    if (widget.passwordController.text.isNotEmpty && 
        widget.confirmController.text.isNotEmpty && 
        widget.passwordController.text != widget.confirmController.text) {
      missingFields.add("Passwords do not match");
    }
    
    return missingFields.join(", ");
  }

  @override
  Widget build(BuildContext context) {

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
            SizedBox(height: 20,),

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
                    onPressed: () async {
                      if (!canSignUp()) {
                        // Show missing fields message
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Missing Information'),
                              content: Text('Please fill in the following fields: ${getMissingFields()}'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                        return;
                      }

                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      );

                      String? errorMessage = await Auth().signUp(
                        widget.emailController.text,
                        widget.passwordController.text,
                        "${widget.firstNameController.text} ${widget.lastNameController.text}",
                        "Sage Hill School",
                      );

                      // Hide loading indicator
                      Navigator.of(context).pop();

                      if (errorMessage == null) {
                        // Success - show verification alert
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Email Verification Required'),
                              content: const Text(
                                'Please check your email and spam folder to verify your account. You must verify your email before you can log in.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(); // Close dialog
                                    Navigator.pushNamed(context, "/"); // Go to login
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        // Error - show error message
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Signup Error'),
                              content: Text(errorMessage),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            );
                          },
                        );
                      }
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
      ),
    ));
  }
}
