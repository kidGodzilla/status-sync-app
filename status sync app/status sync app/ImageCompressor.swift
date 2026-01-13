//
//  ImageCompressor.swift
//  status sync app
//
//  Created by James Futhey on 1/14/26.
//

import Foundation
import AppKit

func compressAvatar(_ imageData: Data, maxDimension: CGFloat = 200, maxSizeKB: Int = 50) -> Data? {
    guard let image = NSImage(data: imageData) else { return nil }
    
    // Get the original size
    let size = image.size
    let maxSize = max(size.width, size.height)
    
    // Calculate new size if needed
    let newSize: NSSize
    if maxSize > maxDimension {
        let scale = maxDimension / maxSize
        newSize = NSSize(width: size.width * scale, height: size.height * scale)
    } else {
        newSize = size
    }
    
    // Resize the image
    let resizedImage = NSImage(size: newSize)
    resizedImage.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
    resizedImage.unlockFocus()
    
    // Convert to JPEG with compression
    guard let tiffData = resizedImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return nil
    }
    
    // Try different compression levels until we're under maxSizeKB
    var quality: CGFloat = 0.9
    var compressedData: Data?
    
    while quality > 0.1 {
        if let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) {
            let sizeKB = data.count / 1024
            if sizeKB <= maxSizeKB {
                compressedData = data
                break
            }
        }
        quality -= 0.1
    }
    
    return compressedData ?? bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.5])
}
