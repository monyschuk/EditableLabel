//
//  EditableLabel.swift
//  Omega
//
//  Created by Mark Onyschuk on 2019-06-29.
//  Copyright © 2019 Mark Onyschuk. All rights reserved.
//

import SwiftUI

struct EditableLabel : NSViewRepresentable {
    @Binding var text: String
    
    var wraps: Bool = false
    var minWidth: CGFloat? = 0
    var maxWidth: CGFloat? = 144

    var didChange: (String)->() = { _ in }
    var didEndEditing: (String)->Bool = { _ in true }
    
    func makeCoordinator() -> EditableLabelCoordinator {
        return EditableLabelCoordinator(didChange: didChange, didEndEditing: didEndEditing)
    }
    
    func makeNSView(context: NSViewRepresentableContext<EditableLabel>) -> EditableLabelView {
        let view = EditableLabelView(text: "")

        view.wraps    = wraps
        view.minWidth = minWidth
        view.maxWidth = maxWidth

        view.delegate = context.coordinator

        return view
    }
    
    func updateNSView(_ view: EditableLabelView, context: NSViewRepresentableContext<EditableLabel>) {
        view.stringValue = text
    }
}

#if DEBUG
struct EditableLabel_Previews : PreviewProvider {
    static var previews: some View {
        EditableLabel(text: .constant("Hello World"))
    }
}
#endif

// MARK: - Coordinator

final class EditableLabelCoordinator: NSObject, NSTextFieldDelegate {
    var didChange: (String)->()
    var didEndEditing: (String)->Bool

    init(didChange: @escaping (String)->(), didEndEditing: @escaping (String)->Bool) {
        self.didChange = didChange; self.didEndEditing = didEndEditing
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else {
            return
        }
        
        didChange(textField.stringValue)
    }
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else {
            return
        }

        if didEndEditing(textField.stringValue) {
            textField.target = self
            textField.action = #selector(endEditing(_:))
        }
    }
    
    @IBAction func endEditing(_ sender: NSTextField) {
        sender.window?.makeFirstResponder(sender.window?.contentView)
        
        sender.target = nil
        sender.action = nil

    }
}

// MARK: - View

final class EditableLabelView: NSTextField {
    var minWidth: CGFloat? {
        didSet {
            needsUpdate()
        }
    }
    
    var maxWidth: CGFloat? {
        didSet {
            needsUpdate()
        }
    }

    lazy var maxConstraint: NSLayoutConstraint = {
        return widthAnchor.constraint(lessThanOrEqualToConstant: 1)
    }()
    lazy var minConstraint: NSLayoutConstraint = {
        return widthAnchor.constraint(greaterThanOrEqualToConstant: 1)
    }()
    

    @IBInspectable
    var wraps: Bool = false {
        didSet {
            if let cell = cell as? NSTextFieldCell {
                cell.wraps = wraps
                cell.isScrollable = !wraps
            }
            needsUpdate()
        }
    }

    private func needsUpdate() {
        self.needsUpdateConstraints = true
    }
    override func updateConstraints() {
        super.updateConstraints()
        
        minConstraint.isActive = false
        maxConstraint.isActive = false
        
        if wraps {
            let minW = minWidth ?? -1
            let maxW = maxWidth ?? -1

            let width = max(minW, maxW)

            if width != -1 {
                minConstraint.constant = width
                minConstraint.isActive = true
                
                maxConstraint.constant = width
                maxConstraint.isActive = true
            }
        } else {
            if let width = minWidth {
                minConstraint.constant = width
                minConstraint.isActive = true
            }
            if let width = maxWidth {
                maxConstraint.constant = width
                maxConstraint.isActive = true
            }
        }
    }
    

    // MARK: - Layout
    
    @objc override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: NSSize {
        var size = CGSize.zero
        
        if let fieldEditor = self.currentEditor() as? NSTextView, let clipView = fieldEditor.superview as? NSClipView {
            if wraps {
                // the field editor may scroll slightly during edits
                // regardless of whether we specify the cell to be scrollable:
                // as a result, we fix the field editor's width prior to calculating height
                
                let clipBounds = clipView.bounds
                var frame = fieldEditor.frame
                
                if NSWidth(frame) > NSWidth(clipBounds) {
                    frame.size.width = NSWidth(clipBounds)
                    fieldEditor.frame = frame
                }
            }
            
            if let textContainer = fieldEditor.textContainer, let layoutManager = fieldEditor.layoutManager {
                let usedRect = layoutManager.usedRect(for: textContainer)
                let clipRect = convert(clipView.bounds, from: fieldEditor.superview)
                
                let clipDelta = NSSize(width: NSWidth(bounds) - NSWidth(clipRect), height: NSHeight(bounds) - NSHeight(clipRect))
                
                if wraps {
                    let minHeight = layoutManager.defaultLineHeight(for: font!)
                    size = NSSize(width: NSView.noIntrinsicMetric, height: max(NSHeight(usedRect), minHeight) + clipDelta.height)
                } else {
                    size = NSSize(width: ceil(NSWidth(usedRect) + clipDelta.width), height: NSHeight(usedRect) + clipDelta.height)
                }
            }
        } else {
            if let cell = cell as? NSTextFieldCell {
                if wraps {
                    // oddly, this sometimes gives incorrect results -
                    // if anyone has any ideas please issue a pull request
                    
                    size = cell.cellSize(forBounds: NSMakeRect(0, 0, NSWidth(bounds), CGFloat.greatestFiniteMagnitude))
                    
                    size.width = NSView.noIntrinsicMetric
                    size.height = ceil(size.height)
                    
                } else {
                    size = cell.cellSize(forBounds: NSMakeRect(0, 0, CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude))
                    
                    size.width = ceil(size.width)
                    size.height = ceil(size.height)
                }
            }
        }
        
        if let font = self.font {
            size.height = max(
                EditableLabelView.lm.defaultLineHeight(for: font),
                size.height
            )
        }
        
        return size
    }
    
    private static var lm = NSLayoutManager()
    
    // MARK: - Lifecycle
    
    init(text: String) {
        super.init(frame: .zero)
        configure(text: text)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure(text: stringValue)
    }
    
    private func configure(text: String?) {
        isBordered = false
        
        focusRingType = .none
        drawsBackground = false
        
        // FIXME: this doesn't work...
        lineBreakMode = .byTruncatingTail

        if let stringValue = text {
            self.stringValue = stringValue
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        if let cell = cell as? NSTextFieldCell {
            cell.wraps = wraps
            cell.isScrollable = !wraps
            cell.truncatesLastVisibleLine = true
        }
    }
}
