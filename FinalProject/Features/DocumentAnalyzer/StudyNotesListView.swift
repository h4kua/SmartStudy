import SwiftUI

struct StudyNotesListView: View {
    @EnvironmentObject var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var selectedNote: StudyNote?
    @State private var noteToDelete: StudyNote?
    @State private var showDeleteAlert = false

    private var filteredNotes: [StudyNote] {
        guard !searchQuery.isEmpty else { return store.studyNotes }
        return store.studyNotes.filter {
            $0.title.localizedCaseInsensitiveContains(searchQuery) ||
            $0.content.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()
                if store.studyNotes.isEmpty {
                    emptyState
                } else {
                    notesList
                }
            }
            .navigationTitle("My Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StudyTheme.accent)
                }
            }
            .searchable(text: $searchQuery, prompt: "Search notes…")
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note)
                    .environmentObject(store)
            }
            .alert("Delete Note?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let n = noteToDelete { store.deleteStudyNote(id: n.id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private var notesList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: StudySpacing.small) {
                ForEach(filteredNotes) { note in
                    noteRow(note)
                }
            }
            .padding(.horizontal, StudySpacing.large)
            .padding(.top, StudySpacing.medium)
            .padding(.bottom, StudySpacing.xxLarge)
        }
    }

    private func noteRow(_ note: StudyNote) -> some View {
        Button { selectedNote = note } label: {
            HStack(alignment: .top, spacing: StudySpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(StudyTheme.accentSoft)
                        .frame(width: 44, height: 44)
                    Image(systemName: "note.text")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(StudyTheme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title)
                        .font(StudyFont.subtitle)
                        .foregroundStyle(StudyTheme.primaryText)
                        .lineLimit(1)
                    Text(note.preview)
                        .font(StudyFont.caption)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .lineLimit(2)
                    HStack(spacing: StudySpacing.small) {
                        Text("\(note.wordCount) words")
                        Text("·")
                        Text(note.createdDate, style: .date)
                        if let sub = note.subject {
                            Text("·")
                            Text(sub)
                                .foregroundStyle(StudyTheme.accent)
                        }
                    }
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.tertiaryText)
                }
                Spacer()
            }
            .padding(StudySpacing.medium)
            .background(StudyTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .contextMenu {
            Button(role: .destructive) {
                noteToDelete = note
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                noteToDelete = note
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: StudySpacing.medium) {
            Image(systemName: "note.text")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(StudyTheme.tertiaryText)
            Text("No Saved Notes")
                .font(StudyFont.cardTitle)
                .foregroundStyle(StudyTheme.primaryText)
            Text("Analyze a document and tap\n\"Save as Note\" to save it here.")
                .font(StudyFont.caption)
                .foregroundStyle(StudyTheme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - NoteDetailView

struct NoteDetailView: View {
    @EnvironmentObject var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    let note: StudyNote

    @State private var editedContent: String = ""
    @State private var isEditing = false
    @State private var showStudySheet = false
    @State private var showDeleteAlert = false

    var readTime: String {
        let minutes = max(1, note.wordCount / 200)
        return "\(minutes) min read"
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                StudyTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: StudySpacing.medium) {

                        // Metadata row
                        HStack(spacing: 8) {
                            if let sub = note.subject {
                                Text(sub)
                                    .font(StudyFont.tiny)
                                    .foregroundStyle(StudyTheme.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(StudyTheme.accentSoft)
                                    .clipShape(Capsule())
                            }
                            Label(readTime, systemImage: "clock")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.tertiaryText)
                            Spacer()
                            Text("\(note.wordCount) words")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.tertiaryText)
                        }

                        Divider().overlay(StudyTheme.surfaceStroke)

                        // Content
                        if isEditing {
                            TextEditor(text: $editedContent)
                                .font(StudyFont.body)
                                .foregroundStyle(StudyTheme.primaryText)
                                .frame(minHeight: 400)
                                .scrollContentBackground(.hidden)
                        } else {
                            Text(note.content)
                                .font(StudyFont.body)
                                .foregroundStyle(StudyTheme.primaryText)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        // Bottom padding so content clears the action bar
                        Spacer().frame(height: 100)
                    }
                    .padding(StudySpacing.large)
                }

                // Sticky study action bar (only when not editing)
                if !isEditing {
                    VStack(spacing: 0) {
                        Divider().overlay(StudyTheme.surfaceStroke)
                        HStack(spacing: StudySpacing.medium) {
                            Button {
                                showStudySheet = true
                            } label: {
                                Label("Quiz me", systemImage: "checkmark.circle.fill")
                                    .font(StudyFont.subtitle)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .buttonStyle(PrimaryStudyButtonStyle())

                            Button {
                                showStudySheet = true
                            } label: {
                                Label("Flashcards", systemImage: "rectangle.on.rectangle.fill")
                                    .font(StudyFont.subtitle)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                            }
                            .buttonStyle(GhostStudyButtonStyle())
                        }
                        .padding(.horizontal, StudySpacing.large)
                        .padding(.vertical, StudySpacing.medium)
                        .background(.ultraThinMaterial)
                    }
                }
            }
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StudyTheme.accent)
                }
                ToolbarItem(placement: .primaryAction) {
                    if isEditing {
                        Button("Save") {
                            var updated = note
                            updated.content = editedContent
                            store.updateStudyNote(updated)
                            isEditing = false
                        }
                        .foregroundStyle(StudyTheme.success)
                    } else {
                        Menu {
                            Button {
                                editedContent = note.content
                                isEditing = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                let fixed = DocumentAnalyzerViewModel.repairAndClean(note.content)
                                var updated = note
                                updated.content = fixed
                                store.updateStudyNote(updated)
                            } label: {
                                Label("Repair Text", systemImage: "wand.and.stars")
                            }
                            Divider()
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete Note", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundStyle(StudyTheme.accent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showStudySheet) {
            NoteStudySheet(note: note)
                .environmentObject(store)
        }
        .alert("Delete Note?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                store.deleteStudyNote(id: note.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(note.title)\" will be permanently deleted.")
        }
    }
}

// MARK: - NoteStudySheet

struct NoteStudySheet: View {
    @EnvironmentObject var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    let note: StudyNote

    @State private var mode: StudyMode = .quiz
    @State private var difficulty: QuizQuestion.Difficulty = .intermediate
    @State private var quizCount  = 10
    @State private var cardCount  = 15
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    enum StudyMode { case quiz, flashcards }

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: StudySpacing.large) {

                        // Header
                        VStack(spacing: 8) {
                            ZStack {
                                Circle().fill(StudyTheme.accentSoft).frame(width: 64, height: 64)
                                Image(systemName: mode == .quiz ? "checkmark.circle.fill" : "rectangle.on.rectangle.fill")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(StudyTheme.accent)
                            }
                            Text("Study from Note")
                                .font(StudyFont.cardTitle)
                                .foregroundStyle(StudyTheme.primaryText)
                            Text(note.title)
                                .font(StudyFont.caption)
                                .foregroundStyle(StudyTheme.secondaryText)
                                .lineLimit(1)
                        }
                        .padding(.top, StudySpacing.medium)

                        // Mode toggle
                        HStack(spacing: 0) {
                            ForEach([StudyMode.quiz, .flashcards], id: \.self) { m in
                                let selected = mode == m
                                Button { withAnimation(.spring(response: 0.3)) { mode = m } } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: m == .quiz ? "checkmark.circle" : "rectangle.on.rectangle")
                                            .font(.system(size: 13, weight: .semibold))
                                        Text(m == .quiz ? "Quiz" : "Flashcards")
                                            .font(StudyFont.caption).fontWeight(.semibold)
                                    }
                                    .foregroundStyle(selected ? .white : StudyTheme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(selected ? StudyTheme.accent : .clear)
                                    )
                                }
                            }
                        }
                        .padding(4)
                        .background(StudyTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // Settings
                        if mode == .quiz {
                            quizSettings
                        } else {
                            flashcardSettings
                        }

                        // Success banner
                        if let msg = successMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(StudyTheme.success)
                                Text(msg)
                                    .font(StudyFont.caption)
                                    .foregroundStyle(StudyTheme.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(StudySpacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(StudyTheme.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // Error
                        if let err = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(StudyTheme.danger)
                                Text(err)
                                    .font(StudyFont.caption)
                                    .foregroundStyle(StudyTheme.danger)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(StudySpacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(StudyTheme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        // Generate button
                        Button {
                            Task { await generate() }
                        } label: {
                            if isGenerating {
                                HStack(spacing: 8) {
                                    ProgressView().tint(.white)
                                    Text("Generating…")
                                }
                                .font(StudyFont.subtitle)
                                .frame(maxWidth: .infinity).frame(height: 52)
                            } else {
                                Text(mode == .quiz ? "Generate Quiz" : "Generate Flashcards")
                                    .font(StudyFont.subtitle)
                                    .frame(maxWidth: .infinity).frame(height: 52)
                            }
                        }
                        .buttonStyle(PrimaryStudyButtonStyle())
                        .disabled(isGenerating)

                        if successMessage != nil {
                            Button("Done") { dismiss() }
                                .font(StudyFont.subtitle)
                                .foregroundStyle(StudyTheme.accent)
                        }
                    }
                    .padding(.horizontal, StudySpacing.large)
                    .padding(.bottom, StudySpacing.xxLarge)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(StudyTheme.secondaryText)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Settings sections

    private var quizSettings: some View {
        VStack(spacing: StudySpacing.medium) {
            settingRow("Difficulty") {
                HStack(spacing: 2) {
                    ForEach(QuizQuestion.Difficulty.allCases, id: \.rawValue) { d in
                        Button { difficulty = d } label: {
                            Text(d.label)
                                .font(StudyFont.tiny)
                                .foregroundStyle(difficulty == d ? .white : StudyTheme.secondaryText)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(Group {
                                    if difficulty == d {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous).fill(d.color)
                                    }
                                })
                        }
                    }
                }
                .padding(4)
                .background(StudyTheme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            settingRow("Questions") {
                HStack(spacing: StudySpacing.small) {
                    ForEach([5, 10, 15], id: \.self) { n in
                        Button { quizCount = n } label: {
                            Text("\(n)")
                                .font(StudyFont.subtitle)
                                .foregroundStyle(quizCount == n ? .white : StudyTheme.secondaryText)
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(quizCount == n ? StudyTheme.accent : StudyTheme.surface2)
                                )
                        }
                    }
                }
            }
        }
    }

    private var flashcardSettings: some View {
        settingRow("Number of Cards") {
            HStack(spacing: StudySpacing.small) {
                ForEach([10, 15, 20, 30], id: \.self) { n in
                    Button { cardCount = n } label: {
                        Text("\(n)")
                            .font(StudyFont.subtitle)
                            .foregroundStyle(cardCount == n ? .white : StudyTheme.secondaryText)
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(cardCount == n ? StudyTheme.accent : StudyTheme.surface2)
                            )
                    }
                }
            }
        }
    }

    private func settingRow<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: StudySpacing.small) {
            Text(label.uppercased())
                .font(StudyFont.tiny).foregroundStyle(StudyTheme.secondaryText).tracking(0.8)
            content()
        }
    }

    // MARK: - Generate

    @MainActor
    private func generate() async {
        isGenerating  = true
        errorMessage  = nil
        successMessage = nil
        let context = note.content.isEmpty ? nil : note.content
        do {
            if mode == .quiz {
                let questions = try await GroqService.shared.generateQuiz(
                    topic: note.title,
                    difficulty: difficulty,
                    count: quizCount,
                    context: context
                )
                guard !questions.isEmpty else { throw GroqError.emptyResponse }
                let session = QuizSession(
                    title: note.title, subject: note.subject,
                    difficulty: difficulty, questions: questions,
                    userAnswers: Array(repeating: -1, count: questions.count)
                )
                store.addQuizSession(session)
                successMessage = "\(questions.count)-question quiz created. Go to Learn → Quizzes to take it."
            } else {
                let topic = "\(note.title). Key concepts: \(note.content.prefix(300))"
                let cards = try await GroqService.shared.generateFlashcards(topic: topic, count: cardCount)
                guard !cards.isEmpty else { throw GroqError.emptyResponse }
                let deck = FlashcardDeck(title: note.title, subject: note.subject, cards: cards)
                store.addFlashcardDeck(deck)
                successMessage = "\(cards.count) flashcards created. Go to Learn → Flashcards to review."
            }
        } catch {
            errorMessage = (error as? GroqError)?.errorDescription ?? error.localizedDescription
        }
        isGenerating = false
    }
}
