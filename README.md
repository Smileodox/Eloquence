# Eloquence - AI Communication Coach

An iOS app that helps users improve their presentation and public speaking skills through AI-powered video analysis.

## Overview

Eloquence records your presentations and provides detailed feedback on:
- **Speech**: Pacing, word count, pauses, and articulation via Azure OpenAI Whisper
- **Body Language**: Facial expressions, posture, and eye contact via Apple Vision Framework
- **AI Feedback**: Personalized improvement suggestions via Azure OpenAI GPT

## Quick Start

1. Clone and open `Eloquence.xcodeproj` in Xcode
3. Run on iOS 17+ device or simulator (won't look as good if you use a pre "Liquid Glass" iOS; also utilizing the XCode Simulator will give problems in the recording-process, please utilise an iPhone if possible)
4. Login with email OTP authentication (I whitelisted all teaching personals and Prof. Butzs LMU e-Mail addresses, please use yours respectively for logging in!)

## Architecture

```
iOS App (SwiftUI)
    |
    v
Azure App Service (FastAPI)
    |
    +-- Azure OpenAI (Whisper + GPT)
    +-- Azure Communication Services (Email OTP)
    +-- Azure Table Storage (Sessions)
```

All LLM API calls are routed through the backend proxy for security.

## Project Structure

```
Eloquence/
├── Views/           # SwiftUI screens
├── Models/          # Data models
├── Services/        # API and analysis services
│   ├── Analysis/    # Scoring, key frame selection
│   └── Vision/      # Apple Vision Framework integration
├── Theme/           # Colors, design tokens
└── Config.plist     # Azure credentials (not committed)

eloquence-auth-backend/
├── app/             # FastAPI application
│   ├── main.py      # API routes
│   └── services/    # Azure integrations
└── requirements.txt
```

## Features

- Video recording
- Real-time audio level monitoring
- Speech transcription and analysis
- Gesture analysis (facial expressions, posture, eye contact)
- AI-generated feedback with strengths and areas to improve
- Key frame extraction with visual annotations
- Progress tracking across sessions

## Development

### Prerequisites

- Xcode 15+
- iOS 17+ device or simulator

(Not required anymore as we provide this, just listing it up for clarity)
- Azure account with:
  - OpenAI resource (Whisper + GPT deployments)
  - Communication Services resource
  - Table Storage account
  - App Service (for backend)

### iOS Setup

1. Open `Eloquence.xcodeproj`
2. Select target device (iPhone needs to pe plugged into Mac)
3. Build and run

### Backend Setup

See [eloquence-auth-backend/README.md](eloquence-auth-backend/README.md)
