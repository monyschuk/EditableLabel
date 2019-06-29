# EditableLabel
A SwiftUI OSX `TextField` alternative with autoresizing, wrapping support

SwiftUI's TextField component for OSX works well in standard form-style interfaces, but falls short when what's needed is an auto-resizing, unbordered, optionally wrapping text input area. To fill the gap, I've repurposed an older NSTextField subclass that I've used in past, as a SwiftUI `NSViewRepresentable` component.

`EditableLabel` offers a `text` binding, optional min- and max- width constraints, with scrolling or line wrapping support. Its two associated closures - `didChange` and `didEndEditing` differ slightly from their equivalents on `TextField` in that both provide the current string value as an argument. The `didEndEditing` closure also returns a `Bool` value which, if true, will dismiss the field editor. 

## Sample Body Usage
Here's some code from a scratchpad View I've created, showing how `EditableLabel` can be used:

```
    var body: some View {
        VStack {
            ForEach(store.project(OrderedPages())) {
                page in
                
                // NOTE: since `didEndEditing` is passed the string value
                // we don't strictly need to maintain an @State property to
                // track the field's contents, and can pass a `.constant(...)` 
                // binding instead. This is optional, but can be handy at times.
                
                EditableLabel(text: .constant(page.name)) {
                    value in
                    self.store.dispatch(RenamePage(id: page.id, name: value))
                    return true
                }
            }
        }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
```

## TODOs or Welcomed PRs
More configuration, formatter support, I'm sure there's lots...

## License

MIT
