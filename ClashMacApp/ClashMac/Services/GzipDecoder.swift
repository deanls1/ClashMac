import Foundation
import zlib

enum GzipDecoder {
    enum Error: Swift.Error {
        case invalidInput
        case decompressFailed(code: Int32)
    }

    static func decompress(_ data: Data) throws -> Data {
        guard !data.isEmpty else { throw Error.invalidInput }

        return try data.withUnsafeBytes { inputBuffer in
            guard let inputBase = inputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else {
                throw Error.invalidInput
            }

            var stream = z_stream()
            stream.next_in = UnsafeMutablePointer(mutating: inputBase)
            stream.avail_in = uInt(inputBuffer.count)

            let initStatus = inflateInit2_(
                &stream,
                15 + 32,
                ZLIB_VERSION,
                Int32(MemoryLayout<z_stream>.size)
            )
            guard initStatus == Z_OK else {
                throw Error.decompressFailed(code: initStatus)
            }
            defer { inflateEnd(&stream) }

            var output = Data()
            let chunkSize = 65_536
            var buffer = [UInt8](repeating: 0, count: chunkSize)

            var status: Int32 = Z_OK
            repeat {
                stream.next_out = UnsafeMutablePointer(mutating: &buffer)
                stream.avail_out = uInt(chunkSize)
                status = inflate(&stream, Z_NO_FLUSH)
                guard status == Z_OK || status == Z_STREAM_END else {
                    throw Error.decompressFailed(code: status)
                }
                let produced = chunkSize - Int(stream.avail_out)
                if produced > 0 {
                    output.append(buffer, count: produced)
                }
            } while status != Z_STREAM_END

            guard !output.isEmpty else { throw Error.invalidInput }
            return output
        }
    }
}
