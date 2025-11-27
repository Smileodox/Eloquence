# Camera Setup - REQUIRED!

## 🎥 Add Camera & Microphone Permissions

**You must add these permissions or the camera won't work!**

### Steps in Xcode:

1. Open `Eloquence.xcodeproj` in Xcode
2. Select the **Eloquence** project in the navigator (left side)
3. Select the **Eloquence** target
4. Go to the **Info** tab
5. Find **Custom iOS Target Properties**
6. Hover over any row and click the **+** button

### Add These Two Permissions:

#### Permission 1: Camera
- **Key**: `Privacy - Camera Usage Description`
- **Type**: String
- **Value**: `Eloquence needs camera access to record your practice sessions.`

#### Permission 2: Microphone
- **Key**: `Privacy - Microphone Usage Description`
- **Type**: String  
- **Value**: `Eloquence needs microphone access to record audio during practice.`

### Quick Steps:
```
1. Xcode → Select Project → Select Target
2. Info tab → Custom iOS Target Properties
3. Click + button
4. Add "Privacy - Camera Usage Description"
5. Click + button again
6. Add "Privacy - Microphone Usage Description"
7. Clean Build (Cmd+Shift+K)
8. Build and Run (Cmd+R)
```

**Without these permissions, the app will crash when trying to access the camera!**

