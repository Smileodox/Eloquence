# Eloquence

An AI-powered communication coach that helps users improve their presentation and public speaking skills.

## 🎯 Features

- **AI Analysis**: Analyzes tone, pacing, pauses, and body language
- **Real-time Feedback**: Provides personalized feedback to enhance clarity and confidence
- **Progress Tracking**: Visualizes performance development over multiple sessions
- **Customizable AI**: Adjust AI voice style and feedback preferences

## 📱 Screens

### 1. Login / Welcome Screen
- Email and password authentication
- Elegant login form with modern UI

### 2. Dashboard / Home Screen
- Welcome message with user name
- Progress widget showing last session improvement
- Quick action buttons for:
  - Start New Session
  - View Progress
  - Settings
- Quick tips for better presentations

### 3. Recording / Practice Screen
- Audio/video recording functionality
- Visual recording indicator with pulsing animation
- Timer display
- Recording instructions
- Start/Stop recording controls

### 4. AI Analyzing Screen
- Loading animation with AI processing indicator
- Progress bar showing analysis percentage
- Step-by-step analysis breakdown:
  - Audio quality
  - Tone patterns
  - Pacing measurement
  - Gesture evaluation
  - Feedback generation

### 5. Feedback Screen
- Overall score with circular progress indicator
- Detailed analysis for:
  - Tone (with score)
  - Pacing (with score)
  - Gestures (with score)
- AI-generated insights and recommendations
- Action buttons:
  - Try Again (repeat practice)
  - View Progress (see history)
  - Back to Dashboard

### 6. Progress / Insights Screen
- Performance statistics cards
- Line chart showing progress over time
- Key metrics with average scores
- Weekly summary with personalized insights
- Export report functionality (PDF)

### 7. Settings / Profile Screen
- User profile information
- AI preferences:
  - Voice style (Neutral, Motivational, Analytical)
  - Camera feedback toggle
  - Weekly summary toggle
- Account settings
- Logout functionality

## 🎨 Design System

### Color Palette (OKLCH)

The app uses a sophisticated OKLCH color system for consistent and modern design:

- **Background**: Dark theme with layered depths
  - `bgDark`: oklch(0.1 0.035 255)
  - `bg`: oklch(0.15 0.035 255)
  - `bgLight`: oklch(0.2 0.035 255)

- **Text**: High contrast for readability
  - `textPrimary`: oklch(0.96 0.07 255)
  - `textMuted`: oklch(0.76 0.07 255)

- **Brand Colors**:
  - `primary`: oklch(0.76 0.1 255) - Blue
  - `secondary`: oklch(0.76 0.1 75) - Yellow

- **Semantic Colors**:
  - `success`: oklch(0.7 0.07 160) - Green
  - `danger`: oklch(0.7 0.07 30) - Red
  - `warning`: oklch(0.7 0.07 100) - Yellow
  - `info`: oklch(0.7 0.07 260) - Purple

### Design Tokens

- Corner Radius: 16px (standard), 12px (small)
- Button Height: 56px
- Spacing: 16px (standard), 24px (large)

## 🏗️ Architecture

### File Structure

```
Eloquence/
├── EloquenceApp.swift          # App entry point
├── Models/
│   └── UserSession.swift       # User state management
├── Views/
│   ├── RootView.swift          # Root navigation controller
│   ├── LoginView.swift         # Authentication screen
│   ├── DashboardView.swift     # Main hub
│   ├── RecordingView.swift     # Recording interface
│   ├── AnalyzingView.swift     # AI processing screen
│   ├── FeedbackView.swift      # Results display
│   ├── ProgressView.swift      # Analytics and insights
│   └── SettingsView.swift      # User preferences
└── Theme/
    └── ColorTheme.swift        # Color system and design tokens
```

### State Management

The app uses SwiftUI's `@StateObject` and `@EnvironmentObject` for state management:

- `UserSession`: ObservableObject managing user authentication, settings, and session data
- Shared across all views via environment injection

### Navigation

- NavigationStack-based navigation
- Programmatic navigation using NavigationLink
- Proper back navigation and dismiss actions

## 🚀 Getting Started

1. Open `Eloquence.xcodeproj` in Xcode
2. Select a simulator or device
3. Press `Cmd + R` to build and run
4. Login with any email/password (demo mode)

## 📝 Notes

- The app currently uses mock data for demonstration purposes
- AI analysis is simulated with random scores and pre-written feedback
- PDF export functionality is a placeholder
- Camera and microphone permissions need to be configured in Info.plist for production

## 🔮 Future Enhancements

- Real AI/ML integration for actual speech analysis
- Cloud storage for session data
- Social features and leaderboards
- Advanced analytics and insights
- Multiple language support
- Offline mode support

## 📄 License

Created for demonstration purposes.

---

Built with ❤️ using SwiftUI

