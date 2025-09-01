# Chroma Swift Example Projects

Four example projects are included, showing Chroma's ephemeral and persistent modes, local embeddings functionality, and cloud synchronization.

The screenshots are from Mac Catalyst, but each demo can also run on iOS devices, too. 



## Ephemeral Chroma Demo

![EphemeralChromaDemo](README_ASSETS/EphemeralChromaDemo.png)



## Persistent Chroma Demo

![LocalEmbeddingsDemo](README_ASSETS/PersistentChromaDemo.png)



## Local Embeddings Demo

![LocalEmbeddingsDemo](README_ASSETS/LocalEmbeddingsDemo.png)



## Chroma Cloud Sync Demo

A demonstration of synchronizing local Chroma collections with Chroma Cloud. This example shows how to:

- Connect to Chroma Cloud using tenant, database, and API key authentication
- Create collections both locally and in the cloud
- Add sample documents to collections
- Upload local collection data to cloud collections

**Security Note**: This demo stores API keys in plain text for demonstration purposes only. In production applications, API keys should be stored securely using:
- iOS Keychain Services
- Environment variables
- Secure configuration management systems
- Never committed to version control

The demo uses the X-Chroma-Token authentication header and follows the Chroma Cloud v2 API endpoint structure with tenant/database multi-tenancy.
