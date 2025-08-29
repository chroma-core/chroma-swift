//
//  DocumentDeletionView.swift
//  PersistentChroma
//
//  Created by Nicholas Arner on 5/21/25.
//

import SwiftUI
import Chroma

struct DocumentDeletionView: View {
    
    @Bindable var state: ChromaState
    
    @State private var selectedDocumentIds: Set<String> = []
    @State private var documentsToShow: [(id: String, content: String?)] = []
    @State private var selectedCollectionForDeletion: String = ""
    @State private var isLoadingDocuments: Bool = false
    
    @FocusState var focused: Bool
    
    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                headerView
                contentView
            }
            .padding()
        } label: {
            Label("Document Deletion", systemImage: "trash.fill")
        }
    }
    
    private var headerView: some View {
        Text("Delete Documents")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var contentView: some View {
        Group {
            if state.collections.isEmpty {
                emptyCollectionsView
            } else {
                deletionControlsView
            }
        }
    }
    
    private var emptyCollectionsView: some View {
        Text("No collections available")
            .foregroundColor(.secondary)
    }
    
    private var deletionControlsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            collectionPickerView
            documentsDisplayView
            actionButtonsView
            refreshButtonView
        }
    }
    
    private var collectionPickerView: some View {
        Picker("Collection", selection: $selectedCollectionForDeletion) {
            Text("Select Collection").tag("")
            ForEach(state.collections, id: \.self) { name in
                Text(name).tag(name)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedCollectionForDeletion) { oldValue, newValue in
            handleCollectionChange(newValue)
        }
    }
    
    private var documentsDisplayView: some View {
        Group {
            if isLoadingDocuments {
                loadingView
            } else if !documentsToShow.isEmpty {
                documentsListView
            } else if !selectedCollectionForDeletion.isEmpty {
                emptyDocumentsView
            }
        }
    }
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .controlSize(.small)
            Text("Loading documents...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var documentsListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Documents in collection:")
                .font(.subheadline)
                .fontWeight(.medium)
            
            documentsScrollView
        }
    }
    
    private var documentsScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(documentsToShow, id: \.id) { document in
                    documentRowView(document)
                }
            }
        }
        .frame(maxHeight: 150)
        .cornerRadius(8)
        .padding(.horizontal, 4)
    }
    
    private func documentRowView(_ document: (id: String, content: String?)) -> some View {
        HStack {
            documentCheckboxView(document.id)
            documentInfoView(document)
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func documentCheckboxView(_ documentId: String) -> some View {
        let isSelected = selectedDocumentIds.contains(documentId)
        
        return Button {
            toggleDocumentSelection(documentId)
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .buttonStyle(.plain)
    }
    
    private func documentInfoView(_ document: (id: String, content: String?)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ID: \(document.id)")
                .font(.caption)
                .fontWeight(.medium)
            
            Text(document.content ?? "(no content)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
    }
    
    private var emptyDocumentsView: some View {
        Text("No documents found in this collection")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 12) {
            deleteSelectedButton
            deleteAllButton
        }
    }
    
    private var deleteSelectedButton: some View {
        ActionButton(
            title: "Delete Selected (\(selectedDocumentIds.count))",
            disabled: !state.isPersistentInitialized || selectedDocumentIds.isEmpty
        ) {
            handleDeleteSelected()
        }
    }
    
    private var deleteAllButton: some View {
        ActionButton(
            title: "Delete All Documents",
            disabled: !state.isPersistentInitialized || selectedCollectionForDeletion.isEmpty || documentsToShow.isEmpty
        ) {
            handleDeleteAll()
        }
    }
    
    @ViewBuilder
    private var refreshButtonView: some View {
        if !selectedCollectionForDeletion.isEmpty {
            ActionButton(
                title: "Refresh Documents",
                disabled: !state.isPersistentInitialized || isLoadingDocuments
            ) {
                handleRefresh()
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func handleCollectionChange(_ newValue: String) {
        if !newValue.isEmpty {
            loadDocumentsForCollection(newValue)
        } else {
            documentsToShow = []
            selectedDocumentIds = []
        }
    }
    
    private func toggleDocumentSelection(_ documentId: String) {
        if selectedDocumentIds.contains(documentId) {
            selectedDocumentIds.remove(documentId)
        } else {
            selectedDocumentIds.insert(documentId)
        }
    }
    
    private func handleDeleteSelected() {
        focused = false
        do {
            try state.deleteDocuments(
                collectionName: selectedCollectionForDeletion,
                documentIds: Array(selectedDocumentIds)
            )
            selectedDocumentIds = []
            loadDocumentsForCollection(selectedCollectionForDeletion)
        } catch {
            state.addLog("Failed to delete selected documents: \(error)")
        }
    }
    
    private func handleDeleteAll() {
        focused = false
        do {
            try state.deleteAllDocumentsFromCollection(collectionName: selectedCollectionForDeletion)
            selectedDocumentIds = []
            loadDocumentsForCollection(selectedCollectionForDeletion)
        } catch {
            state.addLog("Failed to delete all documents: \(error)")
        }
    }
    
    private func handleRefresh() {
        focused = false
        loadDocumentsForCollection(selectedCollectionForDeletion)
    }
    
    private func loadDocumentsForCollection(_ collectionName: String) {
        guard !collectionName.isEmpty else { return }
        
        isLoadingDocuments = true
        selectedDocumentIds = []
        
        Task {
            do {
                let result = try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let result = try getAllDocuments(collectionName: collectionName)
                            continuation.resume(returning: result)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                
                await MainActor.run {
                    documentsToShow = zip(result.ids, result.documents).map { id, doc in
                        (id: id, content: doc)
                    }
                    isLoadingDocuments = false
                    state.addLog("Loaded \(documentsToShow.count) documents for deletion view")
                }
            } catch {
                await MainActor.run {
                    documentsToShow = []
                    isLoadingDocuments = false
                    state.addLog("Failed to load documents: \(error)")
                }
            }
        }
    }
}
