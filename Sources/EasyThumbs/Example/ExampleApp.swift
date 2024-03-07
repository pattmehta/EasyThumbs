import SwiftUI

public struct EasyThumbsExampleApp: View {
    
    @State private var navigationPath = NavigationPath()
    
    public init() {}
    
    public var body: some View {
        NavigationStack(path: $navigationPath) {
            rootView()
                .navigationDestination(for: String.self) { route in
                    switch route {
                    case "root": rootView()
                    default: otherView()
                    }
                }
        }
    }
    
    @ViewBuilder
    func rootView() -> some View {
        VStack(alignment: .center) {
            EasyThumbs(urls: EasyThumbsExampleAppConstants.ytUrls, details: EasyThumbsExampleAppConstants.loremSentences) { thumbData in
                Text(thumbData.detail!.joined(separator: ","))
                    .font(.system(size: 11))
                    .lineLimit(2).truncationMode(.tail).multilineTextAlignment(.leading)
                    .padding([.all],2)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.blue))
            }
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(lineWidth: 1))
            Button("to other") { navigationPath.append("other") }.buttonStyle(.borderedProminent)
        }
    }
    
    @ViewBuilder
    func otherView() -> some View {
        Button("back to root") {
            if navigationPath.count > 0 {
                navigationPath.removeLast()
            }
        }
        .buttonStyle(.borderedProminent)
    }
}

struct EasyThumbsExampleAppConstants {
    
    static let ytUrls = [
        "https://i.ytimg.com/vi/7C2z4GqqS5E/default.jpg",
        "https://i.ytimg.com/vi/kTlv5_Bs8aw/default.jpg",
        "https://i.ytimg.com/vi/OK3GJ0WIQ8s/default.jpg",
        "https://i.ytimg.com/vi/p8npDG2ulKQ/default.jpg",
        "https://i.ytimg.com/vi/6ZfuNTqbHE8/default.jpg",
        "https://i.ytimg.com/vi/kX0vO4vlJuU/default.jpg",
        "https://i.ytimg.com/vi/2Vv-BfVoq4g/default.jpg",
        "https://i.ytimg.com/vi/FlsCjmMhFmw/default.jpg",
        "https://i.ytimg.com/vi/J2HytHu5VBI/default.jpg",
        "https://i.ytimg.com/vi/D_6QmL6rExk/default.jpg"
    ]
    
    static let loremSentences = [
        ["Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.", "Lorem ipsum dolor sit amet, consectetur adipiscing elit."],
        ["Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."],
        ["Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.", "Lorem ipsum dolor sit amet, consectetur adipiscing elit."],
        ["Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."],
        ["Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.", "Lorem ipsum dolor sit amet, consectetur adipiscing elit."],
        ["Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."],
        ["Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.", "Lorem ipsum dolor sit amet, consectetur adipiscing elit."],
        ["Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."],
        ["Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.", "Lorem ipsum dolor sit amet, consectetur adipiscing elit."],
        ["Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."]
    ]
}

struct Example_Preview: PreviewProvider {
    
    static var previews: some View {
        EasyThumbsExampleApp()
    }
}
