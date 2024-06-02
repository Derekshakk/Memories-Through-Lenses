import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:memories_through_lenses/size_config.dart';

enum ContentType { recent, popular }

class HomePage extends StatefulWidget {
  HomePage({super.key});

  List<String> dropdownItems = ["Item 1", "Item 2", "Item 3"];

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
                  color: Colors.red,
                  child: ListView.builder(
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text("Item $index"),
                      );
                    },
                  ))
            ],
          ),
        ));
  }
}
