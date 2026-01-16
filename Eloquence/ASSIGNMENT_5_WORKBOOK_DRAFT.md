# Individual Design Workbook | Assignment 5: User Study & Evaluation

## 1. Study Design

### Goal
The primary goal of this study is to evaluate the core "Record-to-Feedback" loop of the Eloquence app. We aim to verify if users can intuitively record a speech and understand the AI-generated feedback without confusion. Specifically, we want to identify pain points in the `RecordingView` interface and the readability of the `FeedbackView` insights.

### Methodology
We will use a **Qualitative Usability Testing** approach with a **Think-Aloud Protocol**.
- **Format**: Moderated in-person sessions.
- **Procedure**: Participants will be given a scenario and asked to complete 3 specific tasks. They are instructed to speak their thoughts freely as they navigate the app.
- **Data Collection**: Notes will be taken on critical incidents (errors), points of confusion, and positive feedback.

### Participants
We have recruited 3 participants from our target demographic (students and young professionals who give presentations):
1.  **Participant A (Student, 22)**: Frequently gives class presentations. Tech-savvy but nervous about public speaking.
2.  **Participant B (Marketing Junior, 26)**: Gives weekly updates to teams. Wants to improve "professionalism" and body language.
3.  **Participant C (Family Member, 50)**: Occasional speaker. Less familiar with AI tools. Represents a "novice" user.

### Tasks
1.  **Task 1: Setup**: "You have a presentation coming up. Start a 'New Session' from the Dashboard to practice for it."
2.  **Task 2: Recording**: "Record yourself speaking for about 30 seconds. Imagine you are introducing yourself to a new team. Stop the recording when you are done."
3.  **Task 3: Analysis**: "Review the feedback provided. Find your 'Tone' score and read the detailed comment on one of the 'Visual Highlights' cards."

---

## 2. User Testing Notes

*(Notes taken during the sessions)*

### Participant A
- **Task 1**: Found the "Start New Session" button immediately.
- **Task 2**: Was unsure if the recording started immediately or if there was a countdown. *Quote: "Is it recording now? Oh, the timer is moving."*
- **Task 3**: Scrolled through feedback quickly. Tapped on a KeyFrame card to read more but complained the text was still cut off or hard to read. *Quote: "I can't read the whole advice here, clicking this chevron is kinda finicky."*

### Participant B
- **Task 1**: Smooth navigation.
- **Task 2**: Held the phone too low.
- **Task 3**: Waited a long time for the analysis to finish. *Quote: "Wow, this is taking a while... did it crash?"* When results appeared, they were confused by the "Eye Contact: Not Detected" message. *Quote: "I was looking at the camera! Why does it say not detected?"*

### Participant C
- **Task 1**: Hesitated. Didn't know if they needed to create a "Project" first or just hit "Start".
- **Task 2**: Successful.
- **Task 3**: Loved the "Overall Score" circle. Struggled to understand the difference between "Tone" and "Pacing". Did not notice the KeyFrame cards were interactive at all.

---

## 3. Findings and Improvement Ideas

### Summary of Findings
1.  **Analysis Latency**: Users feel uncertain during the long wait time for AI analysis. There is no progress bar or "working" state that explains what is happening (e.g., "Analyzing audio...", "Extracting frames...").
2.  **KeyFrame Card Usability**: The "Visual Highlights" cards have text that truncates. Users either don't realize they can expand the card (poor affordance) or find the tap target (chevron) too small.
3.  **Ambiguous "Eye Contact" Feedback**: When the camera angle is less than perfect, the app simply says "Not Detected," which users interpret as a system failure rather than a setup issue.

### Improvement Ideas

#### 1. Optimistic UI & Progress Feedback (Fixes Latency Uncertainty)
**Problem**: The "Analyzing..." screen is static and feels slow (due to serial GPT calls).
**Improvement**: Implement a granular progress stepper (e.g., "Uploading Video" -> "Analyzing Audio" -> "Detecting Gestures"). Additionally, start uploading/processing chunks of the video *while* the user is still on the recording screen if possible, or parallelize the requests.
* **Figma Pair**: [Link to Image: Current Spinner vs. Detailed Progress Stepper]

#### 2. Expandable Card Redesign (Fixes Truncation)
**Problem**: Long annotation text is cut off, and the expand chevron is subtle.
**Improvement**:
1.  Make the entire card the tap target for expansion, not just the chevron.
2.  Add a visible "Read more..." link text at the end of the truncated line to clearly indicate interactivity.
3.  Ensure the card animates smoothly to show full text without clipping.
* **Figma Pair**: [Link to Image: Current Cut-off Text vs. New "Read More" Layout]

#### 3. Smart Camera Guidance (Fixes Eye Contact Issues)
**Problem**: Users hold the phone too low, leading to "Eye Contact Not Detected".
**Improvement**: Add a "Pre-flight Check" overlay on the `RecordingView` *before* recording starts. Use the Vision framework to detect the face and show a message like "Hold phone higher" or "Move closer" until the face is centered and eyes are visible.
* **Figma Pair**: [Link to Image: Current Simple Camera View vs. AR Face Guide Overlay]
