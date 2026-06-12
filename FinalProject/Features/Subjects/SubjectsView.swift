import SwiftUI

struct SubjectsView: View {
    @EnvironmentObject var store: StudyStore
    @StateObject private var vm = SubjectsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: StudySpacing.medium) {
                    headerBanner
                    subjectsList
                    addButton
                }
                .padding(.horizontal, StudySpacing.large)
                .padding(.bottom, StudySpacing.xxLarge)
            }
            .background(StudyTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $vm.showAddSheet) {
            subjectFormSheet
        }
    }

    // MARK: - Header

    private var headerBanner: some View {
        GradientStudyCard(gradient: StudyTheme.accentGradient) {
            VStack(alignment: .leading, spacing: StudySpacing.small) {
                Label("SUBJECTS", systemImage: "books.vertical.fill")
                    .font(StudyFont.tiny)
                    .foregroundStyle(.black.opacity(0.60))
                    .tracking(1)
                Text("Your Study\nSubjects")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.black.opacity(0.90))
                Text("\(store.subjects.count) subjects tracked")
                    .font(StudyFont.caption)
                    .foregroundStyle(.black.opacity(0.60))
            }
        }
        .padding(.top, StudySpacing.medium)
    }

    // MARK: - List

    @ViewBuilder
    private var subjectsList: some View {
        if store.subjects.isEmpty {
            StudyCard {
                VStack(spacing: StudySpacing.medium) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 44))
                        .foregroundStyle(StudyTheme.secondaryText)
                    Text("No subjects yet")
                        .font(StudyFont.cardTitle)
                        .foregroundStyle(StudyTheme.primaryText)
                    Text("Add your first subject to start tracking study time.")
                        .font(StudyFont.body)
                        .foregroundStyle(StudyTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            ForEach(store.subjects) { subject in
                subjectRow(subject)
            }
        }
    }

    private func subjectRow(_ subject: Subject) -> some View {
        let mins = store.minutesBySubjectToday.first(where: { $0.subject.id == subject.id })?.minutes ?? 0
        return HStack(spacing: StudySpacing.medium) {
            // Colour dot + emoji
            ZStack {
                Circle()
                    .fill(subject.color.opacity(0.20))
                    .frame(width: 52, height: 52)
                Text(subject.emoji).font(.title2)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(subject.name)
                    .font(StudyFont.subtitle)
                    .foregroundStyle(StudyTheme.primaryText)
                Text(mins > 0 ? "Today: \(mins.minutesToHoursString)" : "No sessions today")
                    .font(StudyFont.caption)
                    .foregroundStyle(StudyTheme.secondaryText)
            }

            Spacer()

            // Color indicator strip
            RoundedRectangle(cornerRadius: 3)
                .fill(subject.color)
                .frame(width: 4, height: 36)

            Button {
                vm.startEdit(subject)
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(StudyTheme.secondaryText)
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
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Subject")
                    .fontWeight(.bold)
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

// MARK: - Button style

struct PrimaryStudyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(StudyFont.subtitle)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(StudyTheme.accentGradient)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
