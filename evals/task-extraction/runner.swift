// Runs the app's own TaskExtractor over the eval cases and writes what it answered.
// Compiled together with app/Shared/TaskExtractor.swift by run.sh, so the prompt, schema, model
// and request are exactly the ones the apps use.
//
// usage: runner <.env> <cases.jsonl> <output folder> [reps]
import Foundation

struct Case: Decodable {
    let id: String
    let recorded_at: String
    let transcript: String
    let catalog: TaskCatalog
}

let berlin = TimeZone(identifier: "Europe/Berlin")!

let writing = NSLock()

/// Appends one JSON line. Cases finish concurrently, so writes take turns.
func append(_ object: [String: Any], to url: URL) {
    guard var data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
    data.append(0x0A)
    writing.lock()
    defer { writing.unlock() }
    if let handle = try? FileHandle(forWritingTo: url) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: url)
    }
}

@main
struct Runner {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 4 else { fatalError("usage: runner <.env> <cases.jsonl> <output folder> [reps]") }
        let env = try String(contentsOfFile: arguments[1], encoding: .utf8)
        guard let line = env.split(separator: "\n").first(where: { $0.hasPrefix("ANTHROPIC_API_KEY=") }) else { fatalError("no ANTHROPIC_API_KEY in .env") }
        let key = line.dropFirst("ANTHROPIC_API_KEY=".count).trimmingCharacters(in: CharacterSet(charactersIn: "\"' \r"))
        let cases = try String(contentsOfFile: arguments[2], encoding: .utf8).split(separator: "\n")
            .map { try JSONDecoder().decode(Case.self, from: Data($0.utf8)) }
        let folder = URL(fileURLWithPath: arguments[3])
        let reps = arguments.count > 4 ? Int(arguments[4]) ?? 1 : 1
        let outputs = folder.appendingPathComponent("outputs.jsonl")
        let errors = folder.appendingPathComponent("errors.jsonl")
        let traces = folder.appendingPathComponent("traces")
        try FileManager.default.createDirectory(at: traces, withIntermediateDirectories: true)

        // Resume: skip every (case, rep) that already has an answer.
        var done = Set<String>()
        if let existing = try? String(contentsOf: outputs, encoding: .utf8) {
            for row in existing.split(separator: "\n") {
                if let object = try? JSONSerialization.jsonObject(with: Data(row.utf8)) as? [String: Any],
                   let id = object["id"] as? String, let rep = object["rep"] as? Int { done.insert("\(id)#\(rep)") }
            }
        }
        var work: [(Case, Int)] = []
        for rep in 0..<reps { for item in cases where !done.contains("\(item.id)#\(rep)") { work.append((item, rep)) } }
        print("\(cases.count) cases × \(reps) rep(s): \(work.count) to run, \(done.count) already done")

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = berlin
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let encoder = JSONEncoder()

        await withTaskGroup(of: Void.self) { group in
            var next = 0
            func launch() {
                guard next < work.count else { return }
                let (item, rep) = work[next]
                next += 1
                group.addTask {
                    let recordedAt = formatter.date(from: item.recorded_at)!
                    var attempt = 0
                    while true {
                        attempt += 1
                        let start = Date()
                        do {
                            let result = try await TaskExtractor.extraction(from: item.transcript, recordedAt: recordedAt,
                                                                            catalog: item.catalog, timeZone: berlin, apiKey: key)
                            let latency = Date().timeIntervalSince(start)
                            // A different model answering (a fallback, a reroute) would make the numbers mean something else.
                            guard result.model.hasPrefix(TaskExtractor.model) else {
                                append(["id": item.id, "rep": rep, "class": "served-model mismatch", "detail": result.model, "attempts": attempt], to: errors)
                                return
                            }
                            let drafts = result.drafts.compactMap { try? JSONSerialization.jsonObject(with: encoder.encode($0)) }
                            append(["id": item.id, "rep": rep, "drafts": drafts, "model": result.model, "attempts": attempt,
                                    "latency_s": (latency * 100).rounded() / 100,
                                    "usage": ["input_tokens": result.inputTokens, "output_tokens": result.outputTokens]], to: outputs)
                            let answer = drafts.isEmpty ? "no task" : (try? JSONSerialization.data(withJSONObject: drafts, options: [.prettyPrinted, .sortedKeys]))
                                .flatMap { String(data: $0, encoding: .utf8) } ?? "?"
                            let trace: [[String: String]] = [
                                ["role": "system", "content": TaskExtractor.instructions],
                                ["role": "user", "content": TaskExtractor.message(transcript: item.transcript, recordedAt: recordedAt, catalog: item.catalog, timeZone: berlin)],
                                ["role": "assistant", "content": answer],
                            ]
                            try? JSONSerialization.data(withJSONObject: trace, options: [.prettyPrinted])
                                .write(to: traces.appendingPathComponent("\(item.id)_rep\(rep).json"))
                            return
                        } catch {
                            let message = error.localizedDescription
                            let transient = message.localizedCaseInsensitiveContains("overloaded") || message.localizedCaseInsensitiveContains("rate")
                                || (error as? URLError) != nil
                            if transient, attempt < 4 {
                                try? await Task.sleep(for: .seconds(Double(1 << attempt) + Double.random(in: 0...1)))
                                continue
                            }
                            let kind = (error as? TaskExtractorError).map { if case .declined = $0 { return "refusal" } else { return "api error" } } ?? "harness error"
                            append(["id": item.id, "rep": rep, "class": kind, "detail": message, "attempts": attempt], to: errors)
                            return
                        }
                    }
                }
            }
            for _ in 0..<6 { launch() }
            for await _ in group { launch() }
        }
        print("done")
    }
}
