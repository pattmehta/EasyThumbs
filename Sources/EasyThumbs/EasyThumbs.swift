import SwiftUI

public struct ThumbData: Identifiable {
    
    public let id: Int
    let url: URL
    public let detail: [String]?
    
    init(id: Int, url: URL, detail: [String]? = nil) {
        self.id = id
        self.url = url
        self.detail = detail
    }
}

public enum SelectionMode {
    case none
    case single
    case multiple
}

public struct EasyThumbs: View  {
    
    public typealias callback = () -> ()
    
    public static var debug: Bool = false
    @State private var cachedThumbs: [ThumbData] = []
    @State private var offlineRetries = 1
    @Binding private var selections: [Int]
    @Binding private var filterQuery: String
    
    private let urls: [String]
    private let details: [[String]]
    private let parentWidth: CGFloat
    private let parentHeight: CGFloat
    private let contentRowWidth: CGFloat
    private let contentRowHeight: CGFloat
    private let imageSize: CGSize
    private let imageScaleFactor: CGFloat
    private let imageClipShapeRadius: CGFloat
    private let contentSpacing: CGFloat
    private let rowColor: Color
    private let scrollIndicatorVisibility: ScrollIndicatorVisibility
    private let selectionColor: Color
    private let selectionMode: SelectionMode
    private let onRefresh: callback?
    
    @ViewBuilder private let content: (ThumbData) -> any View
    
    public init(urls: [String], details: [[String]] = [], parentSize: CGSize = CGSize(width: 350, height: 505),
                contentRowSize: CGSize = CGSize(width: 250, height: 44), imageSize: CGSize = CGSize(width: 44, height: 31),
                imageScaleFactor: CGFloat = 1, imageClipShapeRadius: CGFloat = 1, contentSpacing: CGFloat = 1, rowColor: Color = Color.white,
                scrollIndicatorVisibility: ScrollIndicatorVisibility = .hidden,
                selectionColor: Color = Color.green, selectionMode: SelectionMode = .none, selections: Binding<[Int]>,
                filterQuery: Binding<String>,
                onRefresh: callback? = nil, content: @escaping (ThumbData) -> any View) {
        self.urls = urls
        self.details = details
        self.parentWidth = parentSize.width
        self.parentHeight = parentSize.height
        self.contentRowWidth = contentRowSize.width
        self.contentRowHeight = contentRowSize.height
        self.imageSize = imageSize
        self.imageScaleFactor = imageScaleFactor
        self.imageClipShapeRadius = imageClipShapeRadius
        self.contentSpacing = contentSpacing
        self.rowColor = rowColor
        self.scrollIndicatorVisibility = scrollIndicatorVisibility
        self.selectionColor = selectionColor
        self.selectionMode = selectionMode
        self._selections = selections
        self._filterQuery = filterQuery
        /// Stored closures outlive the function scope, so they are marked `@escaping`
        self.onRefresh = onRefresh
        self.content = content
    }
    
    public var body: some View {
        if isValid() {
            VStack(alignment: .center) {
                asyncViewRows { thumbData in
                    AnyView(content(thumbData))
                }
            }
            .frame(width: parentWidth * autoMainWidthFactor(), height: parentHeight, alignment: .center)
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
        List(cachedThumbsFiltered(), id:\.id) { thumbData in
            let data = Data(url: thumbData.url) // withBackup
            HStack(alignment: .center, spacing: contentSpacing) {
                ZStack(alignment: .topLeading) {
                    Image(uiImage: UIImage(data: data)!)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSize.width * imageScaleFactor, height: imageSize.height * imageScaleFactor, alignment: .center)
                }
                .frame(width: imageSize.width, height: imageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: imageClipShapeRadius))
                if thumbData.detail != nil {
                    // custom view content
                    content(thumbData)
                        .frame(width: contentRowWidth, height: contentRowHeight)
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(rowColor)
            .overlay(highlight(selection: thumbData.id))
            .onTapGesture {
                guard selectionMode != .none else {
                    return
                }
                if selectionMode == .single {
                    selections = [thumbData.id]
                } else {
                    selections.append(thumbData.id)
                }
            }
        }
        .frame(width: parentWidth * autoRowWidthFactor(), height: parentHeight * 0.95, alignment: .center)
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .scrollIndicators(scrollIndicatorVisibility, axes: .vertical)
        .refreshable {
            if let onRefresh = onRefresh {
                onRefresh()
            }
        }
        .debugBorder()
    }
    
    @ViewBuilder
    private func highlight(selection index: Int) -> some View {
        if selectionMode != .none, selections.contains(where: { $0 == index }) {
            RoundedRectangle(cornerRadius: 5)
                .stroke(selectionColor, style: StrokeStyle(lineWidth: 2, dash: [3]))
        } else {
            EmptyView()
        }
    }
    
    private func cachedThumbsFiltered() -> [ThumbData] {
        guard filterQuery.count > 2 else {
            return cachedThumbs
        }
        return cachedThumbs.filter {
            $0.detail?.joined(separator:"").lowercased().contains(filterQuery.lowercased())
            ?? false
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
    
    private func autoalignment() -> Alignment {
        /// helps aligning images to the center, if details are not passed
        guard details.count > 0 else {
            return .center
        }
        return .leading
    }
    
    private func autoRowWidthFactor() -> CGFloat {
        /// adjusts width factor for the row frame
        guard details.count > 0 else {
            return EasyThumbsConstants.narrowRowFactor
        }
        return EasyThumbsConstants.wideRowFactor
    }
    
    private func autoMainWidthFactor() -> CGFloat {
        /// adjusts width factor for the main view
        guard details.count > 0 else {
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

fileprivate extension View {
    
    @ViewBuilder func debugBorder() -> some View {
        if EasyThumbs.debug {
            return AnyView(self.overlay(Rectangle().stroke(Color.yellow, lineWidth: 1)))
        }
        return AnyView(self)
    }
}
