import SwiftUI

public struct FocusModeWelcomeView: View {
    @Binding var isPresented: Bool
    var onEnter: () -> Void
    
    public init(isPresented: Binding<Bool>, onEnter: @escaping () -> Void) {
        self._isPresented = isPresented
        self.onEnter = onEnter
    }
    
    public var body: some View {
        VStack(spacing: 24) {
             Image(systemName: "moon.stars.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
            
            Text("Prepare for Deep Reading")
                .font(.largeTitle.bold())
            
            VStack(alignment: .leading, spacing: 16) {
                TipRow(icon: "iphone.slash", text: "Put your phone away or on silent")
                TipRow(icon: "bell.slash", text: "Enable Do Not Disturb in System Settings")
                
                Divider()
                
                Text("Controls")
                    .font(.headline)
                
                TipRow(icon: "arrow.left.and.right", text: "Left/Right Arrow to turn pages")
                TipRow(icon: "note.text", text: "Cmd + N: Toggle Notes")
                TipRow(icon: "sparkles", text: "Cmd + I: Ask Book (AI)")
                TipRow(icon: "arrow.up.left.and.arrow.down.right", text: "Cmd + Shift + F: Toggle Focus")
                TipRow(icon: "escape", text: "Escape: Exit Focus Mode")
            }
            .padding(.horizontal)
            
            Button("Enter Focus Mode") {
                onEnter()
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.borderless)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 20)
    }
}

struct TipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
        }
    }
}
