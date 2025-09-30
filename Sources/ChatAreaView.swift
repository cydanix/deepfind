import SwiftUI
import AppKit

struct ChatAreaView: View {
    let messages: [ChatMessage]
    @ObservedObject var folderIndexer: FolderIndexer
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty {
                        VStack(spacing: 20) {
                            if folderIndexer.indexedFolderPath != nil {
                                VStack(spacing: 16) {
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 48))
                                        .foregroundColor(.blue.opacity(0.6))
                                    
                                    Text("Ready to Chat!")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Your knowledge base is ready. Ask any question about your documents below.")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                                
                                // Sample questions
                                VStack(spacing: 8) {
                                    Text("Try asking:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    
                                    VStack(spacing: 6) {
                                        Text("• \"Summarize the main points\"")
                                        Text("• \"What are the key findings?\"")
                                        Text("• \"Explain the methodology\"")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.8))
                                }
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "arrow.up")
                                        .font(.system(size: 32))
                                        .foregroundColor(.blue.opacity(0.6))
                                    
                                    Text("Set up your knowledge base above to start chatting")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 100)
                            }
                        }
                    } else {
                        ForEach(messages) { message in
                            ChatMessageView(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) {
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ChatMessageView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
                
                Text(message.content)
                    .padding(12)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(message.content, forType: .string)
                        }
                        
                        if #available(macOS 13.0, *) {
                            ShareLink("Share", item: message.content)
                        }
                    }
            } else {
                Text(message.content)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .textSelection(.enabled)
                    .contextMenu {
                        Button("Copy") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(message.content, forType: .string)
                        }
                        
                        if #available(macOS 13.0, *) {
                            ShareLink("Share", item: message.content)
                        }
                    }
                
                Spacer(minLength: 60)
            }
        }
    }
}
