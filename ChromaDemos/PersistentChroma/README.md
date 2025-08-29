# PersistentChroma Example

This example demonstrates how to use the Chroma Swift package with persistent storage. All data is saved to disk and survives app restarts.

## Features

- Create, list, and delete collections
- Add documents with embeddings
- Perform similarity search queries
- Specify a custom path for persistent storage
- View logs of all operations
- Reset and re-initialize the persistent database

## How It Works

- **Persistent storage:** Data is stored in a file on disk (default: `Documents/chroma_data`).
- **Custom path:** You can specify a custom path for the database location.
- **Resettable:** You can reset and re-initialize the persistent database from the UI.

## Getting Started

1. Open `PersistentChroma.xcodeproj` in Xcode.
2. Run the app on your simulator or device.

## Usage

- Use the UI to create collections, add documents, and run queries.
- All actions and errors are logged in the app.
- Use the "Reset" button to clear all data and re-initialize the persistent database.
- The database file is saved in the app’s Documents directory by default.

## Requirements

- Xcode 15+
- iOS 13+ or macOS 10.15+
- Swift 5.10+
- The Chroma Swift package as a dependency

## Notes

- Data is persisted between app launches.
- This example is ideal for real-world usage, prototyping, or apps needing persistent vector storage.

---
