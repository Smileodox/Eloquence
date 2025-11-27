# Eloquence - Quick Start Guide

## 🚀 Getting Started in 3 Steps

### Step 1: Open the Project
1. Navigate to `/Users/johannes/Desktop/Eloquence`
2. Double-click `Eloquence.xcodeproj`
3. Wait for Xcode to open and index the project

### Step 2: Select a Target Device
1. In Xcode's top bar, click the device selector
2. Choose any iOS Simulator (recommended: iPhone 15 or iPhone 15 Pro)
3. Or connect a physical iOS device

### Step 3: Build and Run
1. Press `Cmd + R` or click the Play button ▶️
2. Wait for the app to compile and launch
3. The app will open in the simulator/device

## 📱 Testing the App

### First Launch
1. You'll see the **Login Screen**
2. Enter any email (e.g., `test@eloquence.com`)
3. Enter any password (e.g., `password123`)
4. Tap **Login**

### Exploring Features

#### Practice a Session
1. From Dashboard, tap **"Start New Session"**
2. Tap **"Start Recording"** (large blue button)
3. Wait a few seconds (speaking is optional in demo mode)
4. Tap **"Stop Recording"** (red button)
5. Watch the AI analysis animation
6. View your feedback and scores

#### View Progress
1. From Dashboard, tap **"View Progress"**
2. See your session history chart
3. Review statistics and insights
4. Tap **"Export Report"** (placeholder feature)

#### Adjust Settings
1. From Dashboard, tap **"Settings"**
2. Try changing:
   - AI Voice Style (Neutral/Motivational/Analytical)
   - Camera Feedback toggle
   - Weekly Summary toggle
3. Tap **"Save Settings"**
4. Confirmation alert will appear

## 🎨 What You'll See

### Beautiful UI Elements
- **Dark Theme**: Sophisticated OKLCH color palette
- **Smooth Animations**: Pulsing recording indicator, loading states
- **Interactive Charts**: Line graphs showing progress over time
- **Circular Progress**: Visual score indicators
- **Modern Typography**: System fonts with proper hierarchy

### Color Highlights
- 🔵 **Primary Blue**: Main actions and highlights
- 🟡 **Secondary Yellow**: Accents and variety
- 🟢 **Success Green**: Positive feedback
- 🔴 **Danger Red**: Recording and alerts
- 🟣 **Info Purple**: Information elements

## 📂 Project Structure

```
Eloquence/
├── EloquenceApp.swift          # App entry point
├── Models/
│   └── UserSession.swift       # User state & data
├── Views/
│   ├── RootView.swift          # Navigation root
│   ├── LoginView.swift         # Authentication
│   ├── DashboardView.swift     # Main hub
│   ├── RecordingView.swift     # Record practice
│   ├── AnalyzingView.swift     # AI processing
│   ├── FeedbackView.swift      # Results & scores
│   ├── ProgressView.swift      # Analytics
│   └── SettingsView.swift      # Preferences
└── Theme/
    └── ColorTheme.swift        # Design system
```

## 🎯 Key Features to Test

### ✅ Login Flow
- [x] Email input with validation styling
- [x] Password with show/hide toggle
- [x] Smooth transition to Dashboard

### ✅ Recording Experience
- [x] Large, accessible recording button
- [x] Pulsing animation while recording
- [x] Real-time timer display
- [x] Color change from blue to red

### ✅ AI Analysis
- [x] Rotating brain icon animation
- [x] Orbiting particles
- [x] Progress bar 0-100%
- [x] Step-by-step checklist

### ✅ Feedback Display
- [x] Overall score with circular progress
- [x] Three detailed metrics (Tone, Pacing, Gestures)
- [x] AI-generated insights text
- [x] Multiple navigation options

### ✅ Progress Tracking
- [x] Line chart with three metrics
- [x] Color-coded legend
- [x] Statistics cards
- [x] Weekly summary

### ✅ Settings
- [x] AI voice style selector
- [x] Toggle switches
- [x] Save confirmation
- [x] Logout functionality

## 🐛 Known Demo Limitations

Since this is a demo/prototype:

- **No Real Recording**: Microphone isn't captured (placeholder)
- **Mock AI Analysis**: Scores are randomly generated
- **Demo Login**: Any email/password works
- **No Data Persistence**: Data resets on app restart
- **PDF Export**: Placeholder (not implemented)

## 🔧 Customization Tips

### Change Colors
Edit `/Eloquence/Theme/ColorTheme.swift`:
```swift
static let primary = Color(hue: 255/360, saturation: 0.132, brightness: 0.76)
```

### Modify Feedback Text
Edit `/Eloquence/Views/AnalyzingView.swift`:
```swift
let feedbackOptions = [
    "Your custom feedback here..."
]
```

### Adjust Animations
Search for `.animation()` modifiers throughout the views
Example in `RecordingView.swift`:
```swift
.scaleEffect(isRecording ? 0.95 : 1.0)
.animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
```

## 📚 Documentation

- **README.md**: Full feature list and architecture
- **APP_GUIDE.md**: Detailed screen-by-screen visual guide
- **This file**: Quick start and testing guide

## 🎓 Learning Resources

Want to understand the code better?

1. **SwiftUI Basics**: Start with `LoginView.swift` (simplest view)
2. **State Management**: Review `UserSession.swift` (data model)
3. **Navigation**: Check `RootView.swift` (routing logic)
4. **Animations**: Explore `RecordingView.swift` and `AnalyzingView.swift`
5. **Charts**: See `ProgressView.swift` (Swift Charts usage)

## 🚨 Troubleshooting

### Build Errors?
1. Make sure you're using Xcode 15 or later
2. Clean build folder: `Cmd + Shift + K`
3. Rebuild: `Cmd + B`

### Simulator Issues?
1. Reset simulator: Device → Erase All Content and Settings
2. Try a different simulator model
3. Restart Xcode

### Preview Not Working?
1. Enable previews: `Cmd + Option + Enter`
2. Resume preview: `Cmd + Option + P`
3. Some previews require EnvironmentObject setup

## 💡 Next Steps

After exploring the app:

1. **Add Real Recording**: Integrate AVFoundation for audio capture
2. **Connect AI API**: Replace mock analysis with real AI service
3. **Add Persistence**: Use CoreData or CloudKit for data storage
4. **Implement PDF Export**: Use PDFKit to generate reports
5. **Add Onboarding**: Create welcome screens for first-time users

## 🎉 Enjoy!

Your Eloquence app is ready to use. Open it in Xcode and start exploring!

For questions or issues, refer to the detailed documentation in `README.md` and `APP_GUIDE.md`.

---

**Built with SwiftUI | Designed for iOS 17+**

