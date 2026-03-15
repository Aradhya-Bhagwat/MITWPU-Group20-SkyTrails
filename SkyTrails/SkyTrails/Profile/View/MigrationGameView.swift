import SwiftUI
internal import Combine

struct MigrationGameView: View {
    @Environment(\.dismiss) var dismiss
    @State private var score = 0
    @State private var timeRemaining = 30
    @State private var birds: [BirdInstance] = []
    @State private var gameActive = false
    @State private var showGameOver = false
    @State private var showExplanation = true
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let spawnTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    
    let birdAssets = [
        "falcon_amur", "tern_arctic", "fairy_bluebird_asian",
        "headed_goose_bar", "weaver_baya", "kite_black"
    ]
    
    struct BirdInstance: Identifiable {
        let id = UUID()
        let assetName: String
        var x: CGFloat
        var y: CGFloat
        let speed: Double
        var scale: CGFloat = 0.8
        var opacity: Double = 1.0
    }
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.4, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.4, blue: 0.7)]),
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
            
            // Clouds/Atmosphere
            ForEach(0..<5) { i in
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 200, height: 100)
                    .offset(x: CGFloat(i * 100) - 200, y: CGFloat(i * 150) - 300)
                    .blur(radius: 50)
            }
            
            // Birds
            ForEach(birds) { bird in
                Image(bird.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .scaleEffect(bird.scale)
                    .opacity(bird.opacity)
                    .position(x: bird.x, y: bird.y)
                    .onTapGesture {
                        tapBird(bird)
                    }
            }
            
            // HUD
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("SCORE")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("\(score)")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.black)
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("TIME")
                            .font(.caption)
                            .fontWeight(.bold)
                        Text("\(timeRemaining)s")
                            .font(.system(.title, design: .rounded))
                            .fontWeight(.black)
                            .foregroundColor(timeRemaining < 10 ? .red : .white)
                    }
                    .foregroundColor(.white)
                }
                .padding(.horizontal, 30)
                .padding(.top, 50)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("EXIT")
                        .fontWeight(.bold)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.3)))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 20)
            }
        }
        .onReceive(timer) { _ in
            if gameActive {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    gameActive = false
                    showGameOver = true
                }
            }
        }
        .onReceive(spawnTimer) { _ in
            if gameActive {
                spawnBird()
            }
        }
        .onAppear {
            // Game starts paused showing explanation
        }
        .overlay(
            Group {
                if showExplanation {
                    explanationOverlay
                } else if showGameOver {
                    gameOverOverlay
                }
            }
        )
    }

    var explanationOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "bird.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Help the Birds Migrate!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 12) {
                    BulletPoint(text: "Tap the birds as they fly across the screen.")
                    BulletPoint(text: "Each bird you help scores 1 point.")
                    BulletPoint(text: "You have 30 seconds to help as many as you can.")
                }
                .padding(.horizontal)
                
                Button(action: {
                    showExplanation = false
                    gameActive = true
                    for _ in 0..<3 { spawnBird() }
                }) {
                    Text("Start Migration")
                        .fontWeight(.bold)
                        .frame(width: 200)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
            }
            .padding(40)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(30)
            .padding()
        }
    }

    struct BulletPoint: View {
        let text: String
        var body: some View {
            HStack(alignment: .top) {
                Text("•").foregroundColor(.blue).fontWeight(.bold)
                Text(text).foregroundColor(.white.opacity(0.9))
            }
        }
    }
    
    var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Migration Complete! 🐦")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("You helped \(score) birds reach their destination.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                
                Button(action: {
                    score = 0
                    timeRemaining = 30
                    birds = []
                    showGameOver = false
                    gameActive = true
                }) {
                    Text("Play Again")
                        .fontWeight(.bold)
                        .frame(width: 200)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                }
                
                Button(action: { dismiss() }) {
                    Text("Back to Profile")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .padding(40)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(30)
            .padding()
        }
    }
    
    func spawnBird() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        let newBird = BirdInstance(
            assetName: birdAssets.randomElement() ?? "amur_falcon",
            x: -100,
            y: CGFloat.random(in: 150...(screenHeight - 150)),
            speed: Double.random(in: 2.0...4.0)
        )
        
        birds.append(newBird)
        
        withAnimation(.linear(duration: newBird.speed)) {
            if let index = birds.firstIndex(where: { $0.id == newBird.id }) {
                birds[index].x = screenWidth + 100
            }
        }
        
        // Remove bird after it crosses screen
        DispatchQueue.main.asyncAfter(deadline: .now() + newBird.speed) {
            birds.removeAll(where: { $0.id == newBird.id })
        }
    }
    
    func tapBird(_ bird: BirdInstance) {
        if let index = birds.firstIndex(where: { $0.id == bird.id }) {
            score += 1
            
            // Pop animation
            withAnimation(.spring()) {
                birds[index].scale = 1.5
                birds[index].opacity = 0
            }
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Remove after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                birds.removeAll(where: { $0.id == bird.id })
            }
        }
    }
}
