import SwiftUI

@MainActor
final class SubjectsViewModel: ObservableObject {
    @Published var showAddSheet = false
    @Published var editingSubject: Subject? = nil

    // Draft for add/edit
    @Published var draftName = ""
    @Published var draftEmoji = "📚"
    @Published var draftColorHex = Subject.colorOptions[0]

    func startAdd() {
        draftName = ""
        draftEmoji = "📚"
        draftColorHex = Subject.colorOptions[0]
        showAddSheet = true
    }

    func startEdit(_ subject: Subject) {
        draftName = subject.name
        draftEmoji = subject.emoji
        draftColorHex = subject.colorHex
        editingSubject = subject
        showAddSheet = true
    }

    func saveToStore(_ store: StudyStore) {
        guard !draftName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if var existing = editingSubject {
            existing.name = draftName
            existing.emoji = draftEmoji
            existing.colorHex = draftColorHex
            store.updateSubject(existing)
        } else {
            let sub = Subject(name: draftName, colorHex: draftColorHex, emoji: draftEmoji)
            store.addSubject(sub)
        }
        showAddSheet = false
        editingSubject = nil
    }

    func cancel() {
        showAddSheet = false
        editingSubject = nil
    }
}
