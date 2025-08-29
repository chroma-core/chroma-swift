//
//  ContentView.swift
//  LocalEmbeddingsDemo
//
//  Created by Nicholas Arner on 7/1/25.
//

import SwiftUI
import Chroma

#if canImport(UIKit)
import UIKit
extension View {
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#else
extension View {
    func dismissKeyboard() {
        // No-op for macOS
    }
}
#endif

// Helper for iOS platform check
func isIPad() -> Bool {
    #if canImport(UIKit)
    return UIDevice.current.userInterfaceIdiom == .pad
    #else
    return false
    #endif
}

func isIPhone() -> Bool {
    #if canImport(UIKit)
    return UIDevice.current.userInterfaceIdiom == .phone
    #else
    return false
    #endif
}

struct ContentView: View {
    
    @State var state: ChromaState = .init()
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > 600 {
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            headerView
                            embedderControls
                            databaseControls
                            documentInputSection
                            querySection
                        }
                        .padding(.vertical)
                    }
                    .frame(width: min(500, geometry.size.width * 0.5))
                    logsView
                }
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        headerView
                        embedderControls
                        databaseControls
                        documentInputSection
                        querySection
                        
                        // Logs as part of the scrollable content
                        VStack(spacing: 8) {
                            HStack {
                                Text("Logs")
                                    .font(.headline)
                                    .bold()
                                
                                Spacer()
                                
                                Button("Clear") {
                                    state.logs.removeAll()
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(state.logs.enumerated()), id: \.offset) { index, log in
                                    Text("\(index + 1). \(log)")
                                        .font(.body)
                                        .padding(8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.gray.opacity(0.05))
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear {
            do {
                if !state.isInitialized {
                    try state.initialize()
                    state.refreshCollections()
                }
            } catch {
                state.addLog("Failed to initialize: \(error)")
            }
        }
    }
    
    var headerView: some View {
        VStack(spacing: 8) {
            Text("Local Embeddings Demo")
                .font(.title)
                .bold()
            Text("ChromaSwift with MLXEmbedders")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    var embedderControls: some View {
        VStack(spacing: 16) {
            Text("Embedding Model")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Picker("Model", selection: $state.selectedModel) {
                ForEach(state.availableModels, id: \.self) { model in
                    VStack(alignment: .leading) {
                        Text(model.displayName)
                        Text("\(model.embeddingDimensions) dimensions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(model)
                }
            }
            .pickerStyle(.menu)
            .disabled(state.isLoadingEmbedder)
            
            HStack {
                Button(action: {
                    Task {
                        await state.loadEmbedder()
                    }
                }) {
                    HStack {
                        if state.isLoadingEmbedder {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(state.isLoadingEmbedder ? "Loading..." : "Load Embedder")
                    }
                }
                .disabled(state.isLoadingEmbedder)
                .buttonStyle(.borderedProminent)
                
                if state.isEmbedderLoaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Ready")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    var databaseControls: some View {
        DatabaseControlsView(state: state)
    }
    
    var documentInputSection: some View {
        LocalDocumentInputView(state: state)
    }
    
    var querySection: some View {
        LocalQueryView(state: state)
    }
    
    var logsView: some View {
        LogsView(logs: $state.logs)
    }
}

// ... existing code ...

struct DatabaseControlsView: View {
    @Bindable var state: ChromaState
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Database Controls")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Create New Collection:")
                    .font(.subheadline)
                    .bold()
                
                HStack {
                    TextField("Collection name", text: $state.newCollectionName)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Create") {
                        state.createCollection()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.newCollectionName.isEmpty)
                }
            }
            
            if !state.collections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Collection:")
                        .font(.subheadline)
                        .bold()
                    
                    Picker("Collection", selection: $state.selectedCollectionName) {
                        ForEach(state.collections, id: \.self) { collection in
                            Text(collection).tag(collection)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            
            HStack {
                Button("Refresh Collections") {
                    state.refreshCollections()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Reset Database") {
                    do {
                        try state.reset()
                    } catch {
                        state.addLog("Reset failed: \(error)")
                    }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
            
            if !state.collections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Collections:")
                        .font(.subheadline)
                        .bold()
                    ForEach(state.collections, id: \.self) { collection in
                        HStack {
                            Text("• \(collection)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if collection == state.selectedCollectionName {
                                Text("(active)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct LocalDocumentInputView: View {
    @Bindable var state: ChromaState
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Document")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !state.collections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add to Collection:")
                        .font(.subheadline)
                        .bold()
                    
                    Picker("Collection", selection: $state.selectedCollectionName) {
                        ForEach(state.collections, id: \.self) { collection in
                            Text(collection).tag(collection)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } else {
                HStack {
                    Text("No collections available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Create a collection first")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Document Text:")
                    .font(.subheadline)
                    .bold()
                
                TextEditor(text: $state.docText)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(8)
                    .focused($isTextFieldFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            
            Button(action: {
                isTextFieldFocused = false
                dismissKeyboard()
                Task {
                    await state.addDocumentWithEmbedding()
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Document with Local Embedding")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!state.isEmbedderLoaded || state.docText.isEmpty || state.collections.isEmpty)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct LocalQueryView: View {
    @Bindable var state: ChromaState
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Query Documents")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !state.collections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Query Collection:")
                        .font(.subheadline)
                        .bold()
                    
                    Picker("Collection", selection: $state.selectedCollectionName) {
                        ForEach(state.collections, id: \.self) { collection in
                            Text(collection).tag(collection)
                        }
                    }
                    .pickerStyle(.menu)
                }
            } else {
                HStack {
                    Text("No collections available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Create a collection first")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Query Text:")
                    .font(.subheadline)
                    .bold()
                
                TextField("Enter your query...", text: $state.queryText)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextFieldFocused)
            }
            
            Button(action: {
                isTextFieldFocused = false
                dismissKeyboard()
                Task {
                    await state.performQueryWithEmbedding()
                }
            }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Query with Local Embedding")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!state.isEmbedderLoaded || state.queryText.isEmpty || state.collections.isEmpty)
            
            if !state.queryResults.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Query Results:")
                        .font(.subheadline)
                        .bold()
                    
                    ForEach(Array(state.queryResults.enumerated()), id: \.offset) { index, result in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(index + 1).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if index < state.queryDistances.count {
                                    let similarity = 1.0 - state.queryDistances[index]
                                    Text("Similarity: \(String(format: "%.3f", similarity))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            Text(result)
                                .font(.body)
                                .padding(8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct LogsView: View {
    @Binding var logs: [String]
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Logs")
                    .font(.headline)
                    .bold()
                
                Spacer()
                
                Button("Clear") {
                    logs.removeAll()
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(logs.enumerated()), id: \.offset) { index, log in
                            Text("\(index + 1). \(log)")
                                .font(.body)
                                .padding(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}
