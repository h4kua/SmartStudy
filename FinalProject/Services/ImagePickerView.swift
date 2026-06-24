import SwiftUI
import UIKit

/// Reusable UIImagePickerController wrapper for SwiftUI.
/// Supports both camera capture and photo library selection.
/// Used by DocumentAnalyzerView (note scanning) and AITutorView (equation solving).
struct ImagePickerView: UIViewControllerRepresentable {

    let sourceType: UIImagePickerController.SourceType
    let onPick:     (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker         = UIImagePickerController()
        picker.sourceType  = sourceType
        picker.delegate    = context.coordinator
        picker.allowsEditing = false
        // Better quality for OCR
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject,
                              UIImagePickerControllerDelegate,
                              UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onPick(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
