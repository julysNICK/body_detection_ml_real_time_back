import 'dart:math';

import 'package:body_detection_ml_real_time_back/vectortest.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(
        title: 'screen',
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  dynamic controller;
  bool isBusy = false;
  String shouldersY = '';
  String hipY = '';
  String angleX = '';
  String hipYMultiplier2 = '';
  String shouldersYMultiplier2 = '';
  String inRelationX = '';
  String inRelationY = '';
  String inRelationZ = '';
  bool makingUForwards = false;
  bool makingUBackwards = false;
  late Size size;
  bool isPostureCorrect = false;
  late CameraDescription description = cameras[0];
  CameraLensDirection camDirec = CameraLensDirection.back;
  dynamic poseDetector;
  List<Pose> poses = [];
  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  //TODO code to initialize the camera feed
  initializeCamera() async {
    //TODO initialize detector
    final options = PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
    );
    poseDetector = PoseDetector(options: options);

    controller = CameraController(description, ResolutionPreset.low);
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller.startImageStream((image) => {
            if (!isBusy) {isBusy = true, img = image, doPoseDetectionOnFrame()}
          });
    });
  }

  //close all resources
  @override
  void dispose() {
    controller?.dispose();
    poseDetector.close();
    super.dispose();
  }

  //TODO face detection on a frame
  dynamic _scanResults;
  CameraImage? img;
  doPoseDetectionOnFrame() async {
    print("doPoseDetectionOnFrame");
    var frameImg = getInputImage();
    print("frameImg = $frameImg");
    poses = await poseDetector.processImage(frameImg);
    print(poses.length);
    for (Pose pose in poses) {
      // to access all landmarks
      pose.landmarks.forEach((_, landmark) {
        final type = landmark.type;
        final x = landmark.x;
        final y = landmark.y;
        print("type = $type, x = $x, y = $y");
      });

      // to access specific landmarks
      final landmark = pose.landmarks[PoseLandmarkType.nose];
      final eyeLeft = pose.landmarks[PoseLandmarkType.leftEye];
      final eyeRight = pose.landmarks[PoseLandmarkType.rightEye];
      print(eyeLeft?.x);
      print(eyeRight?.x);
      print(landmark?.x);
    }
    // print("faces present = ${faces.length}");

    // checkSpinePosture();
    if (poses.isNotEmpty) {
      calculationInclinationZ(poses[0]);
      calculationInclinationX(poses[0]);
      calculationInclinationY(poses[0]);
      setState(() {
        makingUForwards = checkInIfCOlumnIsMakingUForward();
        makingUBackwards = checkInIfCOlumnIsMakingUBackward();
      });
    }
    checkAnglePosture();

    setState(() {
      _scanResults = poses;
      isBusy = false;
    });
  }

  InputImage getInputImage() {
    print("chamei");
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in img!.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    final Size imageSize = Size(img!.width.toDouble(), img!.height.toDouble());
    final camera = description;
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    // if (imageRotation == null) return;

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(img!.format.raw);
    // if (inputImageFormat == null) return null;

    final planeData = img!.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation!,
      inputImageFormat: inputImageFormat!,
      planeData: planeData,
    );
    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

    return inputImage;
  }

  //Show rectangles around detected faces
  Widget buildResult() {
    if (_scanResults == null ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Text('');
    }

    final Size imageSize = Size(
      controller.value.previewSize!.height,
      controller.value.previewSize!.width,
    );
    CustomPainter painter = PosePainter(imageSize, _scanResults, camDirec);
    return CustomPaint(
      painter: painter,
    );
  }

  double calculationInclinationY(Pose pose) {
    final leftShoulderInclination =
        pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulderInclination =
        pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHipInclination = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHipInclination = pose.landmarks[PoseLandmarkType.rightHip];

    final shoulderHeightInclination =
        (leftShoulderInclination!.y + rightShoulderInclination!.y) / 2;

    final hipHeightInclination =
        (leftHipInclination!.y + rightHipInclination!.y) / 2;

    final inclination = shoulderHeightInclination - hipHeightInclination;
    setState(() {
      inRelationY = inclination.toStringAsFixed(2);
    });
    return inclination;
  }

  double calculationInclinationX(Pose pose) {
    final leftShoulderInclination =
        pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulderInclination =
        pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHipInclination = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHipInclination = pose.landmarks[PoseLandmarkType.rightHip];

    final shoulderHeightInclination =
        (leftShoulderInclination!.x + rightShoulderInclination!.x) / 2;

    final hipHeightInclination =
        (leftHipInclination!.x + rightHipInclination!.x) / 2;

    final inclination = shoulderHeightInclination - hipHeightInclination;

    setState(() {
      inRelationX = inclination.toStringAsFixed(2);
    });

    return inclination;
  }

  bool checkInIfCOlumnIsMakingUForward() {
    if (poses.isEmpty) return false;
    dynamic rightShoulder = poses[0].landmarks[PoseLandmarkType.rightShoulder];
    dynamic leftShoulder = poses[0].landmarks[PoseLandmarkType.leftShoulder];
    dynamic rightHip = poses[0].landmarks[PoseLandmarkType.rightHip];
    dynamic leftHip = poses[0].landmarks[PoseLandmarkType.leftHip];

    if (rightShoulder != null &&
        leftShoulder != null &&
        rightHip != null &&
        leftHip != null) {
      if (rightShoulder.x > rightHip.x && leftShoulder.x < leftHip.x) {
        return true;
      }
    }
    return false;
  }

  bool checkInIfCOlumnIsMakingUBackward() {
    if (poses.isEmpty) return false;
    dynamic rightShoulder = poses[0].landmarks[PoseLandmarkType.rightShoulder];
    dynamic leftShoulder = poses[0].landmarks[PoseLandmarkType.leftShoulder];
    dynamic rightHip = poses[0].landmarks[PoseLandmarkType.rightHip];
    dynamic leftHip = poses[0].landmarks[PoseLandmarkType.leftHip];

    if (rightShoulder != null &&
        leftShoulder != null &&
        rightHip != null &&
        leftHip != null) {
      if (rightShoulder.x < rightHip.x && leftShoulder.x > leftHip.x) {
        return true;
      }
    }
    return false;
  }

  double calculationInclinationZ(Pose pose) {
    final angleZ = PoseInclinationCalculatorZ();

    setState(() {
      inRelationZ = angleZ.calculationInclinationZEi(pose).toStringAsFixed(2);
    });
    return angleZ.calculationInclinationZEi(pose);
  }

  // checkingBackPosture() {
  //   if (poses.isEmpty) return;
  //   dynamic rightShoulder = poses[0].landmarks[PoseLandmarkType.rightShoulder];
  //   dynamic leftShoulder = poses[0].landmarks[PoseLandmarkType.leftShoulder];
  //   dynamic rightHip = poses[0].landmarks[PoseLandmarkType.rightHip];
  //   dynamic leftHip = poses[0].landmarks[PoseLandmarkType.leftHip];

  //   if (rightShoulder != null &&
  //       leftShoulder != null &&
  //       rightHip != null &&
  //       leftHip != null) {
  //     if (rightShoulder.x > rightHip.x && leftShoulder.x < leftHip.x) {
  //       print("Postura correta");

  //       setState(() {
  //         isPostureCorrect = true;
  //       });
  //     } else {
  //       print("Postura incorreta");

  //       setState(() {
  //         isPostureCorrect = false;
  //       });
  //     }
  //   }
  // }

  // void checkSpinePosture() {
  //   if (poses.isEmpty) return;

  //   dynamic rightShoulder = poses[0].landmarks[PoseLandmarkType.rightShoulder];
  //   dynamic leftShoulder = poses[0].landmarks[PoseLandmarkType.leftShoulder];
  //   dynamic rightHip = poses[0].landmarks[PoseLandmarkType.rightHip];
  //   dynamic leftHip = poses[0].landmarks[PoseLandmarkType.leftHip];

  //   if (rightShoulder != null &&
  //       leftShoulder != null &&
  //       rightHip != null &&
  //       leftHip != null) {
  //     final double shoulderHeight = (rightShoulder.y - leftShoulder.y) / 2;
  //     final double hipHeight = (rightHip.y - leftHip.y) / 2;

  //     if (shoulderHeight > hipHeight * 1.2) {
  //       print("Postura correta");
  //       setState(() {
  //         isPostureCorrect = true;
  //         shouldersY = shoulderHeight.toStringAsFixed(2);
  //         hipY = hipHeight.toStringAsFixed(2);
  //         shouldersYMultiplier2 = (shoulderHeight * 1.2).toStringAsFixed(2);
  //         hipYMultiplier2 = (hipHeight * 1.2).toStringAsFixed(2);
  //       });
  //     } else {
  //       print("Postura incorreta");
  //       setState(() {
  //         isPostureCorrect = false;
  //         shouldersY = shoulderHeight.toStringAsFixed(2);
  //         hipY = hipHeight.toStringAsFixed(2);
  //         shouldersYMultiplier2 = (shoulderHeight * 1.2).toStringAsFixed(2);
  //         hipYMultiplier2 = (hipHeight * 1.2).toStringAsFixed(2);
  //       });
  //     }
  //   }
  // }

  void checkAnglePosture() {
    if (poses.isEmpty) return;

    dynamic rightShoulder = poses[0].landmarks[PoseLandmarkType.rightShoulder];
    dynamic leftShoulder = poses[0].landmarks[PoseLandmarkType.leftShoulder];
    dynamic rightHip = poses[0].landmarks[PoseLandmarkType.rightHip];
    dynamic leftHip = poses[0].landmarks[PoseLandmarkType.leftHip];

    if (rightShoulder != null &&
        leftShoulder != null &&
        rightHip != null &&
        leftHip != null) {
      final double shoulderYAngle = (rightShoulder.y + leftShoulder.y) / 2;
      final double hipsYAngle = (rightHip.y + leftHip.y) / 2;

      final double verticalAngle = shoulderYAngle - hipsYAngle;

      double spinalX = (leftShoulder.x + rightShoulder.x) / 2;

      double angle = atan(verticalAngle / spinalX);

      setState(() {
        angleX = angle.toStringAsFixed(2); //angle in radians
      });
    }
  }

  // checkingBackPostureGround() {
  //   if (poses.isEmpty) return;
  //   dynamic rightShoulder = poses[0].landmarks[PoseLandmarkType.rightShoulder];
  //   dynamic leftShoulder = poses[0].landmarks[PoseLandmarkType.leftShoulder];
  //   dynamic rightHip = poses[0].landmarks[PoseLandmarkType.rightHip];
  //   dynamic leftHip = poses[0].landmarks[PoseLandmarkType.leftHip];

  //   dynamic slope =
  //       (rightShoulder.y - leftShoulder.y) / (rightShoulder.x - leftShoulder.x);

  //   if (slope > 0.5) {
  //     print("Postura correta");
  //     setState(() {
  //       isPostureCorrect = true;
  //     });
  //   } else {
  //     print("Postura incorreta");
  //     setState(() {
  //       isPostureCorrect = false;
  //     });
  //   }
  // }

  //toggle camera direction
  void _toggleCameraDirection() async {
    if (camDirec == CameraLensDirection.back) {
      print("if");
      camDirec = CameraLensDirection.front;
      description = cameras[1];
    } else {
      print("else");
      camDirec = CameraLensDirection.back;
      description = cameras[0];
    }

    // await controller.dispose();
    // controller = null;
    setState(() {
      controller;
    });

    initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    size = MediaQuery.of(context).size;
    if (controller != null) {
      stackChildren.add(
        Positioned(
          top: 0.0,
          left: 0.0,
          width: size.width,
          height: size.height - 230,
          child: Container(
            child: (controller.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  )
                : Container(),
          ),
        ),
      );
      stackChildren.add(
        Positioned(
            top: 0.0,
            left: 0.0,
            width: size.width,
            height: size.height - 230,
            child: buildResult()),
      );
      String posture = isPostureCorrect ? "Correta" : "Incorreta";
      stackChildren.add(
        Positioned(
          left: size.width / 2 - 190,
          bottom: 80,
          child: Container(
            color: Colors.transparent,
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 80),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          "coluna fazendo um U para frente: $makingUForwards, ",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        )
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          "coluna fazendo um U para trás: $makingUBackwards, ",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        )
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          "em relação a y: $inRelationY!!!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          "em relação a x: $inRelationX!!!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          "em relação a z: $inRelationZ!!!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    stackChildren.add(Positioned(
      top: size.height - 230,
      left: 0,
      width: size.width,
      height: 230,
      child: Container(
        color: Colors.grey,
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(bottom: 80),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.cached,
                        color: Colors.white,
                      ),
                      iconSize: 50,
                      color: Colors.black,
                      onPressed: () {
                        _toggleCameraDirection();
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Face detector"),
        backgroundColor: Colors.grey,
      ),
      backgroundColor: Colors.black,
      body: Container(
          margin: const EdgeInsets.only(top: 0),
          color: Colors.black,
          child: Stack(
            children: stackChildren,
          )),
    );
  }
}

