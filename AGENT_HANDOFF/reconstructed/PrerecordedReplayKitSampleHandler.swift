// Reconstructed prototype only. It is not extracted source and is not integrated into TikTok.
// Requires an authorized Xcode/iOS project with ReplayKit, AVFoundation, and an app-group entitlement.
// The product UI must clearly label the source as prerecorded.

import AVFoundation
import ReplayKit

final class PrerecordedReplayKitSampleHandler: RPBroadcastSampleHandler {
    private var reader: AVAssetReader?
    private var videoOutput: AVAssetReaderTrackOutput?
    private var audioOutput: AVAssetReaderTrackOutput?
    private var timer: DispatchSourceTimer?
    private var started = false

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        guard let url = sharedAssetURL() else {
            finishBroadcastWithError(NSError(domain: "PrerecordedStream", code: 1,
                                             userInfo: [NSLocalizedDescriptionKey: "No explicitly selected prerecorded asset"]))
            return
        }
        do { try prepareReader(assetURL: url); started = true; emitNextSample() }
        catch { finishBroadcastWithError(error) }
    }

    override func broadcastPaused() { timer?.suspend() }
    override func broadcastResumed() { timer?.resume() }
    override func broadcastFinished() { timer?.cancel(); timer = nil; reader?.cancelReading() }

    private func prepareReader(assetURL: URL) throws {
        let asset = AVAsset(url: assetURL)
        let r = try AVAssetReader(asset: asset)
        if let track = asset.tracks(withMediaType: .video).first {
            let o = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ])
            o.alwaysCopiesSampleData = false; r.add(o); videoOutput = o
        }
        if let track = asset.tracks(withMediaType: .audio).first {
            let o = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMBitDepthKey: 16
            ])
            o.alwaysCopiesSampleData = false; r.add(o); audioOutput = o
        }
        guard r.startReading() else { throw r.error ?? NSError(domain: "PrerecordedStream", code: 2) }
        reader = r
    }

    private func emitNextSample() {
        guard started, let video = videoOutput?.copyNextSampleBuffer() else {
            finishBroadcastWithError(NSError(domain: "PrerecordedStream", code: 3,
                                             userInfo: [NSLocalizedDescriptionKey: "Prerecorded asset ended or has no video track"]))
            return
        }
        // A production implementation must preserve PTS/DTS, pace frames, pair audio,
        // and send them through the existing authorized broadcast transport. This prototype
        // intentionally stops here rather than pretending that a private TikTok API is known.
        _ = video
    }

    private func sharedAssetURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.zhiliaoapp.shared")?
            .appendingPathComponent("prerecorded-selected.mov")
    }
}
