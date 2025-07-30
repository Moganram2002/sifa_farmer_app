import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'take_selfie.dart'; 

class ProfilePicturePicker extends StatefulWidget {
  final void Function(File file)? onImageSelected;
  final void Function(Uint8List imageBytes)? onWebImageSelected;

  const ProfilePicturePicker({
    super.key,
    this.onImageSelected,
    this.onWebImageSelected,
  });

  @override
  State<ProfilePicturePicker> createState() => _ProfilePicturePickerState();
}

class _ProfilePicturePickerState extends State<ProfilePicturePicker> {
  final CropController _cropController = CropController();
  Uint8List? _webImageBytes;
  File? _pickedFile;
  bool _showCropper = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
          _showCropper = true;
        });
      } else {
        final file = File(pickedFile.path);
        setState(() {
          _pickedFile = file;
          _showCropper = true;
        });
      }
    }
  }

  void _onCropped(Uint8List croppedData) {
    if (kIsWeb) {
      widget.onWebImageSelected?.call(croppedData);
      setState(() {
        _webImageBytes = croppedData;
        _showCropper = false;
      });
    } else {
     
      widget.onWebImageSelected?.call(croppedData); 
      setState(() {
        _showCropper = false;
      });
    }
  }

  Widget _imagePreview() {
    
    return const SizedBox.shrink(); 
  }

  @override
  Widget build(BuildContext context) {

    if (_showCropper && (kIsWeb ? _webImageBytes != null : _pickedFile != null)) {
      return Column(
        children: [
          SizedBox(
            height: 300,
            child: Crop(
              controller: _cropController,
              image: kIsWeb
                  ? _webImageBytes!
                  : File(_pickedFile!.path).readAsBytesSync(),
              onCropped: _onCropped,
              initialSize: 0.8,
              baseColor: Colors.white,
              maskColor: Colors.black.withOpacity(0.4),
              cornerDotBuilder: (size, edgeAlignment) =>
                  const DotControl(color: Colors.orange),
            ),
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() => _showCropper = false),
                child: const Text("Cancel",style: TextStyle(color: Color.fromARGB(255, 101, 156, 98))),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _cropController.crop(),
                child: const Text("Crop & Use",style: TextStyle(color: Color.fromARGB(255, 101, 156, 98))),
              ),
            ],
          )
        ],
      );
    }
    
  
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.upload_file,color: Color.fromARGB(255, 130, 136, 129)),
              label: const Text('Upload',style: TextStyle(color: Color.fromARGB(255, 101, 156, 98))),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () {
                if (kIsWeb) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Take a Selfie",style: TextStyle(color: Color.fromARGB(255, 101, 156, 98))),
                      content: SizedBox(
                        width: 400,
                        height: 500,
                        child: TakeSelfieWebWidget(
                          onCropped: (croppedBytes) {
                            
                            widget.onWebImageSelected?.call(croppedBytes);
                            setState(() {
                              _webImageBytes = croppedBytes;
                              _showCropper = false;
                            });
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ),
                  );
                } else {
                  _pickImage(ImageSource.camera,);
                }
              },
              icon: const Icon(Icons.camera_alt,color: Color.fromARGB(255, 123, 131, 122)),
              label: const Text('Take Selfie',style: TextStyle(color: Color.fromARGB(255, 101, 156, 98))),
            ),
          ],
        ),
      ],
    );
  }
}
