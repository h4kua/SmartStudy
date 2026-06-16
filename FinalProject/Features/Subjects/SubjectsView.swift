import SwiftUI

struct SubjectsView: View {
    @EnvironmentObject var store: StudyStore
    @StateObject private var vm = SubjectsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.medium) {
                    pageHeader
                    subjectsList
                    addButton
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $vm.showAddSheet) {
            subjectFormSheet
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Subjects")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(StudyTheme.primaryText)
                Text("\(store.subjects.count) subject\(store.subjects.count == 1 ? "" : "s") tracked")
                    .font(StudyFont.caption)
                    .foregroundStyle(StudyTheme.secondaryText)
            }
            Spacer()
        }
        .padding(.top, StudySpacing.large)
    }

    // MARK: - List

    @ViewBuilder
    private var subjectsList: some View {
        if store.subjects.isEmpty {
            StudyCard {
                VStack(spacing: StudySpacing.medium) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 40))
                        .foregroundStyle(StudyTheme.tertiaryText)
                    Text("No subjects yet")
                        .font(StudyFont.cardTitle)
                        .foregroundStyle(StudyTheme.primaryText)
                    Text("Add your first subject to start tracking study time.")
                        .font(StudyFont.body)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, StudySpacing.small)
            }
        } else {
            VStack(spacing: StudySpacing.small) {
                ForEach(store.subjects) { subject in
                    subjectRow(subject)
                }
            }
        }
    }

    private func subjectRow(_ subject: Subject) -> some View {
        let mins = store.minutesBySubjectToday.first(where: { $0.subject.id == subject.id })?.minutes ?? 0
        return HStack(spacing: StudySpacing.medium) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(subject.color.opacity(0.16))
                    .frame(width: 48, height: 48)
                Text(subject.emoji).font(.title3)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(subject.name)
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Text(mins > 0 ? "Today: \(mins.minutesToHoursString)" : "No sessions today")
                    .font(StudyFont.tiny)
                    .foregroundStyle(StudyTheme.secondaryText)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 3)
                .fill(subject.color)
                .frame(width: 3, height: 32)

            Button {
                vm.startEdit(subject)
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(StudyTheme.tertiaryText)
            }
        }
        .padding(StudySpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(StudyTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(StudyTheme.surfaceStroke, lineWidth: 1)
                )
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                if let idx = store.subjects.firstIndex(where: { $0.id == subject.id }) {
                    store.deleteSubject(at: IndexSet([idx]))
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var addButton: some View {
        Button { vm.startAdd() } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text("Add Subject")
                    .font(StudyFont.subtitle)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(PrimaryStudyButtonStyle())
    }

    // MARK: - Form sheet

    private var subjectFormSheet: some View {
        NavigationStack {
            Form {
                Section("Name & Icon") {
                    HStack {
                        TextField("Emoji", text: $vm.draftEmoji)
                            .frame(width: 50)
                            .multilineTextAlignment(.center)
                        Divider()
                        TextField("Subject name", text: $vm.draftName)
                    }
                }

                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5),
                              spacing: StudySpacing.small) {
                        ForEach(Subject.colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex) ?? .blue)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(.white, lineWidth: vm.draftColorHex == hex ? 3 : 0)
                                )
                                .onTapGesture { vm.draftColorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(vm.editingSubject == nil ? "New Subject" : "Edit Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { vm.cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { vm.saveToStore(store) }
                        .disabled(vm.draftName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
