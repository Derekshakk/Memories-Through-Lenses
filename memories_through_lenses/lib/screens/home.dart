import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';
import 'package:memories_through_lenses/components/post.dart';
import 'package:memories_through_lenses/components/buttons.dart';
import 'package:memories_through_lenses/services/auth.dart';
import 'package:memories_through_lenses/shared/singleton.dart';

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
  Singleton singleton = Singleton();
  ContentType selected = ContentType.popular;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
        ),
        drawer: Drawer(
          backgroundColor: Color.fromARGB(255, 44, 44, 44),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                SizedBox(
                  height: SizeConfig.blockSizeVertical! * 10,
                ),
                (singleton.userData.containsKey("profile_image"))
                    ? SizedBox(
                        height: SizeConfig.blockSizeHorizontal! * 25,
                        width: SizeConfig.blockSizeHorizontal! * 25,
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: Image.network(
                              singleton.userData["profile_image"],
                              fit: BoxFit.cover,
                            )),
                      )
                    : SizedBox(
                        height: SizeConfig.blockSizeHorizontal! * 25,
                        width: SizeConfig.blockSizeHorizontal! * 25,
                        child: Image.asset("assets/generic_profile.png")),
                Text(
                  "${Auth().user!.displayName}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20),
                ),
                Padding(
                    padding: const EdgeInsets.fromLTRB(85, 0, 85, 0),
                    child: ElevatedButton(
                        onPressed: () {
                          print("Edit profile");
                          Navigator.pushNamed(context, '/profile_edit');
                        },
                        child: const Text("Edit"))),
                Expanded(
                  child: ListView(
                    children: [
                      MenuButton(
                        text: "Create Post",
                        onPressed: () {
                          Navigator.pushNamed(context, '/create');
                        },
                      ),
                      MenuButton(
                        text: "Add/Delete Friends",
                        onPressed: () {
                          Navigator.pushNamed(context, '/received');
                        },
                      ),
                      MenuButton(
                        text: "Manage Groups",
                        onPressed: () {
                          Navigator.pushNamed(context, '/group');
                        },
                      ),
                      MenuButton(
                        text: "Settings",
                        onPressed: () {
                          Navigator.pushNamed(context, '/settings');
                        },
                      ),
                      MenuButton(
                        text: "Log Out",
                        onPressed: () {
                          Auth().logout().then(
                            (value) {
                              Navigator.pushNamedAndRemoveUntil(
                                  context, '/', (route) => false);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
