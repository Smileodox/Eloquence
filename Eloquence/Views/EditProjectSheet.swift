//
//  EditProjectSheet.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI

struct EditProjectSheet: View {
    let project: Project
    let onSave: (Project) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var projectName: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    
    init(project: Project, onSave: @escaping (Project) -> Void, onCancel: @escaping () -> Void) {
        self.project = project
        self.onSave = onSave
        self.onCancel = onCancel
        _projectName = State(initialValue: project.name)
        _dueDate = State(initialValue: project.dueDate ?? Date())
        _hasDueDate = State(initialValue: project.dueDate != nil)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                
                VStack(spacing: Theme.largeSpacing) {
                    // Project Name
                    VStack(alignment: .leading, spacing: Theme.spacing) {
                        Text("Project Name")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.textPrimary)
                        
                        TextField("Enter project name", text: $projectName)
                            .foregroundStyle(Color.textPrimary)
                            .textFieldStyle(.plain)
                            .padding(Theme.spacing)
                            .background(Color.bgLight)
                            .cornerRadius(Theme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.cornerRadius)
                                    .stroke(Color.border, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, Theme.largeSpacing)
                    .padding(.top, Theme.largeSpacing)
                    
                    // Due Date Toggle
                    VStack(alignment: .leading, spacing: Theme.spacing) {
                        Toggle(isOn: $hasDueDate) {
                            Text("Set Due Date")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.textPrimary)
                        }
                        .tint(Color.primary)
                        
                        if hasDueDate {
                            DatePicker(
                                "Due Date",
                                selection: $dueDate,
                                in: Date()...,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.compact)
                            .padding(Theme.spacing)
                            .background(Color.bgLight)
                            .cornerRadius(Theme.cornerRadius)
                            .foregroundStyle(Color.textPrimary)
                        }
                    }
                    .padding(.horizontal, Theme.largeSpacing)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(Color.textPrimary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedProject = Project(
                            id: project.id,
                            name: projectName.trimmingCharacters(in: .whitespacesAndNewlines),
                            createdAt: project.createdAt,
                            dueDate: hasDueDate ? dueDate : nil
                        )
                        onSave(updatedProject)
                        dismiss()
                    }
                    .foregroundStyle(Color.primary)
                    .fontWeight(.semibold)
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .toolbarBackground(Color.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    EditProjectSheet(
        project: Project(name: "Test Project", dueDate: Date()),
        onSave: { _ in },
        onCancel: {}
    )
}

