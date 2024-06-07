import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/post.dart';

enum ContentType { recent, popular }

class PostData {
  final String mediaURL;
  final String mediaType;
  final int likes;
  final int dislikes;

  PostData(
      {required this.mediaURL,
      required this.mediaType,
      required this.likes,
      required this.dislikes});
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  List<String> dropdownItems = ["Item 1", "Item 2", "Item 3"];

  // list of posts (mediaURL, likes, dislikes)
  List<PostData> posts = [
    PostData(
        mediaURL: "https://picsum.photos/200",
        mediaType: "image",
        likes: 0,
        dislikes: 0),
    PostData(
        mediaURL: "https://www.youtube.com/watch?v=jNQXAC9IVRw",
        mediaType: "video",
        likes: 0,
        dislikes: 0),
    PostData(
        mediaURL: "https://picsum.photos/200",
        mediaType: "image",
        likes: 0,
        dislikes: 0),
    PostData(
        mediaURL: "https://picsum.photos/200",
        mediaType: "image",
        likes: 0,
        dislikes: 0),
    PostData(
        mediaURL: "https://picsum.photos/200",
        mediaType: "image",
        likes: 0,
        dislikes: 0),
  ];

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ContentType selected = ContentType.popular;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
        ),
        drawer: Drawer(),
        endDrawer: Drawer(),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: SizeConfig.blockSizeVertical! * 5,
                width: SizeConfig.blockSizeHorizontal! * 90,
                child: DropdownButton(
                    items: widget.dropdownItems.map<DropdownMenuItem<String>>(
                      (String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      },
                    ).toList(),
                    onChanged: (value) {}),
              ),
              SizedBox(
                width: SizeConfig.blockSizeHorizontal! * 90,
                child: SegmentedButton(
                    segments: const <ButtonSegment<ContentType>>[
                      ButtonSegment<ContentType>(
                          value: ContentType.recent,
                          label: Text('Recent'),
                          icon: Icon(CupertinoIcons.star)),
                      ButtonSegment<ContentType>(
                          value: ContentType.popular,
                          label: Text('Popular'),
                          icon: Icon(CupertinoIcons.flame))
                    ],
                    selected: {
                      selected
                    },
                    onSelectionChanged: (value) {
                      setState(() {
                        selected = value.first;
                      });
                    }),
              ),
              Container(
                  height: SizeConfig.blockSizeVertical! * 70,
                  width: SizeConfig.blockSizeHorizontal! * 100,
                  // color: Colors.red,
                  child: ListView.builder(
                    itemCount: widget.posts.length,
                    itemBuilder: (context, index) {
                      return PostCard(
                          mediaURL: widget.posts[index].mediaURL,
                          mediaType: widget.posts[index].mediaType,
                          likes: widget.posts[index].likes,
                          dislikes: widget.posts[index].dislikes);
                    },
                  ))
            ],
          ),
        ));
  }
}
