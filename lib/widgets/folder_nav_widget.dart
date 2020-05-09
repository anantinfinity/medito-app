/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/audioplayer/player_widget.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/list_item.dart';
import 'package:Medito/viewmodel/main_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import 'bottom_sheet_widget.dart';
import 'list_item_file_widget.dart';
import 'list_item_image_widget.dart';
import 'loading_list_widget.dart';
import 'nav_pills_widget.dart';

class FolderStateless extends StatelessWidget {
  FolderStateless({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FolderNavWidget();
  }
}

class FolderNavWidget extends StatefulWidget {
  FolderNavWidget({Key key, this.firstId, this.firstTitle, this.textFuture})
      : super(key: key);

  final String firstId;
  final String firstTitle;
  final Future<String> textFuture;

  @override
  _FolderNavWidgetState createState() => _FolderNavWidgetState();
}

class _FolderNavWidgetState extends State<FolderNavWidget>
    with TickerProviderStateMixin {
  final _viewModel = new SubscriptionViewModelImpl();
  Future<List<ListItem>> listFuture;

  String readMoreText = "";
  String textFileFromFuture = "";
  double textFileOpacity = 0;

  BuildContext scaffoldContext;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    listFuture = _viewModel.getPageChildren(id: widget.firstId);
    if (widget.firstTitle != null && widget.firstTitle.isNotEmpty) {
      _viewModel.addToNavList(
          ListItem("Home", "app+content", null, parentId: "app+content"));
      _viewModel
          .addToNavList(ListItem(widget.firstTitle, widget.firstId, null));
    }

    widget.textFuture?.then((onValue) {
      setState(() {
        textFileFromFuture = onValue;
        textFileOpacity = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
    ));

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: MeditoColors.darkBGColor,
        body: new Builder(
          builder: (BuildContext context) {
            scaffoldContext = context;
            return buildSafeAreaBody();
          },
        ),
      ),
    );
  }

