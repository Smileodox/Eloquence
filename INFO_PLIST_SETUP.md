# Info.plist Setup Guide

## 📋 Required Permissions for Production

When you're ready to implement real recording functionality, you'll need to add these permissions to your `Info.plist` file.

### How to Add Permissions in Xcode

1. Open the Eloquence project in Xcode
2. Select the **Eloquence** target in the project navigator
3. Go to the **Info** tab
4. Right-click in the list and select **"Add Row"**
5. Add each permission below

---

## 🎤 Microphone Permission

**Key:** `NSMicrophoneUsageDescription`
**Type:** String
**Value:** 
```
Eloquence needs access to your microphone to analyze your presentation tone, pacing, and vocal clarity.
```

### XML Format (if editing Info.plist directly)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Eloquence needs access to your microphone to analyze your presentation tone, pacing, and vocal clarity.</string>
```

---

## 📹 Camera Permission

**Key:** `NSCameraUsageDescription`
**Type:** String
**Value:**
```
Eloquence needs access to your camera to analyze your body language and gestures during presentations.
```

### XML Format
```xml
<key>NSCameraUsageDescription</key>
<string>Eloquence needs access to your camera to analyze your body language and gestures during presentations.</string>
```

---

## 📊 Photo Library Permission (Optional)

If you want users to save session recordings:

**Key:** `NSPhotoLibraryAddUsageDescription`
**Type:** String
**Value:**
```
Eloquence would like to save your practice session recordings to your photo library.
```

### XML Format
```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Eloquence would like to save your practice session recordings to your photo library.</string>
```

---

## 🔊 Speech Recognition Permission (Future Feature)

**Key:** `NSSpeechRecognitionUsageDescription`
**Type:** String
**Value:**
```
Eloquence uses speech recognition to analyze your word choice, filler words, and speaking patterns.
```

### XML Format
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Eloquence uses speech recognition to analyze your word choice, filler words, and speaking patterns.</string>
```

---

## 📱 Complete Info.plist Example

Here's what your Info.plist should look like with all permissions:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing keys... -->
    
    <!-- Eloquence Permissions -->
    <key>NSMicrophoneUsageDescription</key>
    <string>Eloquence needs access to your microphone to analyze your presentation tone, pacing, and vocal clarity.</string>
    
    <key>NSCameraUsageDescription</key>
    <string>Eloquence needs access to your camera to analyze your body language and gestures during presentations.</string>
    
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>Eloquence would like to save your practice session recordings to your photo library.</string>
    
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Eloquence uses speech recognition to analyze your word choice, filler words, and speaking patterns.</string>
</dict>
</plist>
```

---

## 🧪 Testing Permissions

### In Simulator
1. Build and run the app
2. When you request permission, a system alert will appear
3. Grant or deny permission
4. Test your recording functionality

### Reset Permissions (for testing)
To reset permissions in the simulator:
1. Settings app → General → Reset → Reset Location & Privacy
2. Or delete and reinstall the app

### In Physical Device
Same as simulator, but permissions persist until:
- App is uninstalled
- Settings → Privacy & Security → [Permission Type] → Eloquence (toggle)

---

## 🔐 Privacy Best Practices

### Always:
✅ Request permission only when needed (not on launch)
✅ Explain why you need the permission
✅ Provide value before asking
✅ Handle denied permissions gracefully
✅ Provide alternative functionality if possible

### Never:
❌ Request all permissions at once
❌ Use generic permission descriptions
❌ Assume permission is granted
❌ Block functionality if permission is denied (when avoidable)

---

## 💻 Code Example: Requesting Microphone Permission

Add this to your `RecordingView.swift`:

```swift
import AVFoundation

func requestMicrophonePermission() {
    AVAudioSession.sharedInstance().requestRecordPermission { granted in
        DispatchQueue.main.async {
            if granted {
                print("Microphone permission granted")
                // Start recording
            } else {
                print("Microphone permission denied")
                // Show alert explaining why permission is needed
                showPermissionDeniedAlert()
            }
        }
    }
}

func showPermissionDeniedAlert() {
    // Show alert with option to open Settings
    let alert = UIAlertController(
        title: "Microphone Access Required",
        message: "Please enable microphone access in Settings to record practice sessions.",
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    })
    
    // Present alert
    // (You'll need to get the current UIViewController)
}
```

---

## 📝 App Store Submission Notes

When submitting to the App Store, Apple will:
1. Review your Info.plist permission descriptions
2. Test that your app handles denied permissions
3. Verify permissions are used as described

### Tips:
- Be specific about why each permission is needed
- Match your permission usage to your app description
- Test thoroughly before submission

---

## 🎯 Implementation Checklist

Before going to production:

- [ ] Add all required permissions to Info.plist
- [ ] Implement permission request logic
- [ ] Handle permission denial gracefully
- [ ] Add "Go to Settings" option for denied permissions
- [ ] Test on physical device (not just simulator)
- [ ] Verify permission alerts show correct descriptions
- [ ] Test with permissions granted and denied
- [ ] Add error handling for all recording scenarios

---

## 🔗 Apple Documentation

- [Requesting Authorization for Media Capture](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/requesting_authorization_for_media_capture_on_ios)
- [Protecting User Privacy](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)
- [Info.plist Keys](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Introduction/Introduction.html)

---

**Note:** The current demo version works without these permissions since it doesn't actually record. Add these when implementing real recording functionality.

