import SwiftUI

// MARK: - SubjectManagementView
// Sheet for adding, editing, and deleting subjects.

struct SubjectManagementView: View {
    @EnvironmentObject var store: LearningStore
    @Environment(\.dismiss) private var dismiss

    @State private var showAddSheet   = false
    @State private var editingSubject: Subject? = nil
    @State private var deleteTarget:  Subject? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()

                List {
                    ForEach(store.subjects) { subject in
                        subjectRow(subject)
                            .listRowBackground(StudyTheme.surface)
                            .listRowSeparatorTint(StudyTheme.surfaceStroke)
                    }
                    .onDelete { offsets in
                        offsets.forEach { i in
                            store.deleteSubject(id: store.subjects[i].id)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Manage Subjects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(StudyTheme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingSubject = nil
                        showAddSheet   = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(StudyTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                SubjectEditSheet(subject: editingSubject)
                    .environmentObject(store)
            }
            .sheet(item: $editingSubject) { subject in
                SubjectEditSheet(subject: subject)
                    .environmentObject(store)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func subjectRow(_ subject: Subject) -> some View {
        HStack(spacing: StudySpacing.medium) {
            // Color swatch + emoji
            ZStack {
                Circle()
                    .fill(subject.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(subject.emoji)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(subject.name)
                    .font(StudyFont.body)
                    .foregroundStyle(StudyTheme.primaryText)
                HStack(spacing: 6) {
                    Circle()
                        .fill(subject.color)
                        .frame(width: 8, height: 8)
                    Text(subject.colorHex.uppercased())
                        .font(StudyFont.tiny)
                        .foregroundStyle(StudyTheme.tertiaryText)
                }
            }

            Spacer()

            Button {
                editingSubject = subject
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(StudyTheme.accent.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Subject Edit Sheet

struct SubjectEditSheet: View {
    @EnvironmentObject var store: LearningStore
    @Environment(\.dismiss) private var dismiss

    /// nil = create new, non-nil = edit existing
    let subject: Subject?

    @State private var name:     String = ""
    @State private var colorHex: String = Subject.colorOptions.first ?? "#4A8EFF"
    @State private var emoji:    String = "📚"

    // Popular emojis for subjects
    private let emojiOptions = [
        "📐","⚛️","💻","📖","🏛️","🔬","🎨","🎵","🌍","🏥",
        "⚖️","📊","🧮","✍️","🔭","🧬","💡","🎯","📚","🧠"
    ]

    var isEditing: Bool { subject != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                StudyTheme.backgroundGradient.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: StudySpacing.large) {
                        // Preview
                        previewCard

                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject Name")
                                .font(StudyFont.caption).foregroundStyle(StudyTheme.secondaryText)
                            TextField("e.g. Mathematics", text: $name)
                                .font(StudyFont.body)
                                .foregroundStyle(StudyTheme.primaryText)
                                .padding(StudySpacing.medium)
                                .background(StudyTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
                        }

                        // Color picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Color")
                                .font(StudyFont.caption).foregroundStyle(StudyTheme.secondaryText)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                                ForEach(Subject.colorOptions, id: \.self) { hex in
                                    colorSwatch(hex: hex)
                                }
                            }
                        }

                        // Emoji picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Emoji")
                                .font(StudyFont.caption).foregroundStyle(StudyTheme.secondaryText)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                                ForEach(emojiOptions, id: \.self) { e in
                                    Button { emoji = e } label: {
                                        Text(e)
                                            .font(.system(size: 26))
                                            .frame(width: 50, height: 50)
                                            .background(
                                                Group {
                                                    if emoji == e {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(StudyTheme.accent.opacity(0.2))
                                                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                                .stroke(StudyTheme.accent, lineWidth: 2))
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .fill(StudyTheme.surface2)
                                                    }
                                                }
                                            )
                                    }
                                }
                            }
                        }

                        // Save
                        Button { save() } label: {
                            Text(isEditing ? "Save Changes" : "Add Subject")
                                .font(StudyFont.subtitle)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity).frame(height: 52)
                        }
                        .buttonStyle(PrimaryStudyButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.top, StudySpacing.small)
                    }
                    .padding(StudySpacing.large)
                }
            }
            .navigationTitle(isEditing ? "Edit Subject" : "New Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(StudyTheme.secondaryText)
                }
            }
        }
        .onAppear {
            if let s = subject {
                name     = s.name
                colorHex = s.colorHex
                emoji    = s.emoji
            }
        }
        .preferredColorScheme(.dark)
    }

    private var previewCard: some View {
        HStack(spacing: StudySpacing.medium) {
            ZStack {
                Circle()
                    .fill((Color(hex: colorHex) ?? StudyTheme.accent).opacity(0.2))
                    .frame(width: 48, height: 48)
                Text(emoji.isEmpty ? "📚" : emoji)
                    .font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Subject Name" : name)
                    .font(StudyFont.subtitle)
                    .foregroundStyle(name.isEmpty ? StudyTheme.tertiaryText : StudyTheme.primaryText)
                Circle()
                    .fill(Color(hex: colorHex) ?? StudyTheme.accent)
                    .frame(width: 8, height: 8)
            }
            Spacer()
        }
        .padding(StudySpacing.medium)
        .background(StudyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(StudyTheme.surfaceStroke, lineWidth: 1))
    }

    private func colorSwatch(hex: String) -> some View {
        let color   = Color(hex: hex) ?? StudyTheme.accent
        let selected = colorHex == hex
        return Button { colorHex = hex } label: {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(selected ? .white : .clear, lineWidth: 3)
                        .padding(2)
                )
                .overlay(
                    Circle()
                        .stroke(selected ? color : .clear, lineWidth: 2)
                )
                .shadow(color: selected ? color.opacity(0.5) : .clear, radius: 6)
        }
        .animation(.spring(response: 0.3), value: selected)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let existing = subject {
            var updated         = existing
            updated.name        = trimmed
            updated.colorHex    = colorHex
            updated.emoji       = emoji
            store.updateSubject(updated)
        } else {
            store.addSubject(Subject(name: trimmed, colorHex: colorHex, emoji: emoji))
        }
        dismiss()
    }
}

// MARK: - View Extension helper

extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}
