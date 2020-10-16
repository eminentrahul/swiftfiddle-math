import Vapor

struct ShareImage {
    static func image(client: Client, from code: String) throws -> EventLoopFuture<ByteBuffer?> {
        return client.post("https://carbonara.now.sh/api/cook", headers: ["Content-Type": "application/json"]) {
            try $0.content.encode(
                ["code": "\(code.split(separator: "\n").prefix(30))",
                 "backgroundColor": "rgba(255, 255, 255, 0)",
                 "language": "swift",
                 "paddingHorizontal": "0px",
                 "paddingVertical": "0px",
                 "theme": "one-light",
                ],
                as: .json
            )
        }
        .map { $0.body }
    }
}