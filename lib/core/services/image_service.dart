import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  static Future<String?> pickCropAndSave() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recadrer',
          lockAspectRatio: true,
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.square,
          cropStyle: CropStyle.rectangle,
        ),
      ],
    );
    if (cropped == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(dir.path, 'covers'));
    if (!await coversDir.exists()) await coversDir.create(recursive: true);

    final dest = p.join(coversDir.path, '${const Uuid().v4()}.jpg');
    await File(cropped.path).copy(dest);
    return dest;
  }
}
