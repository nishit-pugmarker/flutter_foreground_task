import 'dart:isolate';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'sql_helper.dart';

class InstagramProfile {
  final String username;
  final String display_name;
  final String avtar;
  final String followers;
  final String following;

  /* Constructor */
  InstagramProfile({
    required this.username,
    required this.display_name,
    required this.avtar,
    required this.followers,
    required this.following
  });
}
void main() => runApp(MaterialApp(home: MyApp()));

// The callback function should always be a top-level function.
void startCallback() {
  // The setTaskHandler function must be called to handle the task in the background.
  //print("callback called");
  FlutterForegroundTask.setTaskHandler(FirstTaskHandler());
}

class FirstTaskHandler extends TaskHandler {
  int updateCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    // You can use the getData function to get the data you saved.
    final customData =
    await FlutterForegroundTask.getData<String>(key: 'customData');
    //print('customData: $customData');
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    //print(" ------------- ");
    var data = await SQLHelper.getItems();
    String message="";
    data.forEach((element) async {

      var _instagramProfile = await getInstagramProfile(element['username']);
      await SQLHelper.updateItem(

          element['id'], element['username'],_instagramProfile.display_name,_instagramProfile.avtar,_instagramProfile.followers,_instagramProfile.following);
    });
    data = await SQLHelper.getItems();
    data.forEach((element) {
      message+=element['username']+" : "+ element['followers']+"\n";
    });

    FlutterForegroundTask.updateService(
        notificationTitle: "$timestamp",
        notificationText: "$message",
        //callback: updateCount >= 10 ? updateCallback : null
        );

    // Send data to the main isolate.
    sendPort?.send(timestamp);
    sendPort?.send(updateCount);

    updateCount++;
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // You can use the clearAllData function to clear all the stored data.
    //print("Task 1 destroyed");
    await FlutterForegroundTask.clearAllData();
  }

  @override
  Future<void> onButtonPressed(String id) async {
    // Called when the notification button on the Android platform is pressed.
    //print('onButtonPressed >> $id');
    if(id=="sendButton"){
      await FlutterForegroundTask.restartService();
    }else {
      FlutterForegroundTask.updateService(
          notificationTitle: 'handle action button',
          notificationText: "$id");
    }

  }
}

void updateCallback() {
  //print("-0-0-0-0-0-0-0-0-0");
  //FlutterForegroundTask.setTaskHandler(SecondTaskHandler());
}

/*class SecondTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {

  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    print(" ------------- ");
    FlutterForegroundTask.updateService(
        notificationTitle: 'SecondTaskHandler',
        notificationText: timestamp.toString());

    // Send data to the main isolate.
    sendPort?.send(timestamp);
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
print("Destroyed");
  }
}*/

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Map<String, dynamic>> _journals = [];
  bool _isLoading = true;
  void _refreshJournals() async {
    final data = await SQLHelper.getItems();
    setState(() {
      _journals = data;
      _isLoading = false;
    });
  }


  ReceivePort? _receivePort;

  Future<void> _initForegroundTask() async {
    await FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'notification_channel_id',
        channelName: 'Foreground Notification',
        channelDescription:
        'This notification appears when the foreground service is running.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        buttons: [
          const NotificationButton(id: 'sendButton', text: 'Restart'),
          //const NotificationButton(id: 'testButton', text: 'Test'),
        ],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 60000*15,//60000 = 1 minute
        autoRunOnBoot: true,
        allowWifiLock: true,
      ),
      printDevLog: false,
    );
  }

  Future<bool> _startForegroundTask() async {
    // You can save data using the saveData function.
    await FlutterForegroundTask.saveData(key: 'customData', value: 'hello');

    ReceivePort? receivePort;
    if (await FlutterForegroundTask.isRunningService) {
      receivePort = await FlutterForegroundTask.restartService();
    } else {
      receivePort = await FlutterForegroundTask.startService(
        notificationTitle: 'Foreground Service is running',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }

    if (receivePort != null) {
      _receivePort = receivePort;
      _receivePort?.listen((message) {
        if (message is DateTime) {
          //print('receive timestamp: $message');
        } else if (message is int) {
          //print('receive updateCount: $message');
        }
      });

      return true;
    }

    return false;
  }

  Future<bool> _stopForegroundTask() async {
    return await FlutterForegroundTask.stopService();
  }

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _startForegroundTask();
    _refreshJournals(); // Loading the diary when the app starts
  }

  @override
  void dispose() {
    _receivePort?.close();
    super.dispose();
  }

  final TextEditingController _usernameController = TextEditingController();

  void _showForm(int? id) async {
    if (id != null) {
      // id == null -> create new item
      // id != null -> update an existing item
      final existingJournal =
      _journals.firstWhere((element) => element['id'] == id);
      _usernameController.text = existingJournal['username'];

    }

    showModalBottomSheet(
        context: context,
        elevation: 5,
        isScrollControlled: true,
        builder: (_) => Container(
          padding: EdgeInsets.only(
            top: 15,
            left: 15,
            right: 15,
            // this will prevent the soft keyboard from covering the text fields
            bottom: MediaQuery.of(context).viewInsets.bottom + 120,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(hintText: 'Username'),
              ),
              const SizedBox(
                height: 20,
              ),
              ElevatedButton(
                onPressed: () async {
                  // Save new journal
                  if (id == null) {
                    await _addItem();
                  }

                  if (id != null) {
                    await _updateItem(id);
                  }

                  // Clear the text fields
                  _usernameController.text = '';

                  // Close the bottom sheet
                  Navigator.of(context).pop();
                },
                child: Text(id == null ? 'Create New' : 'Update'),
              )
            ],
          ),
        ));
  }

