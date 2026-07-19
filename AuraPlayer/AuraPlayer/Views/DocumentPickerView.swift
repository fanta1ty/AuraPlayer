//
//  DocumentPickerView.swift
//  AuraPlayer
//
//  SwiftUI wrapper around UIDocumentPickerViewController for importing audio.
//  Uses asCopy: true so we get sandbox-local temp copies to move into Documents.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {

    var onPick: ([URL]) -> Void

    /// Broad audio coverage: the generic `.audio` type plus explicit
    /// entries for formats that don't always conform to it (FLAC, DSD…).
    private static var supportedTypes: [UTType] {
        var types: [UTType] = [.audio, .mp3, .wav, .aiff, .mpeg4Audio]
        for ext in ["flac", "alac", "aac", "ogg", "dsf", "dff"] {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: Self.supportedTypes,
            asCopy: true
        )
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick([])
        }
    }
}
