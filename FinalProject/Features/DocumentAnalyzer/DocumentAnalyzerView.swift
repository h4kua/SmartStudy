import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentAnalyzerView: View {
    @EnvironmentObject var store: LearningStore
    @StateObject private var vm = DocumentAnalyzerViewModel()
    @State private var showNotesSheet = false
    @State private var showSolveSheet = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                StudyTheme.backgroundGradient.ignoresSafeArea()

                if vm.result == nil {
                    inputScrollView
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    resultsScrollView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                }

                // Success banner
                if let banner = vm.bannerMessage {
                    successBanner(banner)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.bannerMessage)
            // BUG FIX: previous Task was never cancelled — if a new banner appeared
            // while sleeping, the old Task would prematurely clear the new banner.
            .onChange(of: vm.bannerMessage) { msg in
                guard msg != nil else { return }
                let captured = msg
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    // Only clear if the banner hasn't been replaced by a newer one
                    if vm.bannerMessage == captured {
                        vm.bannerMessage = nil
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showGenerateSheet) {
            generateSheet
        }
        .sheet(isPresented: $showNotesSheet) {
            StudyNotesListView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showSolveSheet) {
            SolveProblemSheet()
        }
        // Note Scanner — image picker sheet
        .sheet(isPresented: $vm.showScanPicker) {
            ImagePickerView(sourceType: vm.scanSourceType) { image in
                Task { await vm.scanImage(image) }
            }
        }
        // Scan source action sheet
        .confirmationDialog("Scan Notes", isPresented: $vm.showScanMenu, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    vm.scanSourceType = .camera
                    vm.showScanPicker = true
                }
            }
            Button("Choose from Photo Library") {
                vm.scanSourceType = .photoLibrary
                vm.showScanPicker = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Take or choose a photo of your notes to extract text automatically.")
        }
        .fileImporter(
            isPresented: $vm.showFilePicker,
            allowedContentTypes: [.plainText, .pdf],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { vm.loadFile(url: url) }
            case .failure(let error):
                vm.errorMessage = "Could not open file: \(error.localizedDescription)"
            }
        }
    }

    // =========================================================
    // MARK: - Input view
    // =========================================================

    private var inputScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: StudySpacing.large) {
                pageHeader(subtitle: "Analyze your study materials")

                // Scan & Solve entry card
                Button { showSolveSheet = true } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(StudyTheme.warning.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(StudyTheme.warning)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan & Solve")
                                .font(StudyFont.subtitle)
                                .foregroundStyle(StudyTheme.primaryText)
                            Text("Photo a question from your textbook — AI solves it step by step")
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(StudyTheme.tertiaryText)
                    }
                    .padding(StudySpacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(StudyTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(StudyTheme.warning.opacity(0.4), lineWidth: 1.5)
                            )
                    )
                }

                // Title field
                VStack(alignment: .leading, spacing: StudySpacing.small) {
                    Text("Document Title")
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .tracking(0.8)
                    TextField("e.g. Chapter 3 — Cell Biology", text: $vm.documentTitle)
                        .font(StudyFont.body)
                        .foregroundStyle(StudyTheme.primaryText)
                        .padding(StudySpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(StudyTheme.surface2)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
                        )
                }

                // Text editor
                VStack(alignment: .leading, spacing: StudySpacing.small) {
                    HStack(spacing: 6) {
                        Text("Content")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .tracking(0.8)
                        Spacer()
                        Text("\(vm.wordCount) words")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.tertiaryText)

                        // ── Scan Notes button (NEW) ──────────────────────
                        Button { vm.showScanMenu = true } label: {
                            if vm.isScanning {
                                HStack(spacing: 4) {
                                    ProgressView().scaleEffect(0.7).tint(StudyTheme.success)
                                    Text("Scanning…").font(StudyFont.tiny)
                                }
                                .foregroundStyle(StudyTheme.success)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(StudyTheme.success.opacity(0.12), in: Capsule())
                            } else {
                                Label("Scan Notes", systemImage: "camera.viewfinder")
                                    .font(StudyFont.tiny)
                                    .foregroundStyle(StudyTheme.success)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(StudyTheme.success.opacity(0.12), in: Capsule())
                            }
                        }
                        .disabled(vm.isScanning)

                        // ── Import File button ────────────────────────────
                        Button { vm.showFilePicker = true } label: {
                            Label("File", systemImage: "doc.fill")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(StudyTheme.accentSoft, in: Capsule())
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        if vm.inputText.isEmpty {
                            Text("Paste your lecture notes, academic paper, or study material here...")
                                .font(StudyFont.body)
                                .foregroundStyle(StudyTheme.tertiaryText)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 10)
                        }
                        TextEditor(text: $vm.inputText)
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.primaryText)
                            .frame(minHeight: 220)
                            .scrollContentBackground(.hidden)
                    }
                    .padding(StudySpacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(StudyTheme.surface2)
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
                    )
                }

                // Error message
                if let err = vm.errorMessage {
                    errorCard(err)
                }

                // My Notes quick-access
                if !store.studyNotes.isEmpty {
                    notesPreviewSection
                }

                // Analyze button
                Button {
                    Task { await vm.analyze(store: store) }
                } label: {
                    if vm.isAnalyzing {
                        HStack(spacing: StudySpacing.small) {
                            ProgressView().tint(.white)
                            Text("Analyzing...")
                        }
                        .font(StudyFont.subtitle)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    } else {
                        HStack(spacing: StudySpacing.small) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Analyze Document")
                                .font(StudyFont.subtitle)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                    }
                }
                .buttonStyle(PrimaryStudyButtonStyle())
                .disabled(vm.isAnalyzing || vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                featureHints
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.bottom, StudySpacing.xxLarge)
        }
    }

    private var notesPreviewSection: some View {
        VStack(alignment: .leading, spacing: StudySpacing.small) {
            HStack {
                Text("My Notes")
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Spacer()
                Button("See All") { showNotesSheet = true }
                    .font(StudyFont.caption)
                    .foregroundStyle(StudyTheme.accent)
            }
            ForEach(store.studyNotes.prefix(2)) { note in
                HStack(alignment: .top, spacing: StudySpacing.small) {
                    Image(systemName: "note.text")
                        .font(.system(size: 13))
                        .foregroundStyle(StudyTheme.accent)
                        .padding(8)
                        .background(StudyTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(note.title)
                            .font(StudyFont.caption)
                            .foregroundStyle(StudyTheme.primaryText)
                            .lineLimit(1)
                        Text(note.preview)
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.tertiaryText)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(StudySpacing.small)
                .background(StudyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var featureHints: some View {
        HStack(spacing: StudySpacing.medium) {
            featureHint(icon: "camera.viewfinder",    label: "Scan\nNotes",   color: StudyTheme.success)
            featureHint(icon: "text.alignleft",       label: "AI\nSummary",   color: StudyTheme.accent)
            featureHint(icon: "checkmark.circle",     label: "Quiz\nGen",     color: StudyTheme.shortBreakColor)
            featureHint(icon: "rectangle.on.rectangle", label: "Flashcard\nGen", color: StudyTheme.longBreakColor)
        }
    }

    private func featureHint(icon: String, label: String, color: Color = StudyTheme.accent) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // =========================================================
    // MARK: - Results view
    // =========================================================

    private var resultsScrollView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: StudySpacing.large) {
                // Header with "New Analysis" button
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Documents")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(StudyTheme.primaryText)
                        Text(vm.result?.title ?? "Analysis complete")
                            .font(StudyFont.caption)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button {
                        withAnimation { vm.reset() }
                    } label: {
                        Label("New", systemImage: "plus")
                            .font(StudyFont.caption)
                            .foregroundStyle(StudyTheme.accent)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(StudyTheme.accentSoft)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, StudySpacing.large)

                if let doc = vm.result {
                    summaryCard(doc)
                    keyConceptsCard(doc)
                    if !doc.definitions.isEmpty { definitionsCard(doc) }
                    if !doc.suggestedQuestions.isEmpty { questionsCard(doc) }
                    generateActionsRow
                    saveAsNoteButton
                }

                if let err = vm.errorMessage {
                    errorCard(err)
                }
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.bottom, StudySpacing.xxLarge)
        }
    }

    // --- Summary ---

    private func summaryCard(_ doc: AnalyzedDocument) -> some View {
        StudyCard(title: "Summary") {
            Text(doc.summary)
                .font(StudyFont.body)
                .foregroundStyle(StudyTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // --- Key Concepts ---

    private func keyConceptsCard(_ doc: AnalyzedDocument) -> some View {
        StudyCard(title: "Key Concepts") {
            VStack(alignment: .leading, spacing: StudySpacing.small) {
                ForEach(doc.keyConcepts, id: \.self) { concept in
                    HStack(spacing: StudySpacing.small) {
                        Circle()
                            .fill(StudyTheme.accent)
                            .frame(width: 6, height: 6)
                        Text(concept)
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.primaryText)
                    }
                }
            }
        }
    }

    // --- Definitions ---

    // BUG FIX: definitions were sorted twice per render (once for ForEach, once for separator check).
    // Dictionary ordering is non-deterministic; sorting once avoids inconsistency and wasted work.
    private func definitionsCard(_ doc: AnalyzedDocument) -> some View {
        let sortedDefs = doc.definitions.sorted(by: { $0.key < $1.key })
        return StudyCard(title: "Definitions") {
            VStack(alignment: .leading, spacing: StudySpacing.medium) {
                ForEach(Array(sortedDefs.enumerated()), id: \.offset) { idx, entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.key)
                            .font(StudyFont.subtitle)
                            .foregroundStyle(StudyTheme.accent)
                        Text(entry.value)
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if idx < sortedDefs.count - 1 {
                        Rectangle().fill(StudyTheme.surfaceStroke).frame(height: 1)
                    }
                }
            }
        }
    }

    // --- Suggested Questions ---

    private func questionsCard(_ doc: AnalyzedDocument) -> some View {
        StudyCard(title: "Suggested Questions") {
            VStack(alignment: .leading, spacing: StudySpacing.small) {
                ForEach(Array(doc.suggestedQuestions.enumerated()), id: \.offset) { i, q in
                    HStack(alignment: .top, spacing: StudySpacing.small) {
                        Text("\(i + 1).")
                            .font(StudyFont.subtitle)
                            .foregroundStyle(StudyTheme.accent)
                            .frame(width: 22, alignment: .leading)
                        Text(q)
                            .font(StudyFont.body)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // --- Save as Note ---

    private var saveAsNoteButton: some View {
        Button {
            vm.saveAsNote(store: store)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                Text("Save as Note")
                    .font(StudyFont.subtitle)
            }
            .frame(maxWidth: .infinity).frame(height: 52)
        }
        .buttonStyle(GhostStudyButtonStyle())
        .disabled(vm.isGenerating)
    }

    // --- Generate action buttons ---

    private var generateActionsRow: some View {
        VStack(spacing: StudySpacing.small) {
            Button {
                vm.generateMode = .quiz
                vm.showGenerateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                    Text("Generate Quiz")
                        .font(StudyFont.subtitle)
                }
                .frame(maxWidth: .infinity).frame(height: 52)
            }
            .buttonStyle(PrimaryStudyButtonStyle())
            .disabled(vm.isGenerating)

            Button {
                vm.generateMode = .flashcards
                vm.showGenerateSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.on.rectangle")
                    Text("Generate Flashcards")
                        .font(StudyFont.subtitle)
                }
                .frame(maxWidth: .infinity).frame(height: 52)
            }
            .buttonStyle(GhostStudyButtonStyle())
            .disabled(vm.isGenerating)
        }
    }

    // =========================================================
    // MARK: - Generate sheet
    // =========================================================

    private var generateSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.large) {

                    // Icon + title
                    VStack(spacing: StudySpacing.small) {
                        ZStack {
                            Circle().fill(StudyTheme.accentSoft).frame(width: 60, height: 60)
                            Image(systemName: vm.generateMode == .quiz
                                  ? "checkmark.circle" : "rectangle.on.rectangle")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(StudyTheme.accent)
                        }
                        Text(vm.generateMode == .quiz ? "Quiz Settings" : "Flashcard Settings")
                            .font(StudyFont.cardTitle)
                            .foregroundStyle(StudyTheme.primaryText)
                    }
                    .padding(.top, StudySpacing.medium)

                    if vm.generateMode == .quiz {
                        quizSettingsSection
                    } else {
                        flashcardSettingsSection
                    }

                    // Generate button
                    Button {
                        Task {
                            if vm.generateMode == .quiz {
                                await vm.generateQuiz(store: store)
                            } else {
                                await vm.generateFlashcards(store: store)
                            }
                        }
                    } label: {
                        if vm.isGenerating {
                            HStack(spacing: StudySpacing.small) {
                                ProgressView().tint(.white)
                                Text("Generating...")
                            }
                            .font(StudyFont.subtitle)
                            .frame(maxWidth: .infinity).frame(height: 52)
                        } else {
                            Text("Generate")
                                .font(StudyFont.subtitle)
                                .frame(maxWidth: .infinity).frame(height: 52)
                        }
                    }
                    .buttonStyle(PrimaryStudyButtonStyle())
                    .disabled(vm.isGenerating)
                    .padding(.horizontal, StudySpacing.large)

                    if let err = vm.errorMessage {
                        errorCard(err)
                            .padding(.horizontal, StudySpacing.large)
                    }

                    Spacer()
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.showGenerateSheet = false }
                        .foregroundStyle(StudyTheme.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var quizSettingsSection: some View {
        VStack(spacing: StudySpacing.medium) {
            // Difficulty
            settingRow(label: "Difficulty") {
                HStack(spacing: 2) {
                    ForEach(QuizQuestion.Difficulty.allCases, id: \.rawValue) { diff in
                        Button {
                            vm.quizDifficulty = diff
                        } label: {
                            Text(diff.label)
                                .font(StudyFont.tiny)
                                .foregroundStyle(vm.quizDifficulty == diff ? .white : StudyTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    Group {
                                        if vm.quizDifficulty == diff {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(diff.color)
                                        }
                                    }
                                )
                        }
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(StudyTheme.surface2))
            }

            // Question count
            settingRow(label: "Questions") {
                HStack(spacing: StudySpacing.small) {
                    ForEach([5, 10, 15], id: \.self) { count in
                        Button { vm.quizCount = count } label: {
                            Text("\(count)")
                                .font(StudyFont.subtitle)
                                .foregroundStyle(vm.quizCount == count ? .white : StudyTheme.secondaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(vm.quizCount == count ? StudyTheme.accent : StudyTheme.surface2)
                                )
                        }
                    }
                }
            }
        }
    }

    private var flashcardSettingsSection: some View {
        settingRow(label: "Number of Cards") {
            HStack(spacing: StudySpacing.small) {
                ForEach([10, 15, 20, 30], id: \.self) { count in
                    Button { vm.flashcardCount = count } label: {
                        Text("\(count)")
                            .font(StudyFont.subtitle)
                            .foregroundStyle(vm.flashcardCount == count ? .white : StudyTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(vm.flashcardCount == count ? StudyTheme.accent : StudyTheme.surface2)
                            )
                    }
                }
            }
        }
    }

    // =========================================================
    // MARK: - Shared helpers
    // =========================================================

    private func pageHeader(subtitle: String) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Documents")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(StudyTheme.primaryText)
                Text(subtitle)
                    .font(StudyFont.caption)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()
        }
        .padding(.top, StudySpacing.large)
    }

    private func settingRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: StudySpacing.small) {
            Text(label.uppercased())
                .font(StudyFont.tiny)
                .foregroundStyle(StudyTheme.secondaryText)
                .tracking(0.8)
            content()
        }
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: StudySpacing.small) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(StudyTheme.danger)
            Text(message)
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(StudySpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(StudyTheme.danger.opacity(0.10))
        )
    }

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: StudySpacing.small) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text(message)
                .font(StudyFont.caption)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, StudySpacing.large)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(StudyTheme.success)
                .shadow(color: StudyTheme.success.opacity(0.4), radius: 12, y: 4)
        )
        .padding(.horizontal, StudySpacing.large)
    }
}

