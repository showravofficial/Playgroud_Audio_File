import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USB Drive Audio Files',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: UsbFilePicker(),
    );
  }
}

class UsbFilePicker extends StatefulWidget {
  @override
  _UsbFilePickerState createState() => _UsbFilePickerState();
}

class _UsbFilePickerState extends State<UsbFilePicker> {
  static const platform = MethodChannel('usb_path_reader/usb');
  String? _selectedPath = '/RECORD';
  String? _usbPath;
  List<String> _audioFiles = [];
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentPlayingFile;
  bool _isUsbConnected = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    if (_selectedPath != null) {
      _listAudioFiles(_selectedPath!);
    }
    _checkUsbConnection();
    _startUsbConnectionCheck();
  }

  void _startUsbConnectionCheck() {
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      _checkUsbConnection();
    });
  }

  void _checkUsbConnection() async {
    try {
      String? usbPath = await platform.invokeMethod('getUsbPath');
      setState(() {
        _usbPath = usbPath;
        _isUsbConnected = usbPath != null;
      });
    } on PlatformException catch (e) {
      print("Failed to get USB path: '${e.message}'");
    }
  }

  Future<void> _requestPermissions() async {
    if (await Permission.storage.request().isDenied) {
      print("Storage permission denied!");
    }

    if (Platform.isAndroid && await Permission.manageExternalStorage.isDenied) {
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        print("Manage External Storage permission denied!");
      }
    }
  }

  void _listAudioFiles(String path) async {
    try {
      final directory = Directory(path);
      if (await directory.exists()) {
        final files = directory.listSync();
        final audioFiles = files.where((file) {
          final extension = file.path.split('.').last.toLowerCase();
          return ['mp3', 'wav', 'aac'].contains(extension);
        }).map((file) => file.path).toList();

        setState(() {
          _audioFiles = audioFiles;
        });

        print('Audio Files Found: ${audioFiles.length}');
      } else {
        print('Directory does not exist: $path');
      }
    } catch (e) {
      print('Error listing files: $e');
    }
  }

  void _copyPathToClipboard() {
    if (_selectedPath != null) {
      Clipboard.setData(ClipboardData(text: _selectedPath!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Path copied to clipboard: $_selectedPath')),
      );
    }
  }

  Future<void> _playPauseAudio(String filePath) async {
    if (_isPlaying && _currentPlayingFile == filePath) {
      await _audioPlayer.pause();
      setState(() {
        _isPlaying = false;
      });
    } else {
      await _audioPlayer.play(DeviceFileSource(filePath));
      setState(() {
        _isPlaying = true;
        _currentPlayingFile = filePath;
      });
    }
  }

  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String combinedPath = '$_usbPath$_selectedPath';

    return Scaffold(
      appBar: AppBar(title: Text('USB Drive Audio Files')),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            color: _isUsbConnected ? Colors.green : Colors.red,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: _isUsbConnected ? Colors.green : Colors.red,
                ),
                SizedBox(width: 10),
                Text(
                  _isUsbConnected
                      ? 'USB Device Connected'
                      : 'USB Device Not Connected',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.lightBlueAccent,
            child: Row(
              children: [
                Expanded(child: Text('Selected Path: $combinedPath')),
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: _copyPathToClipboard,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(10),
            color: Colors.orangeAccent,
            child: Text('Current USB Path: $_usbPath'),
          ),
          if (_usbPath != null)
            ElevatedButton(
              onPressed: () => _listAudioFiles(combinedPath),
              child: Text('Refresh Audio Files'),
            ),
          Expanded(
            child: _audioFiles.isEmpty
                ? Center(child: Text('No audio files found.'))
                : ListView.builder(
                    itemCount: _audioFiles.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_audioFiles[index].split('/').last),
                        subtitle: Text(_audioFiles[index]),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(_isPlaying &&
                                      _currentPlayingFile == _audioFiles[index]
                                  ? Icons.pause
                                  : Icons.play_arrow),
                              onPressed: () {
                                _playPauseAudio(_audioFiles[index]);
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.stop),
                              onPressed: _stopAudio,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
