
import 'dart:async';
import 'dart:io' as io;

import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await firebase_core.Firebase.initializeApp();
  runApp(StorageExampleApp());
}

enum UploadType {
  string,

  file,

  clear,
}

class StorageExampleApp extends StatelessWidget {
  StorageExampleApp({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Storage Example App',
        theme: ThemeData.dark(),
        home: Scaffold(
          body: TaskManager(),
        )
    );
  }
}


class TaskManager extends StatefulWidget {
  TaskManager({Key key}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _TaskManager();
  }
}

class _TaskManager extends State<TaskManager> {

  List<firebase_storage.UploadTask> _uploadTasks = [];

  Future<firebase_storage.UploadTask> uploadFile(PickedFile file) async {
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No file was selected'),
      ));
      return null;
    }

    firebase_storage.UploadTask uploadTask;

    firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
        .ref()
        .child('playground')
        .child('/some-image.jpg');

    final metadata = firebase_storage.SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'picked-file-path': file.path});

    if (kIsWeb) {
      uploadTask = ref.putData(await file.readAsBytes(), metadata);
    } else {
      uploadTask = ref.putFile(io.File(file.path), metadata);
    }

    return Future.value(uploadTask);
  }

  firebase_storage.UploadTask uploadString() {
    const String putStringText = 'This upload has been generated using the putString method! Check the metadata too!';

    firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
        .ref().child('playground').child('/put-string-example.txt');

    return ref.putString(putStringText,
        metadata: firebase_storage.SettableMetadata(
            contentLanguage: 'en',
            customMetadata: <String, String>{'example': 'putString'}));
  }

  Future<void> handleUploadType(UploadType type) async {
    switch (type) {
      case UploadType.string:
        setState(() {
          _uploadTasks = [..._uploadTasks, uploadString()];
        });
        break;
      case UploadType.file:
        PickedFile file =
        await ImagePicker().getImage(source: ImageSource.gallery);
        firebase_storage.UploadTask task = await uploadFile(file);
        if (task != null) {
          setState(() {
            _uploadTasks = [..._uploadTasks, task];
          });
        }
        break;
      case UploadType.clear:
        setState(() {
          _uploadTasks = [];
        });
        break;
    }
  }

  void _removeTaskAtIndex(int index) {
    setState(() {
      _uploadTasks = _uploadTasks..removeAt(index);
    });
  }



  Future<void> _downloadLink(firebase_storage.Reference ref) async {
    final link = await ref.getDownloadURL();

    await Clipboard.setData(ClipboardData(
      text: link,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Success!\n Copied download URL to Clipboard!',
        ),
      ),
    );
  }

  Future<void> _downloadFile(firebase_storage.Reference ref) async {
    final io.Directory systemTempDir = io.Directory.systemTemp;
    final io.File tempFile = io.File('${systemTempDir.path}/temp-${ref.name}');
    if (tempFile.existsSync()) await tempFile.delete();

    await ref.writeToFile(tempFile);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Success!\n Downloaded ${ref.name} \n from bucket: ${ref.bucket}\n '
              'at path: ${ref.fullPath} \n'
              'Wrote "${ref.fullPath}" to tmp-${ref.name}.txt',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Example App'),
        actions: [
          PopupMenuButton<UploadType>(
            onSelected: handleUploadType,
            icon: const Icon(Icons.add),
            itemBuilder: (context) => [
              const PopupMenuItem(
                // ignore: sort_child_properties_last
                  child: Text('Upload string'),
                  value: UploadType.string),
              const PopupMenuItem(
                // ignore: sort_child_properties_last
                  child: Text('Upload local file'),
                  value: UploadType.file),
              if (_uploadTasks.isNotEmpty)
                const PopupMenuItem(
                  // ignore: sort_child_properties_last
                    child: Text('Clear list'),
                    value: UploadType.clear)
            ],
          )
        ],
      ),
      body: _uploadTasks.isEmpty ? const Center(child: Text("Press the '+' button to add a new file."))
          : ListView.builder(
        itemCount: _uploadTasks.length,
        itemBuilder: (context, index) => UploadTaskListTile(
          task: _uploadTasks[index],
          onDismissed: () => _removeTaskAtIndex(index),
          onDownloadLink: () {
            return _downloadLink(_uploadTasks[index].snapshot.ref);
          },
          onDownload: () {
            if (kIsWeb) {
              return _downloadFile(_uploadTasks[index].snapshot.ref);
            } else {
              return _downloadFile(_uploadTasks[index].snapshot.ref);
            }
          },
        ),
      ),
    );
  }
}

