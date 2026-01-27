//
//  NewProjectSheet.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import SwiftUI

struct NewProjectSheet: View {
    @Binding var projectName: String
    @Binding var dueDate: Date
    @Binding var hasDueDate: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) var dismiss
    
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
                    Button("Create") {
                        onSave()
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
    NewProjectSheet(
        projectName: .constant(""),
        dueDate: .constant(Date()),
        hasDueDate: .constant(false),
        onSave: {},
        onCancel: {}
    )
}

