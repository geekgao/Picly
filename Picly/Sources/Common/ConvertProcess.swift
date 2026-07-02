//
//  ConvertProcess.swift
//  Picly
//

import Foundation

enum ImageExportFormat: String, CaseIterable {
    case jpeg = "JPEG / JPG"
    case png  = "PNG"
    case bmp  = "BMP"
    case gif  = "GIF"
    case tiff = "TIFF"
    case tga  = "TGA"
    case ico  = "ICO"
    case sgi  = "SGI"
    case pcx  = "PCX"
    case ppm  = "PPM"
    case pgm  = "PGM"
    case pbm  = "PBM"
    case pam  = "PAM"
    case webp = "WebP"
    case jp2  = "JPEG 2000"

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png:  return "png"
        case .bmp:  return "bmp"
        case .gif:  return "gif"
        case .tiff: return "tiff"
        case .tga:  return "tga"
        case .ico:  return "ico"
        case .sgi:  return "sgi"
        case .pcx:  return "pcx"
        case .ppm:  return "ppm"
        case .pgm:  return "pgm"
        case .pbm:  return "pbm"
        case .pam:  return "pam"
        case .webp: return "webp"
        case .jp2:  return "jp2"
        }
    }

    var supportsQuality: Bool {
        switch self {
        case .jpeg, .webp, .jp2: return true
        case .png, .bmp, .gif, .tiff, .tga, .ico, .sgi, .pcx, .ppm, .pgm, .pbm, .pam: return false
        }
    }
}

func convertImageUsingFFmpeg(input: URL, output: URL, format: ImageExportFormat, quality: Int) -> (Bool, String?) {
    if globalVar.doNotUseFFmpeg {
        let msg = NSLocalizedString("ffmpeg-disabled", comment: "FFmpeg 已在高级设置中禁用，请开启后使用图片转换功能")
        return (false, msg)
    }

    if !FFmpegKitWrapper.shared.getIfLoaded() {
        return (false, "FFmpeg not loaded")
    }

    let scaledQuality = max(1, min(100, quality))
    var extraArgs: [String] = []

    switch format {
    case .jpeg:
        let q = max(2, min(31, 33 - Int(round(Double(scaledQuality) * 0.31))))
        extraArgs = ["-q:v", "\(q)"]
    case .png:
        let level = min(9, 9 - Int(round(Double(scaledQuality) * 0.09)))
        extraArgs = ["-compression_level", "\(level)"]
    case .webp:
        let q = max(1, min(100, scaledQuality))
        extraArgs = ["-quality", "\(q)"]
    case .jp2:
        let q = max(1, min(100, scaledQuality))
        extraArgs = ["-quality", "\(q)"]
    case .gif:
        extraArgs = []
    case .bmp, .tiff, .tga, .ico, .sgi, .pcx, .ppm, .pgm, .pbm, .pam:
        extraArgs = []
    }

    let ffmpegArgs: [String] = ["-y", "-i", input.path] + extraArgs + [output.path]

    log("FFmpeg convert: \(ffmpegArgs.joined(separator: " "))", level: .debug)

    if let session = FFmpegKitWrapper.shared.executeFFmpegCommand(ffmpegArgs) {
        let outputStr = FFmpegKitWrapper.shared.getOutput(from: session) ?? ""
        if let returnCode = FFmpegKitWrapper.shared.getReturnCode(from: session) {
            let success = FFmpegKitWrapper.shared.isSuccess(returnCode)
            if !success {
                log("Image conversion failed with return code: \(outputStr)", level: .error)
            }
            return (success, outputStr)
        } else {
            log("Image conversion: failed to get return code, output: \(outputStr)", level: .error)
            return (false, outputStr)
        }
    } else {
        log("Image conversion: ffmpeg execution failed (session nil)", level: .error)
        return (false, "ffmpeg execution failed (session nil)")
    }
}
