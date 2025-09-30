import SwiftUI
import Foundation
import ApplicationServices
import AVFoundation
import AppKit

struct OnboardingStep {
    let title: String
    let description: String
    let imageName: String
    let buttonText: String
    let source: String?
    let action: ((@escaping (Double) -> Void) -> Void)?
    let skipCondition: (() -> Bool)?
    let progressBar: Bool

    init(
        title: String,
        description: String,
        imageName: String,
        buttonText: String,
        source: String? = nil,
        action: ((@escaping (Double) -> Void) -> Void)? = nil,
        skipCondition: (() -> Bool)? = nil,
        progressBar: Bool = false
    ) {
        self.title = title
        self.description = description
        self.imageName = imageName
        self.buttonText = buttonText
        self.source = source
        self.action = action
        self.skipCondition = skipCondition
        self.progressBar = progressBar
    }
}

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = SettingsStore.shared
    @State private var currentStepIndex = 0
    @State private var stepProgress: Double = 0

    private static func downloadProgressToStepProgress(downloadProgress: Double) -> Double {
        if downloadProgress > 0.8 {
            return 0.8
        } else if downloadProgress < 0.01 {
            return 0.01
        } else {
            return downloadProgress
        }
    }

    private let allSteps = [
        OnboardingStep(
            title: "Welcome to DeepFind",
            description: "Let's set up the essential permissions and preferences so DeepFind works smoothly.",
            imageName: "waveform.circle.fill",
            buttonText: "Next",
            skipCondition: nil
        ),
        OnboardingStep(
            title: "Move to Applications",
            description: """
            1. Click "Open Applications Folder"
            2. Drag DeepFind into the Applications folder
            3. Launch the app from the Applications folder

            This ensures proper updates and reliable functionality.
            """,
            imageName: "folder.badge.plus",
            buttonText: "Open Applications Folder",
            action: { progress in
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                task.arguments = ["/Applications"]
                try? task.run()
            },
            skipCondition: {
                FileManager.default.fileExists(atPath: DeepFindAppDir)
            }
        ),
        OnboardingStep(
            title: "Download LLM Model",
            description: """
            Required for:
            • AI-powered question answering about your documents
            • Natural language chat with your document content

            Click "Download" to download the model.
            """,
            imageName: "brain.head.profile",
            buttonText: "Download",
            source: ModelStorage.shared.getModelFilesUrl(modelID: CurrentLLMModelRepo + "/" + CurrentLLMModelName, subfolder: ""),
            action: { progress in
                Task {
                    let modelID = CurrentLLMModelRepo + "/" + CurrentLLMModelName
                    do {
                        let _ = try await ModelStorage.shared.downloadModel(modelRepo: modelID, modelName: "", progress: { downloadProgress in
                            Logger.log("Downloading LLM model: \(downloadProgress)", log: Logger.general)
                            progress(OnboardingView.downloadProgressToStepProgress(downloadProgress: downloadProgress))
                        })

                        try await ModelStorage.shared.preLoadModel(modelRepo: modelID, modelName: "")
                        progress(1.0)
                    } catch {
                        Logger.log("Failed to download LLM model: \(error)", log: Logger.general, type: .error)
                        do {
                            try ModelStorage.shared.deleteModel(modelRepo: modelID, modelName: "")
                        } catch {
                            Logger.log("Failed to delete LLM model: \(error)", log: Logger.general, type: .error)
                        }
                    }
                }
            },
            skipCondition: {
                ModelStorage.shared.modelExists(modelRepo: CurrentLLMModelRepo + "/" + CurrentLLMModelName, modelName: "") &&
                ModelStorage.shared.isModelLoaded(modelRepo: CurrentLLMModelRepo + "/" + CurrentLLMModelName, modelName: "")
            },
            progressBar: true
        ),
        OnboardingStep(
            title: "You're All Set!",
            description: """
            Quick Start:
            • Launch the app from the Applications folder
            • Click "New Index" in the sidebar
            • Select a folder containing your documents
            • Wait for indexing to complete (progress shown in sidebar)
            • Click on your index to start a chat
            • Ask questions about your documents and get AI-powered answers

            Access settings from DeepFind → Settings in the menu bar.
            """,
            imageName: "checkmark.circle.fill",
            buttonText: "Get Started",
            skipCondition: nil
        )
    ]


    private func completeOnboarding() {
        settings.hasCompletedOnboarding = true

        if !GenericHelper.isDebug() && !GenericHelper.isLocalRun() {
            Logger.log("Relaunching app", log: Logger.general)
            do {
                try GenericHelper.launchApp(appPath: GenericHelper.getAppLocation())
                GenericHelper.terminateApp()
            } catch {
                Logger.log("Error launching app: \(error)", log: Logger.general, type: .error)
            }
        }

        dismiss()
    }

    var body: some View {
        VStack(spacing: 30) {
            var activeSteps = allSteps.filter { step in
                !(step.skipCondition?() ?? false)
            }

            // Progress indicator
            HStack {
                ForEach(0..<activeSteps.count, id: \.self) { index in
                    Circle()
                        .fill(currentStepIndex >= index ? Color.accentColor : Color.white.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            // Current step content
            VStack(spacing: 20) {
                if currentStepIndex >= 0 && currentStepIndex < activeSteps.count {
                    let currentStep = activeSteps[currentStepIndex]
                    Image(systemName: currentStep.imageName)
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    Text(currentStep.title)
                        .font(.title)
                        .bold()
                        .foregroundColor(.white)

                    VStack(alignment: .center, spacing: 8) {
                        // Main description
                        Text(currentStep.description)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                        
                        // Source URL section (only if source exists)
                        if let source = currentStep.source, !source.isEmpty {
                            VStack(spacing: 4) {
                                Text("Source:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    if let nsUrl = URL(string: source) {
                                        NSWorkspace.shared.open(nsUrl)
                                    }
                                }) {
                                    Text(source)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .underline()
                                        .lineLimit(nil)
                                        .multilineTextAlignment(.center)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 10)
                            }
                            .padding(.top, 4)
                        }
                    }


                    if let action = currentStep.action {
                        if !(currentStep.skipCondition?() ?? false) {
                            let progressCallback = { (progress: Double) in
                                Logger.log("Progress: \(progress)", log: Logger.general)
                                DispatchQueue.main.async {
                                    stepProgress = progress
                                }
                            }
                            if currentStep.progressBar {
                                VStack(spacing: 8) {
                                    ProgressView(value: stepProgress)
                                        .progressViewStyle(.linear)
                                        .frame(width: 200)

                                    let status = stepProgress < 0.8 ? "Downloading... \(Int(stepProgress * 100))%" : "Compiling... \(Int(stepProgress * 100))%"
                                    Text(status)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                            }
                            Button(currentStep.buttonText) {
                                stepProgress = 0.01
                                action(progressCallback)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 10)
                            .disabled(stepProgress > 0.0 && stepProgress < 1.0)
                        } else {
                            Text("Completed")
                                .foregroundColor(.green)
                                .padding(.top, 10)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation buttons
            HStack {
                if currentStepIndex > 0 {
                    Button("Back") {
                        withAnimation {
                            if currentStepIndex > 0 {
                                currentStepIndex -= 1
                                stepProgress = 0
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(stepProgress > 0.0 && stepProgress < 1.0)
                }

                Spacer()

                if currentStepIndex >= 0 && currentStepIndex < activeSteps.count - 1 {
                    Button("Next") {
                        withAnimation {
                            if currentStepIndex >= 0 && currentStepIndex < activeSteps.count - 1 {
                                currentStepIndex += 1
                                stepProgress = 0
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(stepProgress > 0.0 && stepProgress < 1.0)
                } else {
                    Button("Get Started") {
                        stepProgress = 0
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(width: 600, height: 500)
        .background(Color.black)
    }
}
