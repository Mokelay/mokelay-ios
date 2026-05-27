# mokelay-ios

Native SwiftUI client for rendering Mokelay page DSL on iOS.

## Local Run

1. Start `mokelay-server` on `http://127.0.0.1:8787`.
2. Open `MokelayIOS.xcodeproj` in Xcode.
3. Run the `MokelayIOS` scheme on an iOS Simulator.

The app starts with `PageScreen(uuid: "index")`, which calls:

```text
http://127.0.0.1:8787/api/mokelay/read_page_by_uuid?uuid=index
```

## Rendering Architecture

- `MokelayPageAPI` fetches pages by uuid.
- `MokelayPage`, `MokelayBlock`, and `JSONValue` decode the page DSL.
- `PageRenderer` renders the block list.
- `BlockRegistry` maps each `block.type` to a native SwiftUI renderer.
- `paragraph` is implemented first.
- Unknown blocks use `UnsupportedBlockRenderer`, so new web blocks can be added incrementally without breaking the page.

Future iOS block renderers should mirror the web block names from `mokelay-editor/src/blocks`, for example `MHeading`, `MRichText`, `MForm`, `MInput`, and `MPage`.