// MARK: - Scan & Solve Sheet

struct SolveProblemSheet: View {
    @StateObject private var vm = SolveProblemViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showFullText = false

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: StudySpacing.large) {
                        if vm.answer != nil {
                            resultView
                        } else if vm.capturedImage != nil {
                            processingView
                        } else {
                            idleView
                        }
                    }
                    .padding(StudySpacing.large)
                    .padding(.bottom, StudySpacing.xxLarge)
                }
            }
            .navigationTitle("Scan & Solve")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StudyTheme.secondaryText)
                }
                if vm.answer != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("New Problem") { withAnimation { vm.reset() } }
                            .foregroundStyle(StudyTheme.warning)
                    }
                }
            }
        }
        .sheet(isPresented: $vm.showImagePicker) {
            ImagePickerView(sourceType: vm.sourceType) { image in
                Task { await vm.scanAndSolve(image) }
            }
        }
    }

    // MARK: - Idle (no photo yet)

    private var idleView: some View {
        VStack(spacing: StudySpacing.xLarge) {
            VStack(spacing: 12) {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(StudyTheme.warning)
                    .padding(.top, StudySpacing.xLarge)
                Text("Point camera at a question")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(StudyTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text("Take a photo of any question from your textbook, exam paper, or handwritten notes — the AI will solve it step by step.")
                    .font(StudyFont.body)
                    .foregroundStyle(StudyTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: StudySpacing.medium) {
                // Primary — big camera button
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        vm.sourceType = .camera
                        vm.showImagePicker = true
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 36, weight: .semibold))
                            Text("Take Photo")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("Point camera at a question")
                                .font(StudyFont.caption)
                                .opacity(0.82)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(StudyTheme.warning)
                                .shadow(color: StudyTheme.warning.opacity(0.45), radius: 16, y: 6)
                        )
                    }
                }

                // Secondary — photo library
                Button {
                    vm.sourceType = .photoLibrary
                    vm.showImagePicker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.fill")
                            .font(.system(size: 20))
                        Text("Choose from Photos")
                            .font(StudyFont.subtitle)
                    }
                    .foregroundStyle(StudyTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(StudyTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(StudyTheme.surfaceStroke, lineWidth: 1)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                tipRow(icon: "sun.max.fill",    text: "Use good lighting for best results")
                tipRow(icon: "textformat",      text: "Works with printed and handwritten text")
                tipRow(icon: "globe",           text: "Supports English and Indonesian")
                tipRow(icon: "function",        text: "Handles math, science, and text questions")
            }
            .padding(StudySpacing.medium)
            .background(StudyTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Processing (scanning / solving)

    private var processingView: some View {
        VStack(spacing: StudySpacing.large) {
            if let img = vm.capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            }

            if vm.isScanning {
                statusCard(title: "Reading text...", subtitle: "On-device OCR — your photo never leaves the device")
            } else if vm.isSolving {
                statusCard(title: "Solving...", subtitle: "AI is working through the problem step by step")

                if !vm.detectedText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Detected text")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .tracking(0.8)
                        Text(vm.detectedText)
                            .font(StudyFont.caption)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .lineLimit(5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(StudySpacing.medium)
                    .background(StudyTheme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }

            if let error = vm.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(StudyTheme.danger)
                    Text(error)
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(StudySpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(StudyTheme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button("Try Again") { withAnimation { vm.reset() } }
                    .buttonStyle(PrimaryStudyButtonStyle())
            }
        }
    }

    // MARK: - Result

    private var resultView: some View {
        VStack(spacing: StudySpacing.large) {
            // Header row: thumbnail + word count
            if let img = vm.capturedImage {
                HStack(spacing: 12) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Problem solved")
                            .font(StudyFont.subtitle)
                            .foregroundStyle(StudyTheme.primaryText)
                        Text("\(vm.detectedText.split(separator: " ").count) words detected")
                            .font(StudyFont.caption)
                            .foregroundStyle(StudyTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(StudyTheme.success)
                }
                .padding(StudySpacing.medium)
                .background(StudyTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // Detected question (collapsible)
            if !vm.detectedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.spring(response: 0.3)) { showFullText.toggle() }
                    } label: {
                        HStack {
                            Text("Detected Question")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.secondaryText)
                                .tracking(0.8)
                            Spacer()
                            Image(systemName: showFullText ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(StudyTheme.tertiaryText)
                        }
                    }
                    if showFullText {
                        Text(vm.detectedText)
                            .font(StudyFont.caption)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(StudySpacing.medium)
                .background(StudyTheme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .animation(.spring(response: 0.3), value: showFullText)
            }

            // AI solution
            if let ans = vm.answer {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.fill")
                            .foregroundStyle(StudyTheme.warning)
                        Text("AI Solution")
                            .font(StudyFont.subtitle)
                            .foregroundStyle(StudyTheme.primaryText)
                    }
                    Text(ans)
                        .font(StudyFont.body)
                        .foregroundStyle(StudyTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(5)
                }
                .padding(StudySpacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(StudyTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(StudyTheme.warning.opacity(0.4), lineWidth: 1.5)
                        )
                )
            }
        }
    }

    // MARK: - Helpers

    private func statusCard(title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ProgressView()
                .tint(StudyTheme.warning)
                .scaleEffect(1.2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Text(subtitle)
                    .font(StudyFont.caption)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()
        }
        .padding(StudySpacing.medium)
        .background(StudyTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(StudyTheme.warning.opacity(0.85))
                .frame(width: 18)
            Text(text)
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.secondaryText)
        }
    }
}
