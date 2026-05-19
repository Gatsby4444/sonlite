import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  /// Ouvre la galerie photo système (Google Photos, etc.)
  static Future<String?> pickCropAndSave() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;
    return _cropAndSave(picked.path);
  }

  /// Ouvre le gestionnaire de fichiers pour choisir n'importe quel fichier image
  static Future<String?> pickCropAndSaveFromFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return _cropAndSave(path);
  }

  static Future<String?> _cropAndSave(String sourcePath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
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
