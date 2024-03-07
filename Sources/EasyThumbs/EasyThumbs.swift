import SwiftUI

public struct ThumbData: Identifiable {
    public let id: Int
    let url: URL
    let detail: [String]?
    
    init(id: Int, url: URL, detail: [String]? = nil) {
        self.id = id
        self.url = url
        self.detail = detail
    }
}

public struct EasyThumbs: View  {
    
    public static var debug: Bool = true
    
    @State private var cachedThumbs: [ThumbData] = []
    @State private var offlineRetries = 1
    
    private let parentWidth: CGFloat
    private let parentHeight: CGFloat
    private let rowHeight: CGFloat
    private let urls: [String]
    private let details: [[String]]
    
    @ViewBuilder private let content: (ThumbData) -> any View
    
    init(urls: [String], details: [[String]] = [], parentWidth: CGFloat = 350, parentHeight: CGFloat = 550,
         rowHeight: CGFloat = 45, content: @escaping (ThumbData) -> any View) {
        self.urls = urls
        self.details = details
        self.parentWidth = parentWidth
        self.parentHeight = parentHeight
        self.rowHeight = rowHeight
        self.content = content
    }
    
    public var body: some View {
        if isValid() {
            VStack(alignment: .center) {
                asyncViewRows { thumbData in
                    AnyView(content(thumbData))
                }
            }
            .frame(width: parentWidth * autoMainWidthFactor(cachedThumbs), height: parentHeight, alignment: .center)
            .onAppear {
                offlineRetries = 1
                cachedThumbs = []
            }
            .task(id: true, priority: .background) {
                if EasyThumbs.debug { cacheUtils.listCache() }
                do { try await loadCachedUrls() }
                catch { if EasyThumbs.debug { print(error) } }
                if Task.isCancelled {
                    if EasyThumbs.debug {
                        print("===================")
                        print("task cancelled")
                        print("===================")
                    }
                    cachedThumbs = []
                }
            }
        } else {
            Text("mismatching count in urls and details")
                .font(.system(size: 12)).foregroundStyle(Color.red)
        }
    }
    
    @ViewBuilder
    private func asyncViewRows(@ViewBuilder content: @escaping (ThumbData) -> some View) -> some View {
        ForEach(cachedThumbs, id:\.id) { thumbData in
            let data = Data(url: thumbData.url) // withBackup
            HStack(alignment: .center) {
                Image(uiImage: UIImage(data: data)!)
                    .resizable(resizingMode: .stretch)
                    .frame(width: EasyThumbsConstants.thumbWidth, height: EasyThumbsConstants.thumbHeight)
                    .aspectRatio(contentMode: .fill)
                if thumbData.detail != nil {
                    // custom view content
                    content(thumbData)
                }
            }
            .frame(width: parentWidth * autoRowWidthFactor(thumbData), height: rowHeight, alignment: autoalignment(thumbData))
        }
    }
    
    private func loadCachedUrls() async throws {
        for (idx, urlString) in urls.enumerated() {
            let url = URL(string: urlString)!
            guard let imgFilename = cacheUtils.networkUrlToCacheFilename(url) else {
                return
            }
            var cacheUrl: URL
            if let url = cacheUtils.readCacheAsUrl(imgFilename: imgFilename) {
                cacheUrl = url
            } else {
                // if cache miss, download the image
                let imgData = Data(url: url) // withBackup!!
                let imgDiskUrl = cacheUtils.writeCache(imgFilename: imgFilename, imgData)
                guard imgDiskUrl != nil else {
                    return
                }
                cacheUrl = imgDiskUrl!
            }
            if details.count > 0 {
                cachedThumbs.append(ThumbData(id: idx, url: cacheUrl, detail: details[idx]))
            } else {
                cachedThumbs.append(ThumbData(id: idx, url: cacheUrl))
            }
            try await Task.sleep(for: .milliseconds(EasyThumbsConstants.sleepTimeInMilliseconds))
        }
        if cacheUtils.overcache(urls: cachedThumbs.map { $0.url }) && offlineRetries < EasyThumbsConstants.maxOfflineRetries {
            offlineRetries = offlineRetries + 1
            if EasyThumbs.debug {
                print("===================")
                print("cache bloat")
                print("===================")
            }
            cacheUtils.clearCache()
            cachedThumbs = []
            try await loadCachedUrls()
        }
    }
}

fileprivate extension EasyThumbs {
    
    private func isValid() -> Bool {
        /// ensures equal count of urls and details for a uniform look
        guard details.count > 0, details.count != urls.count else {
            return true
        }
        return false
    }
    
    private func autoalignment(_ thumbdata: ThumbData) -> Alignment {
        /// helps aligning images to the center, if details are not passed
        guard thumbdata.detail != nil else {
            return .center
        }
        return .leading
    }
    
    private func autoRowWidthFactor(_ thumbdata: ThumbData) -> CGFloat {
        /// adjusts width factor for the row frame
        guard thumbdata.detail != nil else {
            return EasyThumbsConstants.narrowRowFactor
        }
        return EasyThumbsConstants.wideRowFactor
    }
    
    private func autoMainWidthFactor(_ cachedThumbs: [ThumbData]) -> CGFloat {
        /// adjusts width factor for the main view
        let details = cachedThumbs.map { $0.detail }
        guard details.first(where: { $0 == nil }) == nil else {
            return EasyThumbsConstants.mainWidthNarrowFactor
        }
        return EasyThumbsConstants.mainWidthWideFactor
    }
}

let placeholderBitmap: Data = {
    let size = CGSize(width: 16, height: 16)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    format.preferredRange = .standard
    let rect = CGRect(origin: CGPoint.zero, size: size)
    
    return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 1.0) { context in
        context.cgContext.setFillColor(UIColor.lightGray.cgColor)
        context.cgContext.addRect(rect)
        context.cgContext.drawPath(using: .fill)
    }
}()
