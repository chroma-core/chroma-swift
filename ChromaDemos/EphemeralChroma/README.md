# EphemeralChroma Example

This example demonstrates how to use the Chroma Swift package in an ephemeral (in-memory or temporary) mode. All data is stored in memory and will be lost when the app is closed or reset.

## Features

- Create, list, and delete collections
- Add documents with embeddings
- Perform similarity search queries
- View logs of all operations
- Reset the database at any time

## How It Works

- **Ephemeral storage:** All data is stored in memory only. Use this mode for testing, demos, or temporary data needs.
- **Resettable:** You can reset the database at any time from the UI, which clears all data.

## Getting Started

1. Open `EphemeralChroma.xcodeproj` in Xcode.
2. Run the app on your simulator or device (on either your Mac or iOS targets).

## Usage

- Use the UI to create collections, add documents, and run queries.
- All actions and errors are logged in the app.
- Use the "Reset" button to clear all data and start fresh.

## Requirements

- Xcode 15+
- iOS 13+ or macOS 10.15+
- Swift 5.10+
- The Chroma Swift package as a dependency

## Notes

- Data is not persisted between app launches.
- This example is ideal for learning and experimentation.

---
