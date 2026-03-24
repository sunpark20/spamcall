import Foundation

/// 선택된 번호대로부터 정렬된 E.164 전화번호 배열을 생성
public final class NumberGenerator {

    public init() {}

    /// 선택된 PrefixEntry들로부터 정렬된 Int64 번호 배열 생성
    /// - 각 prefix 내의 번호는 자연적으로 정렬됨
    /// - prefix 간 정렬을 위해 startNumber 기준으로 정렬 후 순차 생성
    public func generateSortedNumbers(from entries: [PrefixEntry]) -> [Int64] {
        let sortedEntries = entries.sorted { $0.startNumber < $1.startNumber }
        var numbers: [Int64] = []
        numbers.reserveCapacity(sortedEntries.reduce(0) { $0 + $1.numberCount })

        for entry in sortedEntries {
            let start = entry.startNumber
            for i in 0..<Int64(entry.numberCount) {
                numbers.append(start + i)
            }
        }

        return numbers
    }

    /// 선택된 PrefixEntry들로부터 정렬된 번호를 바이너리 파일로 직접 스트리밍 저장
    /// 메모리를 절약하면서 대량 번호 생성 가능
    public func generateAndWriteToBinaryFile(
        from entries: [PrefixEntry],
        to fileURL: URL,
        progress: ((Int, Int) -> Void)? = nil
    ) throws -> Int {
        let sortedEntries = entries.sorted { $0.startNumber < $1.startNumber }
        let totalCount = sortedEntries.reduce(0) { $0 + $1.numberCount }

        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)
        defer { handle.closeFile() }

        var written = 0
        let bufferSize = 4096 // 512개 번호씩 버퍼링 (512 * 8 bytes)
        var buffer = Data(capacity: bufferSize * MemoryLayout<Int64>.size)

        for entry in sortedEntries {
            let start = entry.startNumber
            for i in 0..<entry.numberCount {
                var number = start + Int64(i)
                buffer.append(Data(bytes: &number, count: MemoryLayout<Int64>.size))

                if buffer.count >= bufferSize * MemoryLayout<Int64>.size {
                    handle.write(buffer)
                    buffer.removeAll(keepingCapacity: true)
                }

                written += 1
                if written % 100_000 == 0 {
                    progress?(written, totalCount)
                }
            }
        }

        // 남은 버퍼 기록
        if !buffer.isEmpty {
            handle.write(buffer)
        }

        progress?(written, totalCount)
        return written
    }
}
