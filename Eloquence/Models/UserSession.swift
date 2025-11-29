//
//  UserSession.swift
//  Eloquence
//
//  Created by Johannes Gruber on 10.11.25.
//

import Foundation
import Combine

class UserSession: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userName: String = "Johannes"
    @Published var email: String = ""
    
    // Settings
    @Published var aiVoiceStyle: AIVoiceStyle = .neutral
    @Published var useCameraFeedback: Bool = true
    @Published var receiveWeeklySummary: Bool = true
    
    // Session tracking
    @Published var sessions: [PracticeSession] = [] {
        didSet {
            saveSessions()
        }
    }
    @Published var lastImprovement: Int = 0 {
        didSet {
            saveLastImprovement()
        }
    }
    
    // Projects
    @Published var projects: [Project] = [] {
        didSet {
            saveProjects()
        }
    }
    
    private let sessionsKey = "savedSessions"
    private let lastImprovementKey = "lastImprovement"
    private let projectsKey = "savedProjects"
    
    init() {
        loadSessions()
        loadLastImprovement()
        loadProjects()
    }
    
    func login(email: String, password: String) {
        // Simulate login
        self.email = email
        self.userName = "Johannes"
        self.isLoggedIn = true
        
        // Don't load mock data - use real sessions only
        // Sessions will be added when recordings are made
        // Sessions are loaded from persistence in init()
    }
    
    func logout() {
        self.isLoggedIn = false
        self.email = ""
        self.userName = "Johannes"
        // Don't clear sessions on logout - keep progress
    }
    
    func resetProgress() {
        self.sessions = []
        self.lastImprovement = 0
        // This will trigger saveSessions() and saveLastImprovement() via didSet
    }
    
    // MARK: - Persistence
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: sessionsKey)
        }
    }
    
    private func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([PracticeSession].self, from: data) {
            self.sessions = decoded
        }
    }
    
    private func saveLastImprovement() {
        UserDefaults.standard.set(lastImprovement, forKey: lastImprovementKey)
    }
    
    private func loadLastImprovement() {
        self.lastImprovement = UserDefaults.standard.integer(forKey: lastImprovementKey)
    }
    
    func addProject(_ project: Project) {
        projects.append(project)
    }
    
    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
    }
    
    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        // Also remove sessions associated with this project
        sessions.removeAll { $0.projectId == project.id }
    }
    
    private func saveProjects() {
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: projectsKey)
        }
    }
    
    private func loadProjects() {
        if let data = UserDefaults.standard.data(forKey: projectsKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            self.projects = decoded
        }
    }
    
    private func loadMockSessions() {
        // Create some mock session data for demonstration
        let calendar = Calendar.current
        let now = Date()
        
        sessions = [
            PracticeSession(
                date: calendar.date(byAdding: .day, value: -7, to: now)!,
                toneScore: 75,
                pacingScore: 68,
                gesturesScore: 70
            ),
            PracticeSession(
                date: calendar.date(byAdding: .day, value: -5, to: now)!,
                toneScore: 78,
                pacingScore: 72,
                gesturesScore: 75
            ),
            PracticeSession(
                date: calendar.date(byAdding: .day, value: -3, to: now)!,
                toneScore: 82,
                pacingScore: 76,
                gesturesScore: 78
            ),
            PracticeSession(
                date: calendar.date(byAdding: .day, value: -1, to: now)!,
                toneScore: 85,
                pacingScore: 80,
                gesturesScore: 82
            )
        ]
        
        lastImprovement = 12
    }
    
    func addSession(_ session: PracticeSession) {
        sessions.append(session)
        
        // Calculate improvement
        if sessions.count >= 2 {
            let previous = sessions[sessions.count - 2]
            let current = sessions[sessions.count - 1]
            let prevAvg = (previous.toneScore + previous.pacingScore + previous.gesturesScore) / 3
            let currAvg = (current.toneScore + current.pacingScore + current.gesturesScore) / 3
            lastImprovement = currAvg - prevAvg
        }
    }
    
    var averageScore: Int {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { $0 + ($1.toneScore + $1.pacingScore + $1.gesturesScore) / 3 }
        return total / sessions.count
    }
    
    var improvementPercentage: Int {
        guard sessions.count >= 2 else { return 0 }
        let first = sessions.first!
        let last = sessions.last!
        let firstAvg = (first.toneScore + first.pacingScore + first.gesturesScore) / 3
        let lastAvg = (last.toneScore + last.pacingScore + last.gesturesScore) / 3
        let improvement = ((lastAvg - firstAvg) * 100) / max(firstAvg, 1)
        return improvement
    }
}

enum AIVoiceStyle: String, CaseIterable {
    case neutral = "Neutral"
    case motivational = "Motivational"
    case analytical = "Analytical"
}

enum RecordingType: String, CaseIterable {
    case professional = "Professional"
    case education = "Education"
    case publicSpeech = "Public Speech"
    
    var icon: String {
        switch self {
        case .professional: return "briefcase.fill"
        case .education: return "book.fill"
        case .publicSpeech: return "megaphone.fill"
        }
    }
}

struct PracticeSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let toneScore: Int
    let pacingScore: Int
    let gesturesScore: Int
    var feedback: String = ""
    var recordingType: String?
    var projectId: UUID?

    // Gesture analysis details
    var gestureStrength: String?
    var gestureImprovement: String?
    var facialScore: Int?
    var postureScore: Int?
    var eyeContactScore: Int?
    var keyFrames: [KeyFrame]?

    var averageScore: Int {
        (toneScore + pacingScore + gesturesScore) / 3
    }

    init(id: UUID = UUID(), date: Date = Date(), toneScore: Int, pacingScore: Int, gesturesScore: Int, feedback: String = "", recordingType: String? = nil, projectId: UUID? = nil, gestureStrength: String? = nil, gestureImprovement: String? = nil, facialScore: Int? = nil, postureScore: Int? = nil, eyeContactScore: Int? = nil, keyFrames: [KeyFrame]? = nil) {
        self.id = id
        self.date = date
        self.toneScore = toneScore
        self.pacingScore = pacingScore
        self.gesturesScore = gesturesScore
        self.feedback = feedback
        self.recordingType = recordingType
        self.projectId = projectId
        self.gestureStrength = gestureStrength
        self.gestureImprovement = gestureImprovement
        self.facialScore = facialScore
        self.postureScore = postureScore
        self.eyeContactScore = eyeContactScore
        self.keyFrames = keyFrames
    }
}

struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    var dueDate: Date?
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), dueDate: Date? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.dueDate = dueDate
    }
}

