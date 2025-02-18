import 'package:http/http.dart' as http;

// Servers for both face recognition and content moderation
class Servers {
  static const String faceRecognitionServer =
      'http://ec2-52-53-167-135.us-west-1.compute.amazonaws.com:5000';

  static const String contentModerationServer = 'http://localhost:5000';

  // contentModeration methods

  // send the image url to the flask server at /predict
  // the server will return a json response with the key 'offensive' which is a bool
  Future<bool> checkImage(String imageUrl) async {
    final response = await http.post(
      Uri.parse('$contentModerationServer/predict'),
      body: {'url': imageUrl},
    ).then((value) {
      // response looks like {"offensive": true, "predictions": [{"class": "subject", "confidence": 0.99}, ..]}
      Map<String, dynamic> data = value.body as Map<String, dynamic>;
      return data['offensive'];
    });

    return response;
  }
}
