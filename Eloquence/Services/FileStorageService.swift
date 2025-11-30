//
//  FileStorageService.swift
//  Eloquence
//
//  Manages file storage for large assets (images, videos) to avoid bloating UserDefaults.
//

import Foundation

class FileStorageService {
    static let shared = FileStorageService()
    
    private let fileManager = FileManager.default
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var imagesDirectory: URL {
        let url = documentsDirectory.appendingPathComponent("KeyFrameImages")
        if !fileManager.fileExists(atPath: url.path) {
            try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
    
    /// Saves image data to disk and returns the relative path
    func saveImage(_ data: Data, id: UUID) -> String? {
        let fileName = "\(id.uuidString).jpg"
        let fileURL = imagesDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return "KeyFrameImages/\(fileName)"
        } catch {
            print("❌ [FileStorage] Failed to save image: \(error)")
            return nil
        }
    }
    
    /// Loads image data from relative path
    func loadImage(path: String) -> Data? {
        let fileURL = documentsDirectory.appendingPathComponent(path)
        
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("❌ [FileStorage] Failed to load image from \(path): \(error)")
            return nil
        }
    }
    
    /// Deletes image file
    func deleteImage(path: String) {
        let fileURL = documentsDirectory.appendingPathComponent(path)
        try? fileManager.removeItem(at: fileURL)
    }
}