class PosePainter extends CustomPainter {
  PosePainter(this.absoluteImageSize, this.poses, this.camDire2);

  final Size absoluteImageSize;
  final List<Pose> poses;
  CameraLensDirection camDire2;
  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = size.width / absoluteImageSize.width;
    final double scaleY = size.height / absoluteImageSize.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.green;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blueAccent;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        Offset pointCamBack = Offset(landmark.x * scaleX, landmark.y * scaleY);
        Offset pointCamFront =
            Offset(size.width - landmark.x * scaleX, landmark.y * scaleY);

        if (camDire2 == CameraLensDirection.back) {
          canvas.drawCircle(pointCamBack, 1, paint);
        } else {
          canvas.drawCircle(pointCamFront, 1, paint);
        }

        // canvas.drawCircle(
        //     Offset(landmark.x * scaleX, landmark.y * scaleY), 1, paint);
      });

      void paintLine(
          PoseLandmarkType type1, PoseLandmarkType type2, Paint paintType) {
        final PoseLandmark joint1 = pose.landmarks[type1]!;
        final PoseLandmark joint2 = pose.landmarks[type2]!;

        Offset point1WhenCamBack = Offset(joint1.x * scaleX, joint1.y * scaleY);
        Offset point2WhenCamBack = Offset(joint2.x * scaleX, joint2.y * scaleY);

        Offset point1WhenCamFront =
            Offset(size.width - joint1.x * scaleX, joint1.y * scaleY);
        Offset point2WhenCamFront =
            Offset(size.width - joint2.x * scaleX, joint2.y * scaleY);

        // canvas.drawLine(Offset(joint1.x * scaleX, joint1.y * scaleY),
        //     Offset(joint2.x * scaleX, joint2.y * scaleY), paintType);

        Offset point1 = camDire2 == CameraLensDirection.front
            ? point1WhenCamFront
            : point1WhenCamBack;
        Offset point2 = camDire2 == CameraLensDirection.front
            ? point2WhenCamFront
            : point2WhenCamBack;

        canvas.drawLine(point1, point2, paintType);
      }

      //Draw arms
      paintLine(
          PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(
          PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow,
          rightPaint);
      paintLine(
          PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      //Draw Body
      paintLine(
          PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip,
          rightPaint);

      //Draw legs
      paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      paintLine(
          PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      paintLine(
          PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      paintLine(
          PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
    }
  }

  @override
  bool shouldRepaint(PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.poses != poses;
  }
}
