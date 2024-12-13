import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';

class Comment extends StatefulWidget {
  const Comment({super.key, required this.description});
  final String description;

  @override
  State<Comment> createState() => _CommentState();
}

class _CommentState extends State<Comment> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: REPLACE WITH ONLONGPRESS WHEN MOVING TO TEST ON DEVICES
        print("Long Pressed");
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return const ReportCommentPopup();
          },
        );
      },
      child: Container(
        height: SizeConfig.blockSizeVertical! * 10,
        color: Colors.white,
        child: Padding(
          // EdgeInsets.all(8.0)
          padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 0.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                    'https://imageio.forbes.com/specials-images/imageserve/5d35eacaf1176b0008974b54/0x0.jpg?format=jpg&crop=4560,2565,x790,y784,safe&height=900&width=1600&fit=bounds'),
              ),
              Container(
                color: Colors.white,
                width: SizeConfig.blockSizeHorizontal! * 70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("Username"),
                        Padding(padding: EdgeInsets.all(5.0)),
                        Text("mm/dd/yyyy",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    Text(widget.description),
                    // TextButton(
                    //   style: TextButton.styleFrom(
                    //       padding: EdgeInsets.zero),
                    //   onPressed: () {},
                    //   child: Text("Reply"),
                    // ),
                    // TextButton(
                    //   style: TextButton.styleFrom(
                    //       padding: EdgeInsets.zero),
                    //   onPressed: () {},
                    //   child: Text("View Replies"),
                    // )
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_border),
                  ),
                  Text("0"),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// report popup
class ReportCommentPopup extends StatelessWidget {
  const ReportCommentPopup({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report Comment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Text('Are you sure you want to report this comment?'),
          TextField(
            decoration: InputDecoration(
              hintText: 'Reason for reporting',
            ),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Report'),
        ),
      ],
    );
  }
}