// Insert a new journal to the database
  Future<void> _addItem() async {
    var _instagramProfile =
    await getInstagramProfile(_usernameController.text);
    await SQLHelper.createItem(
        _usernameController.text,_instagramProfile.display_name,_instagramProfile.avtar,_instagramProfile.followers,_instagramProfile.following);
    _refreshJournals();
  }



  // Update an existing journal
  Future<void> _updateItem(int id) async {
    var _instagramProfile =
    await getInstagramProfile(_usernameController.text);
    await SQLHelper.updateItem(

        id, _usernameController.text,_instagramProfile.display_name,_instagramProfile.avtar,_instagramProfile.followers,_instagramProfile.following);
    _refreshJournals();
  }

  // Delete an item
  void _deleteItem(int id) async {
    await SQLHelper.deleteItem(id);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Successfully deleted a journal!'),
    ));
    _refreshJournals();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // A widget that prevents the app from closing when the foreground service is running.
      // This widget must be declared above the [Scaffold] widget.
      home: WithForegroundTask(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter Foreground Task'),
            centerTitle: true,
              actions: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 10.0),
            child: GestureDetector(
              onTap: _startForegroundTask,
              child: Icon(
                Icons.play_arrow,
                size: 26.0,
              ),
            )
        ),
                Padding(
                    padding: EdgeInsets.only(right: 10.0),
                    child: GestureDetector(
                      onTap: _stopForegroundTask,
                      child: Icon(
                        Icons.pause,
                        size: 26.0,
                      ),
                    )
                )
              ]
          ),
          body: _isLoading
              ? const Center(
            child: CircularProgressIndicator(),
          )
              : ListView.builder(
            itemCount: _journals.length,
            itemBuilder: (context, index) => Card(
              color: Colors.orange[200],
              margin: const EdgeInsets.all(15),
              child: ListTile(
                  leading: Image.network(_journals[index]['avtar']),
                  title: Text(_journals[index]['username']),
                  subtitle: Text(_journals[index]['display_name']+"\n"+"Follower :"+_journals[index]['followers']+"\n"+"Following :"+_journals[index]['following']),
                  trailing: SizedBox(
                    width: 100,
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showForm(_journals[index]['id']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              _deleteItem(_journals[index]['id']),
                        ),
                      ],
                    ),
                  )),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.add),
            onPressed: () => _showForm(null),
          ),

        ),
      ),
    );
  }

}

Future<InstagramProfile> getInstagramProfile(String username) async {

  String _username, _display_name, _avtar, _followers, _following;

  late InstagramProfile _instagramProfile;

  /* It was tricky to get profile data of an Instagram user by performing a simple get request. In 2020 is was possible get the json data with url of the format:

    "https://www.instagram.com/" + username + "/?__a=1"
    Since 2021 you have to add "/channel" to make it work. The resulting url is:
    "https://www.instagram.com/" + username "/channel/?__a=1"
    But even this is not working as stable as expected. Requesting the json from MacBook with Firefox was no problem, but performing the get request inside Flutter led to complications which occurred sporadically.
    The temporary solution: With network analysis inside Firefox on MacBook, it was possible to see the http get request header from the request. The header was copied and is now used in the flutter application.
    In the header of the response are mentioned different expiration dates:
    30.10.2021, 21.01.2022 and 22.10.2022. I dont know how long the cookie in the header is valid, so this is not a permanent solution.

    Sources for further information:
    - https://stackoverflow.com/questions/49265339/instagram-a-1-url-not-working-anymore-problems-with-graphql-query-to-get-da/49341049#49341049
    - https://stackoverflow.com/questions/48673900/get-json-from-website-instagram

    Also the package flutter_insta 1.0.0 had the some problem, as mentioned here: https://github.com/viralvaghela/flutter_insta/issues/13 */

  String url = "https://www.instagram.com/" + username.trim() + "/?__a=1";
  Map<String, String> _headers = {
    "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:93.0) Gecko/20100101 Firefox/93.0",
    "Cookie":
    'csrftoken=KwugFcdUbqWmIw5gafx4XceFqG7lL0iy; mid=YXGdmQAEAAGZ8KAkPxbouItPlKZW;ig_did=B1A4CD44-2BC0-46D6-9EA8-183539CC48D0;rur="ASH\0541626909116\0541666509625:01f790737601ddb28113116c4f532ec31a70ba9eed81c465a824b04048f33062c5ad07d8"; ds_user_id=1626909116; sessionid=1626909116%3ASJKuakuknKMwgK%3A29; shbid="13780\0541626909116\0541666509141:01f7550222f10cb6d3fe921d0365f3c16d488e2b5fa5d8df394a2e22bf77b6e58c651ba9"; shbts="1634973141\0541626909116\0541666509141:01f76d9c1887499197411336f50b5e86b6bd269a7d945cef01282c80c8f395ac42412c0f"'
  };

  try {
    /* Get data from instagram and decode json */
    var _response =
    await http.get(Uri.parse(Uri.encodeFull(url)), headers: _headers);
    final _extractedData =
    json.decode(_response.body) as Map<String, dynamic>;

    if (_extractedData.isNotEmpty) {
      var _graphql = _extractedData['graphql'];
      var _user = _graphql['user'];

      /* Get profile information */
      _followers = _user['edge_followed_by']['count'].toString();
      _following = _user['edge_follow']['count'].toString();
      _username = _user['username'].toString();
      _display_name = _user['full_name'].toString();
      _avtar = _user['profile_pic_url_hd'].toString();

      /* Save profile information */
      _instagramProfile = InstagramProfile(
          followers: _followers,
          following: _following,
          username: _username,
          display_name: _display_name,
          avtar: _avtar
      );
    }
  } catch (error) {
    print(error);
    //throw error;
    //return false;
  }

  return _instagramProfile;
}