  Widget buildSafeAreaBody() {
    checkConnectivity().then((connected) {
      if (!connected) {
        createSnackBar('Check your connectivity', scaffoldContext);
      }
    });

    return SafeArea(
      bottom: false,
      maintainBottomViewPadding: false,
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                  child: Stack(
                children: <Widget>[
                  Visibility(
                    child: getListView(),
                    visible: textFileOpacity == 0,
                  ),
                  AnimatedOpacity(
                      duration: Duration(milliseconds: 100),
                      opacity: textFileOpacity,
                      child: getInnerTextView()),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget getListView() {
    return RefreshIndicator(
      color: MeditoColors.lightColor,
      backgroundColor: MeditoColors.darkColor,
      child: FutureBuilder(
          future: listFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.none) {
              return Text(
                "No connection. Please try again later",
                style: Theme.of(context).textTheme.display2,
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.hasData == false ||
                snapshot.hasData == null) {
              return LoadingListWidget();
            }

            return new ListView.builder(
                itemCount:
                    1 + (snapshot.data == null ? 0 : snapshot.data.length),
                shrinkWrap: true,
                itemBuilder: (BuildContext context, int i) {
                  if (i == 0) {
                    return NavPillsWidget(
                      list: _viewModel.navList,
                      backPressed: _backPressed,
                    );
                  }
                  return Column(
                    children: <Widget>[
                      getChildForListView(snapshot.data[i - 1]),
                    ],
                  );
                });
          }),
      onRefresh: _onPullToRefresh,
    );
  }

  Future<void> _onPullToRefresh() async {
    setState(() {
      listFuture = _viewModel.getPageChildren(
          id: _viewModel.getCurrentPageId(), skipCache: true);
    });
  }

  void folderTap(ListItem i) {
    Tracking.trackEvent(Tracking.FOLDER_TAPPED, Tracking.SCREEN_LOADED, i.id);
    //if you tapped on a folder
    setState(() {
      _viewModel.addToNavList(i);
      listFuture = _viewModel.getPageChildren(id: i.id);
    });
  }

  void fileTap(ListItem item) {
    if (item.fileType == FileType.audiosethourly ||
        item.fileType == FileType.audiosetdaily) {
      Tracking.trackEvent(Tracking.FILE_TAPPED, Tracking.AUDIO_OPENED, item.id);
      _showPlayerBottomSheet(item);
    } else if (item.fileType == FileType.audio) {
      Tracking.trackEvent(Tracking.FILE_TAPPED, Tracking.AUDIO_OPENED, item.id);
      _showPlayerBottomSheet(item);
    } else if (item.fileType == FileType.both) {
      Tracking.trackEvent(Tracking.FILE_TAPPED, Tracking.AUDIO_OPENED, item.id);
      _showPlayerBottomSheet(item);
    } else if (item.fileType == FileType.text) {
      Tracking.trackEvent(
          Tracking.FILE_TAPPED, Tracking.TEXT_ONLY_OPENED, item.id);
      setState(() {
        _viewModel.addToNavList(item);
        textFileOpacity = 1;
      });
    }
  }

  _showPlayerBottomSheet(ListItem listItem) {
    _viewModel.currentlySelectedFile = listItem;

    var data;
    if (listItem.fileType == FileType.audiosetdaily ||
        listItem.fileType == FileType.audiosethourly) {
      data = _viewModel.getAudioFromSet(
          id: listItem.id, timely: listItem.fileType);
    } else {
      data = _viewModel.getAudioData(id: listItem.id);
    }

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => BottomSheetWidget(
            title: listItem.title,
            onBeginPressed: _showPlayer,
            data: data,
          ),
        ));
  }

  _showPlayer(dynamic fileTapped, dynamic coverArt, dynamic coverColor,
      String title, String description, String contentText) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (c) => PlayerWidget(
              fileModel: fileTapped,
              description: description,
              coverArt: coverArt,
              coverColor: coverColor,
              title: title,
              listItem: _viewModel.currentlySelectedFile,
              attributions:
                  _viewModel.getAttributions(fileTapped.attributions)),
        ));
  }

  Widget getFileListItem(ListItem item) {
    return new ListItemWidget(
      item: item,
    );
  }

  Widget getChildForListView(ListItem item) {
    if (item.type == ListItemType.folder) {
      return InkWell(
          onTap: () => folderTap(item),
          splashColor: MeditoColors.darkColor,
          child: getFileListItem(item));
    } else if (item.type == ListItemType.file) {
      return InkWell(
          onTap: () => fileTap(item),
          splashColor: MeditoColors.darkColor,
          child: getFileListItem(item));
    } else {
      return SizedBox(
          width: 300, child: new ImageListItemWidget(src: item.url));
    }
  }

  void _backPressed(String id) {
    setState(() {
      if (_viewModel.navList.length == 1) {
        Navigator.pop(context);
      } else if (_viewModel.navList.length == 2 && widget.firstId.isNotEmpty) {
        Navigator.pop(context);
      } else {
        if (textFileOpacity == 1) {
          textFileOpacity = 0;
        } else {
          if (widget.firstId != null || widget.firstId.isNotEmpty) {
            listFuture = _viewModel.getPageChildren(id: id);
          } else {
            Navigator.pop(context);
          }
        }
        _viewModel.navList.removeLast();
      }
    });
  }

  Future<bool> _onWillPop() {
    if (_viewModel.navList.length > 1) {
      _backPressed(_viewModel.navList.last.parentId);
      Tracking.trackEvent(
          Tracking.BACK_PRESSED,
          Tracking.CURRENTLY_SELECTED_FILE,
          _viewModel.currentlySelectedFile?.id);
    } else {
      return new Future(() => true);
    }
    return new Future(() => false);
  }

  Widget getInnerTextView() {
    String content;

    if (textFileFromFuture.isEmpty) {
      content = _viewModel?.navList?.last?.contentText;
    } else {
      content = textFileFromFuture;
    }

    return IgnorePointer(
      ignoring: textFileOpacity == 0,
      child: Container(
        color: MeditoColors.darkBGColor,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: <Widget>[
                    NavPillsWidget(
                      list: _viewModel?.navList,
                      backPressed: _backPressed,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, bottom: 16.0),
                      child: MarkdownBody(
                        onTapLink: ((url) {
                          launch(url);
                        }),
                        selectable: false,
                        styleSheet: MarkdownStyleSheet.fromTheme(
                                Theme.of(context))
                            .copyWith(
                                a: Theme.of(context).textTheme.body1.copyWith(
                                    decoration: TextDecoration.underline),
                                h1: Theme.of(context).textTheme.title,
                                h2: Theme.of(context).textTheme.headline,
                                h3: Theme.of(context).textTheme.subtitle,
                                listBullet: Theme.of(context).textTheme.subhead,
                                p: Theme.of(context).textTheme.body1),
                        data: content == null ? '' : content,
                        imageDirectory: 'https://raw.githubusercontent.com',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}