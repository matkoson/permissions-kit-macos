import Foundation

struct FileCoverage {
    var lines: [(Int, Int)] = []
    var hit = 0
    var found = 0
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("usage: LcovToCobertura input.lcov output.xml\n".utf8))
    exit(2)
}

let input = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
var files: [String: FileCoverage] = [:]
var current: String?

for raw in input.split(separator: "\n", omittingEmptySubsequences: false) {
    let line = String(raw)
    if line.hasPrefix("SF:") {
        current = String(line.dropFirst(3))
        if let name = current, files[name] == nil {
            files[name] = FileCoverage()
        }
    } else if line.hasPrefix("DA:"), let name = current {
        let parts = line.dropFirst(3).split(separator: ",", maxSplits: 1).map(String.init)
        guard parts.count == 2, let number = Int(parts[0]), let hits = Int(parts[1]) else { continue }
        var coverage = files[name] ?? FileCoverage()
        coverage.lines.append((number, hits))
        coverage.found += 1
        if hits > 0 { coverage.hit += 1 }
        files[name] = coverage
    } else if line == "end_of_record" {
        current = nil
    }
}

let totalHit = files.values.reduce(0) { $0 + $1.hit }
let totalFound = files.values.reduce(0) { $0 + $1.found }
let rate = totalFound == 0 ? 0.0 : Double(totalHit) / Double(totalFound)

func escape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

var xml = "<?xml version=\"1.0\" ?>\n"
xml += "<coverage line-rate=\"\(String(format: "%.4f", rate))\" branch-rate=\"1.0\" lines-covered=\"\(totalHit)\" lines-valid=\"\(totalFound)\" version=\"1\">\n"
xml += "  <packages><package name=\"MacPermissionKit\" line-rate=\"\(String(format: "%.4f", rate))\"><classes>\n"
for name in files.keys.sorted() {
    let coverage = files[name] ?? FileCoverage()
    let fileRate = coverage.found == 0 ? 0.0 : Double(coverage.hit) / Double(coverage.found)
    xml += "<class name=\"\(escape((name as NSString).lastPathComponent))\" filename=\"\(escape(name))\" line-rate=\"\(String(format: "%.4f", fileRate))\"><lines>\n"
    for (number, hits) in coverage.lines.sorted(by: { $0.0 < $1.0 }) {
        xml += "<line number=\"\(number)\" hits=\"\(hits)\"/>\n"
    }
    xml += "</lines></class>\n"
}
xml += "</classes></package></packages></coverage>\n"
try xml.write(toFile: CommandLine.arguments[2], atomically: true, encoding: .utf8)
let message = String(format: "line coverage %.2f%% (%d/%d)\n", rate * 100, totalHit, totalFound)
FileHandle.standardOutput.write(Data(message.utf8))
if rate + 0.0000001 < 0.90 {
    FileHandle.standardError.write(Data("coverage below 90%\n".utf8))
    exit(1)
}
