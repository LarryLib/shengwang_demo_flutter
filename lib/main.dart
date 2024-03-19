import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(MyApp());

// 填写项目的 App ID，可在声网控制台中生成
const appId = "d6da9a22cf2c4307a363035a092ad11f";
// 填写声网控制台中生成的临时 Token
const token = "007eJxTYLDyVsmLuGfLoPL6xfZj0Tfnbt9VMFXX9U5txNujL5c92TVfgSHFLCXRMtHIKDnNKNnE2MA80djM2MDYNNHA0igxxdAwrcDuZ2pDICND6XIVFkYGCATxORkMjYxNTM3MLSwZGACGwSGs";
// 填写频道名
const channel = "123456789";

// 应用类
class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

// 应用状态类
class _MyAppState extends State<MyApp> {
  int? _remoteUid; // 用于存储远端用户的 uid
  bool _localUserJoined = false; // 表示本地用户是否加入频道，初始值为 false
  late RtcEngine _engine; // 用于存储 RtcEngine 实例

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> initAgora() async {
    // 获取麦克风和摄像头权限
    await [Permission.microphone, Permission.camera].request();

    // 创建 RtcEngine 对象
    _engine = await createAgoraRtcEngine();

    // 初始化 RtcEngine，设置频道场景为直播场景
    await _engine.initialize(const RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    // 添加回调事件
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        // 成功加入频道回调
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
          setState(() {
            _localUserJoined = true;
          });
        },
        // 远端用户加入频道回调
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        // 远端用户离开频道回调
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left channel");
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );
    // 启用视频模块
    await _engine.enableVideo();
    // 开启本地预览
    await _engine.startPreview();
    // 加入频道
    await _engine.joinChannel(
      token: token,
      channelId: channel,
      options: const ChannelMediaOptions(
        // 设置用户角色为主播
        // 如果要将用户角色设置为观众，则修改 clientRoleBroadcaster 为 clientRoleAudience
          clientRoleType: ClientRoleType.clientRoleBroadcaster),
      uid: 0,
    );
  }

  @override
  void dispose() {
    super.dispose();
    _dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel(); // 离开频道
    await _engine.release(); // 释放资源
  }

  // 构建 UI，显示本地视图和远端视图
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Agora Video Call'),
        ),
        body: Stack(
          children: [
            Center(
              child: _remoteVideo(),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 100,
                height: 150,
                child: Center(
                  child: _localUserJoined
                      ? AgoraVideoView(
                    controller: VideoViewController(
                      rtcEngine: _engine,
                      canvas: const VideoCanvas(uid: 0),
                    ),
                  )
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 生成远端视频
  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: const RtcConnection(channelId: channel),
        ),
      );
    } else {
      return const Text(
        'Please wait for remote user to join',
        textAlign: TextAlign.center,
      );
    }
  }
}
