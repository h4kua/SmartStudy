import SwiftUI
import UniformTypeIdentifiers

struct DocumentAnalyzerView: View {
    @EnvironmentObject var store: LearningStore
    @StateObject private var vm = DocumentAnalyzerViewModel()

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
                    HStack {
                        Text("Content")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.secondaryText)
                            .tracking(0.8)
                        Spacer()
                        Text("\(vm.wordCount) words")
                            .font(StudyFont.tiny)
                            .foregroundStyle(StudyTheme.tertiaryText)
                        Button { vm.showFilePicker = true } label: {
                            Label("Import File", systemImage: "doc.fill")
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

    private var featureHints: some View {
        HStack(spacing: StudySpacing.medium) {
            featureHint(icon: "text.alignleft",      label: "Summary")
            featureHint(icon: "lightbulb",            label: "Key Concepts")
            featureHint(icon: "book.closed",          label: "Definitions")
            featureHint(icon: "questionmark.circle",  label: "Questions")
        }
    }

    private func featureHint(icon: String, label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudyTheme.accent)
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
