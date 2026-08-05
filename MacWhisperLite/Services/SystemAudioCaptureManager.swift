//
//  SystemAudioCaptureManager.swift
//  MacWhisperLite

// Create a dedicated manager to handle capturing internal audio. This implementation captures the entire system audio stream, resamples it using AVAudioConverter, and forwards the samples back to your manager.
//  Created by ian kuo on 2026-07-14.
//


import ScreenCaptureKit
import AVFoundation

class SystemAudioCaptureManager: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var converter: AVAudioConverter?
    private let whisperFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    
    var onSamplesCaptured: (([Float]) -> Void)?
    
    func startCapture() async throws {
        // 1. Request permission and get available content
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        
        // 2. Create a filter for all system audio
        let filter = SCContentFilter(display: content.displays[0], excludingWindows: [])
        
        // 3. Configure the stream to ONLY capture audio
        let configuration = SCStreamConfiguration()
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = true // Avoid capturing itself if it plays sounds
        
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.whisper.system.audio"))
        
        try await stream?.startCapture()
    }
    
    func stopCapture() async throws {
        try await stream?.stopCapture()
        stream = nil
        converter = nil
    }
    
    // MARK: - SCStreamOutput Delegate
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        
        // Setup converter on the fly based on the incoming hardware format
        if converter == nil, let formatDescription = sampleBuffer.formatDescription {
            let hardwareFormat = AVAudioFormat(cmAudioFormatDescription: formatDescription)
            converter = AVAudioConverter(from: hardwareFormat, to: whisperFormat)
        }
        
        guard let converter = converter else { return }
        
        // Convert CMSampleBuffer to AVAudioPCMBuffer
        guard let pcmBuffer = AVAudioPCMBuffer(pcmBuffer: sampleBuffer) else { return }
        
        let ratio = 16000.0 / pcmBuffer.format.sampleRate
        let targetCapacity = AVAudioFrameCount(Double(pcmBuffer.frameLength) * ratio)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: whisperFormat, frameCapacity: targetCapacity) else { return }
        
        var error: NSError?
        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return pcmBuffer
        }
        
        guard let channelData = outputBuffer.floatChannelData else { return }
        let frameCount = Int(outputBuffer.frameLength)
        let newSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))
        
        if !newSamples.isEmpty {
            onSamplesCaptured?(newSamples)
        }
    }
}

// Helper extension to initialize an AVAudioPCMBuffer from ScreenCaptureKit's CMSampleBuffer
extension AVAudioPCMBuffer {
    convenience init?(pcmBuffer sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = sampleBuffer.formatDescription else { return nil }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)
        
        var ablList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &ablList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        self.init(pcmFormat: format, frameCapacity: frameCount)
        self.frameLength = frameCount
        
        if let srcBuffer = ablList.mBuffers.mData, let destBuffer = self.mutableAudioBufferList.pointee.mBuffers.mData {
            destBuffer.copyMemory(from: srcBuffer, byteCount: Int(ablList.mBuffers.mDataByteSize))
        }
    }
}
