import Foundation

/// 정렬된 Int64 전화번호의 바이너리 파일 읽기/쓰기
public final class BinaryFileManager {

    public init() {}

    /// Int64 배열을 바이너리 파일로 저장
    public func write(numbers: [Int64], to fileURL: URL) throws {
        let data = numbers.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        try data.write(to: fileURL, options: .atomic)
    }

    /// 바이너리 파일에서 Int64 배열로 로드 (Strategy A: 직접 로드)
    public func readAll(from fileURL: URL) throws -> [Int64] {
        let data = try Data(contentsOf: fileURL)
        let count = data.count / MemoryLayout<Int64>.size
        var numbers = [Int64](repeating: 0, count: count)
        _ = numbers.withUnsafeMutableBufferPointer { buffer in
            data.copyBytes(to: buffer)
        }
        return numbers
    }

    /// 바이너리 파일의 번호 개수 반환
    public func numberCount(at fileURL: URL) -> Int {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int else {
            return 0
        }
        return size / MemoryLayout<Int64>.size
    }

    /// 바이너리 파일 존재 여부 확인
    public func fileExists(at fileURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// 바이너리 파일 삭제
    public func deleteFile(at fileURL: URL) throws {
        if fileExists(at: fileURL) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
