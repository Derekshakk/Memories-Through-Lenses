import 'package:flutter/material.dart';

class EulaPopup extends StatelessWidget {
  const EulaPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('End User License Agreement'),
      content: const SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            Text('End-User License Agreement (EULA) for MemoLens\n',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'This End-User License Agreement ("Agreement") is a legal agreement between you ("User") and MemoLens ("Company," "we," "us," or "our") regarding your use of the MemoLens application ("App"). By downloading, installing, or using the App, you agree to be bound by the terms and conditions set forth in this Agreement.\n',
            ),
            Text(
              '1. License Grant\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial purposes in accordance with this Agreement.\n',
            ),
            Text(
              '2. Restrictions\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'You agree not to:\n- Modify, copy, distribute, or create derivative works of the App.\n- Reverse engineer, decompile, or disassemble the App.\n- Use the App to engage in any unlawful activity.\n- Post or share any content that is illegal, obscene, defamatory, or violates any third-party rights.\n',
            ),
            Text(
              '3. User-Generated Content\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'MemoLens allows you to post images and other content in groups you create or join ("Content"). By posting Content, you:\n- Warrant that you have the rights to distribute such Content.\n- Grant MemoLens a non-exclusive, royalty-free, worldwide license to use, display, and distribute the Content within the App.\n- Acknowledge that you are solely responsible for the Content you post.\n',
            ),
            Text(
              '4. Termination\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'This Agreement is effective until terminated by you or MemoLens. We may terminate your access to the App at any time without notice if you violate this Agreement.\n',
            ),
            Text(
              '5. Privacy Policy\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Your use of the App is subject to our Privacy Policy, which can be accessed [here].\n',
            ),
            Text(
              '6. Disclaimers\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'The App is provided "as-is" without any warranties, whether express or implied. MemoLens disclaims all liability for any harm or damages arising from your use of the App.\n',
            ),
            Text(
              '7. Limitation of Liability\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'In no event shall MemoLens be liable for any indirect, incidental, or consequential damages arising from your use of the App.\n',
            ),
            Text(
              '8. Governing Law\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'This Agreement shall be governed by and construed in accordance with the laws of [Your Jurisdiction], without regard to its conflict of law principles.\n',
            ),
            Text(
              '9. Changes to this Agreement\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'MemoLens reserves the right to modify this Agreement at any time. Any changes will be effective upon posting the updated Agreement within the App. Your continued use of the App constitutes acceptance of the modified terms.\n',
            ),
            Text(
              '10. Contact Information\n',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'If you have any questions about this Agreement, please contact us at: dereksha2008@gmail.com\n',
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Accept'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: const Text('Decline'),
          onPressed: () {
            Navigator.of(context).pop();
            // Add any logic for declining the EULA if necessary
            Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
          },
        ),
      ],
    );
  }
}
