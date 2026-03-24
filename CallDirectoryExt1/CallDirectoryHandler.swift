import Foundation
import CallKit
import SpamBlockerKit

/// 번호 로딩 전략
enum LoadingStrategy {
    case directLoad  // Strategy A: 전체 배열 로드
    case mmap        // Strategy B: Memory-mapped 파일
    case streaming   // Strategy C: FileHandle 순차 읽기
}

final class CallDirectoryHandler: CXCallDirectoryProvider {

    // Phase 0 실험용: 여기서 전략을 변경하여 테스트
    private let strategy: LoadingStrategy = .mmap

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        let fileURL = AppGroupManager.shared.defaultBinaryFilePath

        guard BinaryFileManager().fileExists(at: fileURL) else {
            context.completeRequest()
            return
        }

        do {
            switch strategy {
            case .directLoad:
                try addBlockingEntries_directLoad(context: context, fileURL: fileURL)
            case .mmap:
                try addBlockingEntries_mmap(context: context, fileURL: fileURL)
            case .streaming:
                try addBlockingEntries_streaming(context: context, fileURL: fileURL)
            }
        } catch {
            print("[CallDirectoryHandler] Error: \(error)")
        }

        context.completeRequest()
    }

    // MARK: - Strategy A: 직접 로드

    private func addBlockingEntries_directLoad(
        context: CXCallDirectoryExtensionContext,
        fileURL: URL
    ) throws {
        let numbers = try BinaryFileManager().readAll(from: fileURL)
        for number in numbers {
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }
    }

    // MARK: - Strategy B: mmap

    private func addBlockingEntries_mmap(
        context: CXCallDirectoryExtensionContext,
        fileURL: URL
    ) throws {
        let reader = MmapReader(fileURL: fileURL)
        try reader.open()
        defer { reader.close() }

        reader.enumerate { number in
            context.addBlockingEntry(withNextSequentialPhoneNumber: number)
        }
    }

    // MARK: - Strategy C: 스트리밍

    private func addBlockingEntries_streaming(
        context: CXCallDirectoryExtensionContext,
        fileURL: URL
    ) throws {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { handle.closeFile() }

        let chunkSize = MemoryLayout<Int64>.size * 512 // 512개씩 읽기

        while true {
            let data = handle.readData(ofLength: chunkSize)
            if data.isEmpty { break }

            data.withUnsafeBytes { rawBuffer in
                let buffer = rawBuffer.bindMemory(to: Int64.self)
                for number in buffer {
                    context.addBlockingEntry(withNextSequentialPhoneNumber: number)
                }
            }
        }
    }
}

// MARK: - CXCallDirectoryExtensionContextDelegate

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        print("[CallDirectoryHandler] Request failed: \(error)")
    }
}
