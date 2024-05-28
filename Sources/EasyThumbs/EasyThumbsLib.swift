import SwiftUI

class CacheUtils {
    
    static let shared: CacheUtils = CacheUtils()
    static var debug: Bool = true
    
    private init() {}
    
    var cacheDir: String? {
        /// returns `Path` string for `FileManager` cache directory
        guard let cacheDirUrl = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let imageCacheDirUrl = URL(fileURLWithPath: cacheDirUrl.path(percentEncoded: true)).appendingPathComponent("ImageCache")
        if !FileManager.default.fileExists(atPath: imageCacheDirUrl.path(percentEncoded: true)) {
            do {
                try FileManager.default.createDirectory(at: imageCacheDirUrl, withIntermediateDirectories: false)
            } catch {
                print("cacheDir: \(error)")
                return nil
            }
        }
        return imageCacheDirUrl.path(percentEncoded: true)
    }
    
    func networkUrlToCacheFilename(_ networkUrl: URL) -> String? {
        /// get a unique string filename from a url
        /// always generates same name for same url
        let imgDiskUrl = networkUrl.absoluteString
        guard let base64String = imgDiskUrl.data(using: .utf8)?.base64EncodedString() else {
            return nil
        }
        let endIndex = base64String.index(base64String.startIndex, offsetBy: base64String.count - EasyThumbsConstants.base64StringSkipTrailingCount)
        return String(base64String[base64String.startIndex...endIndex])
    }
    
    func readCacheAsUrl(imgFilename: String) -> URL? {
        guard let cacheDir = cacheDir else {
            return nil
        }
        
        let imgDiskUrl = URL(fileURLWithPath: cacheDir).appendingPathComponent(imgFilename)
        if FileManager.default.fileExists(atPath: imgDiskUrl.path(percentEncoded: true)) {
            if CacheUtils.debug {
                print("read-cache: \(imgFilename)")
            }
            return imgDiskUrl
        } else {
            if CacheUtils.debug {
                print("read-cache-failed: \(imgFilename)")
            }
            return nil
        }
    }
    
    func writeCache(imgFilename: String, _ imgData: Data) -> URL? {
        guard let cacheDir = cacheDir else {
            return nil
        }
        let imgDiskUrl = URL(fileURLWithPath: cacheDir).appendingPathComponent(imgFilename)
        do {
            try imgData.write(to: imgDiskUrl)
            if CacheUtils.debug {
                print("write-cache: \(imgFilename)")
            }
            return imgDiskUrl
        } catch {
            if CacheUtils.debug {
                print("write-cache-failed: \(imgFilename)")
            }
            return nil
        }
    }
    
    func listCache() {
        guard let cacheDir = cacheDir else {
            return
        }
        let imgDiskUrl = URL(fileURLWithPath: cacheDir)
        guard let urls = try? FileManager.default.contentsOfDirectory(at: imgDiskUrl, includingPropertiesForKeys: [.isRegularFileKey]) else {
            print("listCache: cacheDir is empty")
            return
        }
        
        if urls.count > 0 {
            print("listCache:")
            for (idx,url) in urls.enumerated() {
                let pathComponentsCount = url.pathComponents.count
                if pathComponentsCount > 4 {
                    print("#\(idx + 1) \(url.pathComponents[pathComponentsCount - 4 ..< pathComponentsCount].joined(separator: "/"))")
                }
            }
        }
    }
    
    func clearCache() {
        guard let cacheDir = cacheDir else {
            return
        }
        do {
            let imgDiskUrl = URL(fileURLWithPath: cacheDir)
            try FileManager.default.removeItem(at: imgDiskUrl)
        } catch {
            print("clearCache: \(error)")
        }
    }
    
    func overcache(urls: [URL]) -> Bool {
        /// if cache was created offline, such that (ratio of) tolerance data is copy of placeholder/backup
        /// return true, which will ensure cache is cleared, and loading is re-run
        let tolerance = EasyThumbsConstants.overCacheTolerance
        guard let cacheBloat = try? (urls.filter { try Data(contentsOf: $0).starts(with: placeholderBitmap) }) else {
            return false
        }
        return Float(cacheBloat.count / urls.count) > tolerance
    }
}

extension Data {
    
    init(url: URL, withBackup: Data = placeholderBitmap) {
        guard let data = try? Data(contentsOf: url) else {
            self = placeholderBitmap
            return
        }
        self = data
    }
}

let cacheUtils = CacheUtils.shared
