# Eloquence - App Guide

## 🎨 Visual Design

The app features a modern, dark-themed interface with a sophisticated color system using OKLCH color space for consistent and vibrant colors across all screens.

### Color Usage

- **Primary Blue** - Main actions, highlights, and interactive elements
- **Secondary Yellow** - Complementary accent for variety
- **Success Green** - Positive feedback and improvements
- **Danger Red** - Recording indicators and important actions
- **Info Purple** - Informational elements
- **Warning Yellow** - Alerts and tips

## 📱 Screen-by-Screen Guide

### 1. Login Screen

**Visual Elements:**
- Large circular logo with waveform icon
- App name "Eloquence" in bold rounded font
- Tagline: "Master the art of communication"
- Email and password input fields with icons
- Primary action button with gradient background
- Sign up link

**User Flow:**
1. Enter email address
2. Enter password
3. Tap "Login" button
4. → Navigate to Dashboard

**Design Features:**
- Gradient background (dark to light)
- Focused input fields have primary blue border
- Password visibility toggle
- "Forgot Password?" link
- Smooth transitions

---

### 2. Dashboard Screen

**Visual Elements:**
- Personalized welcome message with user name
- Progress card showing last session improvement
- Circular progress indicator
- Three main action cards:
  1. **Start New Session** - Large featured card with microphone icon
  2. **View Progress** - Medium card with chart icon
  3. **Settings** - Medium card with gear icon
- Quick tips section with bullet points

**User Flow:**
- From here, users can:
  - → Start Recording (main action)
  - → View Progress (analytics)
  - → Settings (preferences)

**Design Features:**
- Cards with rounded corners (16px)
- Hover/tap states for interactivity
- Icon-based navigation
- Progress metrics front and center
- Motivational messaging

---

### 3. Recording Screen

**Visual Elements:**
- Large circular recording button (160px)
- Pulsing ring animations when recording
- Real-time timer display (MM:SS.ms format)
- Recording instructions panel
- Status text: "Ready to start your practice?"

**User Flow:**
1. Tap "Start Recording" button
2. Button changes to red with stop icon
3. Timer begins counting
4. Tap "Stop Recording"
5. → Navigate to Analyzing Screen

**Design Features:**
- Microphone icon transforms to stop square
- Pulsing animations for visual feedback
- Timer in large monospace font
- Color change from primary blue to danger red
- Instructions fade when recording

---

### 4. AI Analyzing Screen

**Visual Elements:**
- Central brain icon rotating
- 8 orbiting particles around center
- Linear progress bar (0-100%)
- Large percentage display
- Current processing step indicator
- Step-by-step checklist:
  - ✓ Analyzing audio quality
  - ✓ Detecting tone patterns
  - ✓ Measuring pacing
  - ✓ Evaluating gestures
  - ⚡ Generating feedback

**User Flow:**
- Automatic processing (3-5 seconds)
- Progress increments smoothly
- → Auto-navigate to Feedback Screen when complete

**Design Features:**
- Animated loading states
- Progress visualization
- Real-time step updates
- Gradient progress bar
- Professional "AI Processing" branding

---

### 5. Feedback Screen

**Visual Elements:**
- Success checkmark animation
- Overall score with circular progress (0-100)
- Three detailed score cards:
  - **Tone** - Waveform icon, primary blue
  - **Pacing** - Speedometer icon, secondary yellow
  - **Gestures** - Figure icon, info purple
- Each with horizontal progress bar
- AI insights text panel with sparkles icon
- Two action buttons:
  - "Try Again" (primary)
  - "View Progress" (secondary)
- "Back to Dashboard" text link

**User Flow:**
- Review scores and feedback
- Options:
  - → Try Again (return to recording)
  - → View Progress (see history)
  - → Back to Dashboard (home)

**Design Features:**
- Celebratory animation on appear
- Color-coded scores
- Detailed breakdown
- Personalized AI feedback text
- Clear call-to-action hierarchy

---

### 6. Progress Screen

**Visual Elements:**
- Two stat cards at top:
  - Total Sessions count
  - Overall Improvement percentage
- Line chart showing performance over time
  - Three lines: Tone, Pacing, Gestures
  - Color-coded legend
- Key metrics section with average scores
- Weekly summary text with lightbulb icon
- "Export Report (PDF)" button

**User Flow:**
- Review historical performance
- Analyze trends
- Export data (optional)

**Design Features:**
- Interactive charts using Swift Charts
- Color-coded metrics matching feedback screen
- Responsive layout
- Motivational summary text based on performance
- Professional data visualization

---

### 7. Settings Screen

**Visual Elements:**
- User profile section:
  - Circular avatar with initial
  - Name and email display
- AI Preferences section:
  - Voice Style selector (pill buttons)
    - Neutral
    - Motivational
    - Analytical
  - Camera Feedback toggle
  - Weekly Summary toggle
- Account section:
  - Change Password
  - Notification Settings
  - Help & Support
  - About Eloquence
- "Save Settings" button (primary)
- "Logout" button (danger outline)

**User Flow:**
1. Adjust preferences
2. Tap "Save Settings"
3. → Success confirmation
4. Optional: Logout → Return to Login Screen

**Design Features:**
- Segmented control for AI voice styles
- Toggle switches with primary color tint
- Icon-based menu items
- Clear visual hierarchy
- Confirmation dialog for save action

---

## 🎯 Navigation Flow

```
Login Screen
    ↓
Dashboard Screen ←─────────────┐
    ├─→ Recording Screen        │
    │       ↓                    │
    │   Analyzing Screen         │
    │       ↓                    │
    │   Feedback Screen ─────────┤
    │       ↓                    │
    ├─→ Progress Screen ─────────┤
    │                            │
    └─→ Settings Screen          │
            ↓ (Logout)           │
        Login Screen             │
            └────────────────────┘
```

## 🎨 Design Principles

1. **Consistency**: Uniform spacing, corner radius, and color usage
2. **Hierarchy**: Clear visual importance through size, color, and position
3. **Feedback**: Animations and transitions for user actions
4. **Accessibility**: High contrast text, large touch targets
5. **Modern**: Following iOS design guidelines with custom branding

## ✨ Animation Details

- **Screen Transitions**: Fade in/out with easing
- **Button Taps**: Scale effect (0.95) with spring animation
- **Progress Indicators**: Linear animation with smooth interpolation
- **Recording Pulse**: Continuous scale animation while recording
- **Success Celebration**: Spring animation on score reveal
- **Loading States**: Rotation and orbit animations

## 📐 Layout Specifications

- **Screen Padding**: 24px horizontal
- **Card Spacing**: 16px between elements
- **Button Height**: 56px
- **Corner Radius**: 16px (cards), 12px (inputs)
- **Icon Sizes**: 24px (inline), 50px (featured)
- **Font Sizes**:
  - Title: 36px bold
  - Heading: 20-24px semibold
  - Body: 14-16px medium
  - Caption: 12-14px regular

## 🎯 Key Features Summary

✅ Beautiful, modern dark theme UI
✅ Smooth animations and transitions
✅ Intuitive navigation flow
✅ Real-time feedback and progress tracking
✅ Customizable AI preferences
✅ Professional data visualization
✅ Consistent design system
✅ Responsive layouts
✅ Accessibility considerations

---

**Ready to launch!** Open the project in Xcode and run on any iOS simulator or device.

