import Foundation
import MacPermissionKit

@main
enum MatkosonPermissions {
    static func main() async {
        let code = await PermissionCommandLine.execute(commandLine: CommandLine.arguments)
        if code != 0 {
            exit(code)
        }
    }
}
