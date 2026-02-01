//
//  VideoPicker.swift
//  Eloquence
//

import SwiftUI
import PhotosUI

struct VideoPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, dismiss: dismiss)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (URL) -> Void
        let dismiss: DismissAction

        init(onPick: @escaping (URL) -> Void, dismiss: DismissAction) {
            self.onPick = onPick
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier("public.movie") else {
                dismiss()
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: "public.movie") { url, error in
                guard let url = url else {
                    DispatchQueue.main.async { self.dismiss() }
                    return
                }

                let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let timestamp = Int(Date().timeIntervalSince1970)
                let destURL = documentsDir.appendingPathComponent("practice_\(timestamp).mov")

                do {
                    try FileManager.default.copyItem(at: url, to: destURL)
                    DispatchQueue.main.async {
                        self.onPick(destURL)
                        self.dismiss()
                    }
                } catch {
                    print("Failed to copy video: \(error)")
                    DispatchQueue.main.async { self.dismiss() }
                }
            }
        }
    }
}