/// Displays the current state of a single UploadTask.
class UploadTaskListTile extends StatelessWidget {
  // ignore: public_member_api_docs
  const UploadTaskListTile({
    Key key,
    this.task,
    this.onDismissed,
    this.onDownload,
    this.onDownloadLink,
  }) : super(key: key);

  final firebase_storage.UploadTask /*!*/ task;

  final VoidCallback /*!*/ onDismissed;

  final VoidCallback /*!*/ onDownload;

  final VoidCallback /*!*/ onDownloadLink;

  String _bytesTransferred(firebase_storage.TaskSnapshot snapshot) {
  //  return '${snapshot.bytesTransferred}/${snapshot.totalBytes}';

    var kilobyte = 1024;
    var megabyte = kilobyte * 1024;
    var gigabyte = megabyte * 1024;
    var terabyte = gigabyte * 1024;
    var transfer = snapshot.bytesTransferred;
    var bytes = snapshot.totalBytes;


    if ((bytes >= 0) && (bytes < kilobyte)) {
      return '$transfer/${snapshot.totalBytes} B';

    } else if ((bytes >= kilobyte) && (bytes < megabyte)) {
      return '${transfer / kilobyte}/${snapshot.totalBytes/ kilobyte} KB';

    } else if ((bytes >= megabyte) && (bytes < gigabyte)) {
      return '${transfer / megabyte}/${snapshot.totalBytes/ megabyte} MB';

    } else if ((bytes >= gigabyte) && (bytes < terabyte)) {
      return '${transfer / gigabyte}/${snapshot.totalBytes/ gigabyte} GB';

    } else if (bytes >= terabyte) {
      return '${transfer / terabyte}/${snapshot.totalBytes/ terabyte} TB';
    } else {
      return '$transfer Bytes';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_storage.TaskSnapshot>(
      stream: task.snapshotEvents,
      builder: (
          BuildContext context,
          AsyncSnapshot<firebase_storage.TaskSnapshot> asyncSnapshot,
          ) {
        Widget subtitle = const Text('---');
        firebase_storage.TaskSnapshot snapshot = asyncSnapshot.data;
        firebase_storage.TaskState state = snapshot?.state;

        if (asyncSnapshot.hasError) {
          if (asyncSnapshot.error is firebase_core.FirebaseException &&
              (asyncSnapshot.error as firebase_core.FirebaseException).code ==
                  'canceled') {
            subtitle = const Text('Upload canceled.');
          } else {
            // ignore: avoid_print
            print(asyncSnapshot.error);
            subtitle = const Text('Something went wrong.');
          }
        } else if (snapshot != null) {
          subtitle = Text('$state: ${_bytesTransferred(snapshot)} bytes sent');
        }

        return Dismissible(
          key: Key(task.hashCode.toString()),
          onDismissed: ($) => onDismissed(),
          child: ListTile(
            title: Text('Upload Task #${task.hashCode}'),
            subtitle: subtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (state == firebase_storage.TaskState.running)
                  IconButton(
                    icon: const Icon(Icons.pause), onPressed: task.pause,
                  ),
                if (state == firebase_storage.TaskState.running)
                  IconButton(
                    icon: const Icon(Icons.cancel), onPressed: task.cancel,
                  ),
                if (state == firebase_storage.TaskState.paused)
                  IconButton(
                    icon: const Icon(Icons.file_upload), onPressed: task.resume,
                  ),
                if (state == firebase_storage.TaskState.success)
                  IconButton(
                    icon: const Icon(Icons.file_download), onPressed: onDownload,
                  ),
                if (state == firebase_storage.TaskState.success)
                  IconButton(
                    icon: const Icon(Icons.link), onPressed: onDownloadLink,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}









