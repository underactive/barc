import AVFoundation
import Combine

class NetworkSoundManager: ObservableObject {
    static let shared = NetworkSoundManager()

    private var audioEngine: AVAudioEngine?
    private var txPlayerNode: AVAudioPlayerNode?
    private var rxPlayerNode: AVAudioPlayerNode?
    private var txBuffer: AVAudioPCMBuffer?
    private var rxBuffer: AVAudioPCMBuffer?

    private var cancellables = Set<AnyCancellable>()
    private var lastTxState = false
    private var lastRxState = false

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "sound.networkActivity")
            if isEnabled {
                setupAudioEngine()
            } else {
                stopAudioEngine()
            }
        }
    }

    @Published var rxEnabled: Bool {
        didSet {
            UserDefaults.standard.set(rxEnabled, forKey: "sound.rxEnabled")
        }
    }

    @Published var txEnabled: Bool {
        didSet {
            UserDefaults.standard.set(txEnabled, forKey: "sound.txEnabled")
        }
    }

    @Published var volume: Float {
        didSet {
            UserDefaults.standard.set(volume, forKey: "sound.volume")
            updateVolume()
        }
    }

    @Published var soundScope: NetworkSoundScope {
        didSet {
            UserDefaults.standard.set(soundScope.rawValue, forKey: "sound.scope")
        }
    }

    private func updateVolume() {
        txPlayerNode?.volume = volume
        rxPlayerNode?.volume = volume
    }

    private init() {
        // Default to enabled
        if UserDefaults.standard.object(forKey: "sound.networkActivity") == nil {
            UserDefaults.standard.set(true, forKey: "sound.networkActivity")
        }
        self.isEnabled = UserDefaults.standard.bool(forKey: "sound.networkActivity")

        // Default to true if not set
        if UserDefaults.standard.object(forKey: "sound.rxEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "sound.rxEnabled")
        }
        if UserDefaults.standard.object(forKey: "sound.txEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "sound.txEnabled")
        }
        // Default volume to 50%
        if UserDefaults.standard.object(forKey: "sound.volume") == nil {
            UserDefaults.standard.set(Float(0.5), forKey: "sound.volume")
        }
        // Default scope to active tab only
        if UserDefaults.standard.object(forKey: "sound.scope") == nil {
            UserDefaults.standard.set(NetworkSoundScope.activeTabOnly.rawValue, forKey: "sound.scope")
        }
        self.rxEnabled = UserDefaults.standard.bool(forKey: "sound.rxEnabled")
        self.txEnabled = UserDefaults.standard.bool(forKey: "sound.txEnabled")
        self.volume = UserDefaults.standard.float(forKey: "sound.volume")
        self.soundScope = NetworkSoundScope(rawValue: UserDefaults.standard.string(forKey: "sound.scope") ?? "activeTabOnly") ?? .activeTabOnly

        if isEnabled {
            setupAudioEngine()
        }

        // Observe network activity
        setupNetworkObservers()
    }

    private func setupNetworkObservers() {
        let monitor = NetworkActivityMonitor.shared

        // Observe transmitting changes
        monitor.$isTransmitting
            .removeDuplicates()
            .sink { [weak self] isTransmitting in
                guard let self = self, self.isEnabled, self.txEnabled else { return }
                if isTransmitting && !self.lastTxState {
                    // Check if we should play based on sound scope
                    if self.soundScope == .allTabs || monitor.lastTransmitWasActiveTab {
                        self.playTxSound()
                    }
                }
                self.lastTxState = isTransmitting
            }
            .store(in: &cancellables)

        // Observe receiving changes
        monitor.$isReceiving
            .removeDuplicates()
            .sink { [weak self] isReceiving in
                guard let self = self, self.isEnabled, self.rxEnabled else { return }
                if isReceiving && !self.lastRxState {
                    // Check if we should play based on sound scope
                    if self.soundScope == .allTabs || monitor.lastReceiveWasActiveTab {
                        self.playRxSound()
                    }
                }
                self.lastRxState = isReceiving
            }
            .store(in: &cancellables)
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        txPlayerNode = AVAudioPlayerNode()
        rxPlayerNode = AVAudioPlayerNode()

        guard let txPlayerNode = txPlayerNode,
              let rxPlayerNode = rxPlayerNode else { return }

        audioEngine.attach(txPlayerNode)
        audioEngine.attach(rxPlayerNode)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        audioEngine.connect(txPlayerNode, to: audioEngine.mainMixerNode, format: format)
        audioEngine.connect(rxPlayerNode, to: audioEngine.mainMixerNode, format: format)

        // Apply volume setting
        txPlayerNode.volume = volume
        rxPlayerNode.volume = volume

        // Generate the static noise buffers
        txBuffer = generateModemStaticBuffer(format: format, frequency: 2400, duration: 0.08) // Higher pitch for Tx
        rxBuffer = generateModemStaticBuffer(format: format, frequency: 1200, duration: 0.08) // Lower pitch for Rx

        do {
            try audioEngine.start()
        } catch {
            print("[Barc] Failed to start audio engine: \(error)")
        }
    }

    private func stopAudioEngine() {
        txPlayerNode?.stop()
        rxPlayerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        txPlayerNode = nil
        rxPlayerNode = nil
    }

    private func generateModemStaticBuffer(format: AVAudioFormat, frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        guard let floatData = buffer.floatChannelData?[0] else {
            return nil
        }

        // Generate modem-like static: combination of carrier wave + noise + modulation
        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate

            // Base carrier wave (like modem carrier)
            let carrier = sin(2.0 * .pi * frequency * time)

            // Add some harmonics for that characteristic modem sound
            let harmonic1 = sin(2.0 * .pi * frequency * 1.5 * time) * 0.3
            let harmonic2 = sin(2.0 * .pi * frequency * 2.0 * time) * 0.2

            // Add noise component (the static/hiss)
            let noise = Double.random(in: -1...1) * 0.4

            // Frequency modulation for warble effect
            let modulation = sin(2.0 * .pi * 30 * time) * 0.2

            // Combine all components
            var sample = (carrier + harmonic1 + harmonic2) * (1.0 + modulation) + noise

            // Apply envelope (quick attack, quick decay) for click sound
            let envelope = min(1.0, Double(frame) / (sampleRate * 0.01)) *
                          min(1.0, Double(Int(frameCount) - frame) / (sampleRate * 0.02))
            sample *= envelope

            // Reduce overall volume
            sample *= 0.15

            floatData[frame] = Float(sample)
        }

        return buffer
    }

    func playTxSound() {
        guard let txPlayerNode = txPlayerNode,
              let txBuffer = txBuffer,
              audioEngine?.isRunning == true else { return }

        txPlayerNode.scheduleBuffer(txBuffer, at: nil, options: [], completionHandler: nil)
        if !txPlayerNode.isPlaying {
            txPlayerNode.play()
        }
    }

    func playRxSound() {
        guard let rxPlayerNode = rxPlayerNode,
              let rxBuffer = rxBuffer,
              audioEngine?.isRunning == true else { return }

        rxPlayerNode.scheduleBuffer(rxBuffer, at: nil, options: [], completionHandler: nil)
        if !rxPlayerNode.isPlaying {
            rxPlayerNode.play()
        }
    }

    deinit {
        stopAudioEngine()
    }
}
