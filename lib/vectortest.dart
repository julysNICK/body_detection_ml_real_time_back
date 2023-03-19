import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:vector_math/vector_math_64.dart';

class PoseInclinationCalculatorZ {
  double calculationInclinationZEi(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder]!;
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder]!;
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip]!;
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip]!;

    final shoulderVector = Vector3(leftShoulder.z, leftShoulder.y, 0);
    final hipVector = Vector3(leftHip.z, leftHip.y, 0);

    final shoulderHipVector = shoulderVector - hipVector;

    final referenceVector = Vector3(0, 1, 0);

    final angle = shoulderHipVector.angleTo(referenceVector);

    return angle;
  }
}
