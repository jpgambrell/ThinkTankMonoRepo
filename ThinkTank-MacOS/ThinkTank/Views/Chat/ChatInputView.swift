//
//  ChatInputView.swift
//  ThinkTank
//
//  Created by John Gambrell on 1/29/26.
//

import SwiftUI
import AppKit

struct ChatInputView: View {
    @Binding var messageText: String
    let isLoading: Bool
    let onSend: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var textHeight: CGFloat = 26 // Single line height with padding
    
    private let minHeight: CGFloat = 26
    private let maxHeight: CGFloat = 120
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                // Attachment Button (placeholder)
                Button(action: {
                    // Attachment functionality placeholder
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(ThemeColors.placeholderText(colorScheme))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .stroke(ThemeColors.border(colorScheme), lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .help("Attach file")
                
                // Text Input
                HStack(alignment: .bottom, spacing: 8) {
                    ChatTextEditor(
                        text: $messageText,
                        textHeight: $textHeight,
                        minHeight: minHeight,
                        maxHeight: maxHeight,
                        onSubmit: {
                            if canSend {
                                onSend()
                            }
                        },
                        colorScheme: colorScheme
                    )
                    .frame(height: min(max(textHeight, minHeight), maxHeight))
                    
                    // Send Button
                    Button(action: onSend) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(canSend ? .white : ThemeColors.placeholderText(colorScheme))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(canSend ? Color.brandPrimary : ThemeColors.border(colorScheme))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .help("Send message (Enter)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(ThemeColors.inputBackground(colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(ThemeColors.border(colorScheme), lineWidth: 1)
                )
            }
            .padding(.horizontal, 40)
            
            // Keyboard shortcut hint
            Text("Press Enter to send • Shift+Enter for new line")
                .font(.system(size: 11))
                .foregroundStyle(ThemeColors.placeholderText(colorScheme))
        }
        .padding(.vertical, 16)
        .background(ThemeColors.cardBackground(colorScheme))
        .animation(.easeOut(duration: 0.1), value: textHeight)
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }
}

// MARK: - Custom Text Editor with Enter/Shift+Enter handling
struct ChatTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var textHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let onSubmit: () -> Void
    let colorScheme: ColorScheme
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = ChatNSTextView()
        
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 0, height: 4)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.autoresizingMask = [.width]
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        
        // Set initial text
        textView.string = text
        
        // Make it first responder after a short delay
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
            context.coordinator.updateHeight()
        }
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ChatNSTextView else { return }
        
        // Update text if changed externally (e.g., cleared after send)
        if textView.string != text {
            textView.string = text
            context.coordinator.updateHeight()
        }
        
        // Update text color based on color scheme
        textView.textColor = colorScheme == .dark ? NSColor(Color(hex: "F0F0F0")) : NSColor(Color(hex: "1A1A1A"))
        
        // Update placeholder visibility
        textView.needsDisplay = true
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ChatTextEditor
        weak var textView: ChatNSTextView?
        weak var scrollView: NSScrollView?
        
        init(_ parent: ChatTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            updateHeight()
        }
        
        func updateHeight() {
            guard let textView = textView else { return }
            
            // Force layout
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
            
            // Calculate the height needed for the text
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }
            
            let usedRect = layoutManager.usedRect(for: textContainer)
            // Add textContainerInset (top + bottom = 8) to the content height
            let newHeight = max(usedRect.height + 8, parent.minHeight)
            
            DispatchQueue.main.async {
                self.parent.textHeight = newHeight
                
                // Show/hide scrollbar based on whether content exceeds max height
                if newHeight > self.parent.maxHeight {
                    self.scrollView?.hasVerticalScroller = true
                } else {
                    self.scrollView?.hasVerticalScroller = false
                }
            }
        }
    }
}

// MARK: - Custom NSTextView that handles Enter key
class ChatNSTextView: NSTextView {
    var onSubmit: (() -> Void)?
    
    override func keyDown(with event: NSEvent) {
        // Check for Enter key (keyCode 36) or Return key on numpad (keyCode 76)
        if event.keyCode == 36 || event.keyCode == 76 {
            // Shift+Enter: insert new line
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)
            } else {
                // Enter without shift: submit
                onSubmit?()
            }
        } else {
            super.keyDown(with: event)
        }
    }
    
    // Draw placeholder when empty
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if string.isEmpty {
            let placeholder = "Message ThinkTank..."
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 14)
            ]
            // Account for textContainerInset
            let inset = textContainerInset
            let rect = NSRect(x: 2, y: inset.height, width: bounds.width - 4, height: bounds.height - inset.height * 2)
            placeholder.draw(in: rect, withAttributes: attrs)
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        needsDisplay = true
        return result
    }
}

#Preview {
    ChatInputView(
        messageText: .constant(""),
        isLoading: false,
        onSend: {}
    )
    .frame(width: 800)
}
