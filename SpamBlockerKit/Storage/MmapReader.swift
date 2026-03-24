import Foundation

/// Memory-mapped 바이너리 파일 리더 (Strategy B: mmap)
/// Extension에서 대량 번호를 메모리 효율적으로 읽기 위한 클래스
public final class MmapReader {
    private let fileURL: URL
    private var fileDescriptor: Int32 = -1
    private var mappedPointer: UnsafeMutableRawPointer?
    private var fileSize: Int = 0

    public var count: Int {
        fileSize / MemoryLayout<Int64>.size
    }

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    deinit {
        close()
    }

    /// 파일을 mmap으로 열기
    public func open() throws {
        fileDescriptor = Darwin.open(fileURL.path, O_RDONLY)
        guard fileDescriptor >= 0 else {
            throw MmapError.cannotOpenFile(fileURL.path)
        }

        var stat = stat()
        guard fstat(fileDescriptor, &stat) == 0 else {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            throw MmapError.cannotStatFile
        }

        fileSize = Int(stat.st_size)
        guard fileSize > 0 else {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            throw MmapError.emptyFile
        }

        mappedPointer = mmap(nil, fileSize, PROT_READ, MAP_PRIVATE, fileDescriptor, 0)
        guard mappedPointer != MAP_FAILED else {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
            mappedPointer = nil
            throw MmapError.mmapFailed
        }
    }

    /// 인덱스로 번호 읽기
    public subscript(index: Int) -> Int64 {
        guard let ptr = mappedPointer else { return 0 }
        return ptr.load(fromByteOffset: index * MemoryLayout<Int64>.size, as: Int64.self)
    }

    /// 모든 번호를 순회하며 클로저 호출
    public func enumerate(_ body: (Int64) -> Void) {
        let total = count
        for i in 0..<total {
            body(self[i])
        }
    }

    /// 파일 닫기
    public func close() {
        if let ptr = mappedPointer, fileSize > 0 {
            munmap(ptr, fileSize)
            mappedPointer = nil
        }
        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }
        fileSize = 0
    }
}

public enum MmapError: Error, LocalizedError {
    case cannotOpenFile(String)
    case cannotStatFile
    case emptyFile
    case mmapFailed

    public var errorDescription: String? {
        switch self {
        case .cannotOpenFile(let path): return "Cannot open file: \(path)"
        case .cannotStatFile: return "Cannot stat file"
        case .emptyFile: return "File is empty"
        case .mmapFailed: return "mmap failed"
        }
    }
}
