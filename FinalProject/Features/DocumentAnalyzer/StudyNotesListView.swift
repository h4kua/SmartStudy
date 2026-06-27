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

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: StudySpacing.medium) {
                        // Metadata row
                        HStack(spacing: StudySpacing.small) {
                            if let sub = note.subject {
                                Text(sub)
                                    .font(StudyFont.tiny)
                                    .foregroundStyle(StudyTheme.accent)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(StudyTheme.accentSoft)
                                    .clipShape(Capsule())
                            }
                            Text(note.createdDate, style: .date)
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.tertiaryText)
                            Spacer()
                            Text("\(note.wordCount) words")
                                .font(StudyFont.tiny)
                                .foregroundStyle(StudyTheme.tertiaryText)
                        }

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
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(StudySpacing.large)
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
                        Button("Edit") {
                            editedContent = note.content
                            isEditing = true
                        }
                        .foregroundStyle(StudyTheme.accent)
                    }
                }
            }
        }
    }
}
