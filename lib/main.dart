import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const Map<String, Map<String, String>> localizedStrings = {
  'en': {
    'title': 'YouTube Downloader',
    'appBarTitle': 'YT Downloader',
    'enterUrl': 'YouTube Video ID or URL',
    'mp4': 'MP4 Video',
    'mp3': 'MP3 Audio',
    'download': 'Download',
    'downloading': 'Downloading... ',
    'downloadComplete': 'Download Complete',
    'location': 'Location: YTDownloader folder',
    'cancel': 'Cancel',
    'selectQuality': 'Select Video Quality',
    'error': 'Error',
    'downloadFailed': 'Download failed',
    'downloadCancelled': 'Download Cancelled',
    'stopped': 'The download has been stopped',
    'savedAs': 'Saved as: ',
    'open': 'Open',
  },
  'ar': {
    'title': 'تنزيل يوتيوب',
    'appBarTitle': 'تنزيل يوتيوب',
    'enterUrl': 'معرّف الفيديو أو الرابط',
    'mp4': 'فيديو MP4',
    'mp3': 'صوت MP3',
    'download': 'تنزيل',
    'downloading': 'جارٍ التنزيل... ',
    'downloadComplete': 'اكتمل التنزيل',
    'location': 'المكان: مجلد YTDownloader',
    'cancel': 'إلغاء',
    'selectQuality': 'اختر جودة الفيديو',
    'error': 'خطأ',
    'downloadFailed': 'فشل التنزيل',
    'downloadCancelled': 'تم إلغاء التنزيل',
    'stopped': 'تم إيقاف التنزيل',
    'savedAs': 'تم الحفظ باسم: ',
    'open': 'فتح',
  }
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestInitialPermissions();
  runApp(const MyApp());
}

Future<void> _requestInitialPermissions() async {
  await Permission.storage.request();
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String currentLanguage = 'ar'; // default language is Arabic

  void changeLanguage(String lang) {
    setState(() {
      currentLanguage = lang;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: localizedStrings[currentLanguage]!['title']!,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.red,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Colors.white),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red),
            borderRadius: BorderRadius.circular(15),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.red, width: 2.0),
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
      ),
      locale: Locale(currentLanguage),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      home: DownloadScreen(
        currentLanguage: currentLanguage,
        onLanguageChanged: changeLanguage,
      ),
    );
  }
}

// Custom FloatingActionButtonLocation that always positions the FAB on the right
class AlwaysRightFloatingActionButtonLocation
    extends FloatingActionButtonLocation {
  const AlwaysRightFloatingActionButtonLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabWidth = scaffoldGeometry.floatingActionButtonSize.width;
    final double fabHeight = scaffoldGeometry.floatingActionButtonSize.height;
    final double scaffoldWidth = scaffoldGeometry.scaffoldSize.width;
    final double scaffoldHeight = scaffoldGeometry.scaffoldSize.height;
    const double margin = 16.0;
    final double dx = scaffoldWidth - fabWidth - margin;
    final double dy =
        scaffoldHeight - fabHeight - scaffoldGeometry.minInsets.bottom - margin;
    return Offset(dx, dy);
  }
}

class DownloadScreen extends StatefulWidget {
  final String currentLanguage;
  final Function(String) onLanguageChanged;
  const DownloadScreen({
    Key? key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  }) : super(key: key);
  @override
  _DownloadScreenState createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  double _progress = 0;
  bool _isAudioOnly = false;
  bool _cancelDownload = false;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  late final AppLinks _appLinks;
  StreamSubscription? _appLinksSub;

