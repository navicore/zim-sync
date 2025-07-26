# ZimSync

Fast local network file sync for audio production, built with pure Swift.

## Overview

ZimSync solves the frustrating problem of transferring audio files between Apple devices on the same network. Instead of fighting with AirDrop, ZimSync provides reliable, fast UDP-based file transfer optimized for audio production workflows.

## Features

- 🚀 **Fast UDP Protocol** - Optimized for local networks
- 🔍 **Automatic Discovery** - Devices find each other via Bonjour
- 📱 **Native Apple Experience** - Built with Swift and SwiftUI
- 🎵 **Audio-Optimized** - Handles large audio files efficiently
- 🔒 **Local Only** - No cloud services required

## Architecture

Built using idiomatic Swift patterns:

- **Modern Concurrency** - async/await throughout
- **Network.framework** - Apple's modern networking API
- **Value Types** - Structs and enums for safety
- **Protocol-Oriented** - Extensible design
- **SwiftUI** - Native UI on all platforms

## Project Structure

```
ZimSync/
├── Package.swift           # Swift Package Manager manifest
├── Sources/
│   ├── ZimSyncCore/       # Shared networking & sync logic
│   └── ZimSyncCLI/        # Command-line testing tool
├── Apps/
│   ├── ZimSync-macOS/     # macOS app (coming soon)
│   └── ZimSync-iOS/       # iOS/iPadOS app (coming soon)
└── Tests/                 # Unit tests
```

## Getting Started

### Build the CLI

```bash
swift build
```

### Run discovery

```bash
swift run zimsync discover
```

### Start a server

```bash
swift run zimsync serve --port 8080 --name "My Studio Mac"
```

### Test connection

```bash
swift run zimsync test hostname.local
```

## Development

This project embraces Apple's platform conventions:

- Swift 5.9+ with strict concurrency
- Minimum deployment: macOS 14, iOS 17
- Swift Package Manager for dependencies
- XCTest for testing

## Protocol Design

The UDP protocol is inspired by VoIP for speed:

1. **Discovery** - Bonjour advertises `_zimsync._udp.local`
2. **Handshake** - Exchange capabilities and file lists
3. **Transfer** - Chunked data with simple ACK
4. **Verification** - Checksum validation

## Roadmap

- [x] Core UDP networking
- [x] Bonjour service discovery
- [x] CLI testing tool
- [ ] Packet protocol implementation
- [ ] File chunking and transfer
- [ ] macOS app with menu bar
- [ ] iOS app with share extension
- [ ] Background sync
- [ ] Delta sync optimization

## License

MIT