  static const platform = MethodChannel("com.Hedwig.yt_downloader/share");

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initAppLinks();
    _setupShareListener();
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        setState(() {
          _urlController.text = initialLink.toString();
        });
      }
    } catch (e) {}
    _appLinksSub = _appLinks.uriLinkStream.listen((Uri link) {
      setState(() {
        _urlController.text = link.toString();
      });
    });
  }

  void _setupShareListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == "shareText") {
        String sharedText = call.arguments;
        if (sharedText.isNotEmpty) {
          setState(() {
            _urlController.text = sharedText;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _appLinksSub?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);
  }

  Future<Directory> _getDownloadDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download/YTDownloader');
    } else {
      directory = await getDownloadsDirectory();
      directory = Directory('${directory?.path}/YTDownloader');
    }
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> downloadVideo(String id) async {
    var permission = await Permission.storage.request();
    if (!permission.isGranted) {
      await Permission.storage.request();
      return;
    }
    if (_urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${getLocalized('error')}: ${getLocalized('enterUrl')}')));
      return;
    }
    setState(() {
      _isLoading = true;
      _progress = 0;
      _cancelDownload = false;
    });
    var yt = YoutubeExplode();
    try {
      var video = await yt.videos.get(id);
      var manifest = await yt.videos.streamsClient.getManifest(id);
      StreamInfo? chosenStream;
      bool useAdaptive = false;
      if (!_isAudioOnly) {
        if (manifest.muxed.isNotEmpty) {
          chosenStream =
              await _showQualityDialog(context, manifest.muxed.toList());
        } else {
          chosenStream =
              await _showQualityDialog(context, manifest.videoOnly.toList());
          useAdaptive = true;
        }
        if (chosenStream == null) {
          setState(() {
            _isLoading = false;
            _progress = 0;
          });
          yt.close();
          return;
        }
      }
      Directory directory = await _getDownloadDirectory();
      if (_isAudioOnly) {
        if (manifest.audioOnly.isEmpty) {
          throw Exception(
              '${getLocalized('error')}: No audio streams available');
        }
        var streamInfo = manifest.audioOnly.withHighestBitrate();
        String fileName = '${video.title}.mp3';
        fileName = fileName.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_');
        File file = File('${directory.path}/$fileName');
        if (file.existsSync()) file.deleteSync();
        var output = file.openWrite(mode: FileMode.writeOnlyAppend);
        var stream = yt.videos.streamsClient.get(streamInfo);
        var size = streamInfo.size.totalBytes;
        var count = 0;
        await for (final data in stream) {
          if (_cancelDownload) {
            await output.close();
            if (file.existsSync()) file.deleteSync();
            setState(() {
              _isLoading = false;
              _progress = 0;
            });
            _showNotification(
                getLocalized('downloadCancelled'), getLocalized('stopped'));
            return;
          }
          count += data.length;
          double progressVal = count / size;
          setState(() {
            _progress = progressVal * 100;
          });
          output.add(data);
          _updateProgressNotification(_progress);
        }
        await output.close();
        setState(() {
          _isLoading = false;
          _progress = 0;
        });
        _showSuccessNotification(file);
      } else if (!useAdaptive) {
        MuxedStreamInfo streamInfo = chosenStream as MuxedStreamInfo;
        String fileName = '${video.title}.${streamInfo.container.name}';
        fileName = fileName.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_');
        File file = File('${directory.path}/$fileName');
        if (file.existsSync()) file.deleteSync();
        var output = file.openWrite(mode: FileMode.writeOnlyAppend);
        var stream = yt.videos.streamsClient.get(streamInfo);
        var size = streamInfo.size.totalBytes;
        var count = 0;
        await for (final data in stream) {
          if (_cancelDownload) {
            await output.close();
            if (file.existsSync()) file.deleteSync();
            setState(() {
              _isLoading = false;
              _progress = 0;
            });
            _showNotification(
                getLocalized('downloadCancelled'), getLocalized('stopped'));
            return;
          }
          count += data.length;
          double progressVal = count / size;
          setState(() {
            _progress = progressVal * 100;
          });
          output.add(data);
          _updateProgressNotification(_progress);
        }
        await output.close();
        setState(() {
          _isLoading = false;
          _progress = 0;
        });
        _showSuccessNotification(file);
      } else {
        VideoOnlyStreamInfo videoStreamInfo =
            chosenStream as VideoOnlyStreamInfo;
        if (manifest.audioOnly.isEmpty) {
          throw Exception(
              '${getLocalized('error')}: No audio streams available');
        }
        var audioStreamInfo = manifest.audioOnly.withHighestBitrate();
        String videoTempPath =
            '${directory.path}/temp_video.${videoStreamInfo.container.name}';
        String audioTempPath =
            '${directory.path}/temp_audio.${audioStreamInfo.container.name}';
        File videoFile = File(videoTempPath);
        File audioFile = File(audioTempPath);
        if (videoFile.existsSync()) videoFile.deleteSync();
        if (audioFile.existsSync()) audioFile.deleteSync();
        var videoStream = yt.videos.streamsClient.get(videoStreamInfo);
        int videoSize = videoStreamInfo.size.totalBytes;
        int videoCount = 0;
        var videoOutput = videoFile.openWrite(mode: FileMode.writeOnlyAppend);
        await for (final data in videoStream) {
          if (_cancelDownload) {
            await videoOutput.close();
            if (videoFile.existsSync()) videoFile.deleteSync();
            setState(() {
              _isLoading = false;
              _progress = 0;
            });
            _showNotification(
                getLocalized('downloadCancelled'), getLocalized('stopped'));
            return;
          }
          videoCount += data.length;
          double progressVal = videoCount / videoSize;
          setState(() {
            _progress = progressVal * 50;
          });
          videoOutput.add(data);
          _updateProgressNotification(_progress);
        }
        await videoOutput.close();
        var audioStream = yt.videos.streamsClient.get(audioStreamInfo);
        int audioSize = audioStreamInfo.size.totalBytes;
        int audioCount = 0;
        var audioOutput = audioFile.openWrite(mode: FileMode.writeOnlyAppend);
        await for (final data in audioStream) {
          if (_cancelDownload) {
            await audioOutput.close();
            if (audioFile.existsSync()) audioFile.deleteSync();
            setState(() {
              _isLoading = false;
              _progress = 0;
            });
            _showNotification(
                getLocalized('downloadCancelled'), getLocalized('stopped'));
            return;
          }
          audioCount += data.length;
          double progressVal = audioCount / audioSize;
          setState(() {
            _progress = 50 + progressVal * 50;
          });
          audioOutput.add(data);
          _updateProgressNotification(_progress);
        }
        await audioOutput.close();
        String outputFileName = '${video.title}.mp4';
        outputFileName =
            outputFileName.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_');
        String outputFilePath = '${directory.path}/$outputFileName';
        String ffmpegCommand =
            '-i "$videoTempPath" -i "$audioTempPath" -c copy "$outputFilePath"';
        await FFmpegKit.execute(ffmpegCommand);
        if (videoFile.existsSync()) videoFile.deleteSync();
        if (audioFile.existsSync()) audioFile.deleteSync();
        setState(() {
          _isLoading = false;
          _progress = 0;
        });
        _showSuccessNotification(File(outputFilePath));
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _progress = 0;
      });
      _showNotification(
          getLocalized('error'), '${getLocalized('downloadFailed')}: $e');
    } finally {
      yt.close();
    }
  }

  Future<T?> _showQualityDialog<T extends StreamInfo>(
      BuildContext context, List<T> streams) async {
    List<T> filteredStreams =
        streams.where((s) => s.container.name.toLowerCase() == "mp4").toList();
    if (filteredStreams.isEmpty) {
      filteredStreams = streams;
    }
    final Map<String, T> qualityMap = {};
    for (var stream in filteredStreams) {
      String quality = stream is VideoStreamInfo
          ? stream.videoQuality.toString()
          : "Unknown Quality";
      if (!qualityMap.containsKey(quality)) {
        qualityMap[quality] = stream;
      } else {
        if (stream.size.totalBytes > qualityMap[quality]!.size.totalBytes) {
          qualityMap[quality] = stream;
        }
      }
    }
    List<T> dedupedStreams = qualityMap.values.toList();
    return await showDialog<T>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(getLocalized('selectQuality')),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: dedupedStreams.length,
              itemBuilder: (context, index) {
                final stream = dedupedStreams[index];
                String qualityText = 'Unknown Quality';
                if (stream is VideoStreamInfo) {
                  qualityText = stream.videoQuality.toString();
                }
                return ListTile(
                  title: Text('$qualityText - ${stream.container.name}'),
                  subtitle: Text(
                      '${(stream.size.totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB'),
                  onTap: () {
                    Navigator.pop(context, stream);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(getLocalized('cancel')),
            )
          ],
        );
      },
    );
  }

  Future<void> _updateProgressNotification(double progress) async {
    const channelId = 'downloads';
    const channelName = 'Downloads';
    const channelDescription = 'Download notifications';
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress.toInt(),
      onlyAlertOnce: true,
    );
    await _notifications.show(
      1,
      getLocalized('downloading'),
      'Progress: ${progress.toStringAsFixed(1)}%',
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _showSuccessNotification(File file) async {
    // Cancel the progress notification
    await _notifications.cancel(1);
    const androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Download notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _notifications.show(
      0,
      getLocalized('downloadComplete'),
      '${getLocalized('savedAs')}${file.path.split('/').last}',
      const NotificationDetails(android: androidDetails),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(getLocalized('downloadComplete'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${getLocalized('savedAs')}${file.path.split('/').last}'),
            Text(getLocalized('location')),
          ],
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: getLocalized('open'),
          onPressed: () => OpenFile.open(file.path),
        ),
      ),
    );
    setState(() {
      _urlController.clear();
    });
  }

  void _showNotification(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title: $message'),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _stopDownload() {
    _notifications.cancel(1);
    setState(() {
      _cancelDownload = true;
    });
    _notifications.show(
      0,
      getLocalized('downloadCancelled'),
      getLocalized('stopped'),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'downloads',
          'Downloads',
          channelDescription: 'Download notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  void _onDownloadPressed() async {
    String input = _urlController.text.trim();
    String id = extractVideoId(input);
    await downloadVideo(id);
  }

  String extractVideoId(String input) {
    if (!input.startsWith('http')) return input;
    Uri uri = Uri.parse(input);
    if (uri.host.contains('youtu.be') || uri.host.contains('youtube.be')) {
      return uri.pathSegments.first;
    }
    if (uri.host.contains('youtube.com') ||
        uri.host.contains('m.youtube.com')) {
      return uri.queryParameters['v'] ?? input;
    }
    return input;
  }

  String getLocalized(String key) {
    return localizedStrings[widget.currentLanguage]?[key] ?? key;
  }

  void _showLanguageSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('English'),
                onTap: () {
                  widget.onLanguageChanged('en');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('العربية'),
                onTap: () {
                  widget.onLanguageChanged('ar');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(getLocalized('appBarTitle')),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Colors.red.shade900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: getLocalized('enterUrl'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                  prefixIcon: const Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(getLocalized('mp4')),
                      value: false,
                      groupValue: _isAudioOnly,
                      onChanged: (value) =>
                          setState(() => _isAudioOnly = value!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text(getLocalized('mp3')),
                      value: true,
                      groupValue: _isAudioOnly,
                      onChanged: (value) =>
                          setState(() => _isAudioOnly = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: _isLoading
                    ? const CircularProgressIndicator()
                    : Icon(_isAudioOnly ? Icons.audio_file : Icons.videocam),
                label: Text(
                  _isLoading
                      ? '${getLocalized('downloading')} (${_progress.toStringAsFixed(1)}%)'
                      : getLocalized('download'),
                  style: const TextStyle(fontSize: 16),
                ),
                onPressed: _isLoading ? null : _onDownloadPressed,
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: Text(getLocalized('cancel')),
                    onPressed: _stopDownload,
                  ),
                ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: LinearProgressIndicator(
                    value: _progress / 100,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showLanguageSelection,
        child: const Icon(Icons.language),
      ),
      floatingActionButtonLocation:
          const AlwaysRightFloatingActionButtonLocation(),
    );
  }
}
