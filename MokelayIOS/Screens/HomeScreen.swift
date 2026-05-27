import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct HomeScreen: View {
    @State private var pageUUID = ""
    @State private var destinationUUID: String?
    @State private var isShowingPage = false
    @FocusState private var isUUIDFieldFocused: Bool

    private var trimmedUUID: String {
        pageUUID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canNavigate: Bool {
        !trimmedUUID.isEmpty
    }

    var body: some View {
        let view = ZStack {
            systemBackgroundColor
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 64)

                logo

                VStack(spacing: 16) {
                    uuidInput
                    jumpButton
                }
                .frame(maxWidth: 520)

                NavigationLink(isActive: $isShowingPage) {
                    if let destinationUUID {
                        PageScreen(uuid: destinationUUID)
                    } else {
                        EmptyView()
                    }
                } label: {
                    EmptyView()
                }
                .hidden()

                Spacer(minLength: 120)
            }
            .padding(.horizontal, 28)
        }

        #if os(iOS)
        return view.navigationBarHidden(true)
        #else
        return view
        #endif
    }

    private var logo: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.19, blue: 0.16))
                    .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 10)

                Text("M")
                    .font(.system(size: 70, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.84, green: 0.96, blue: 0.42))
                    .offset(y: -1)
            }
            .frame(width: 108, height: 108)

            Text("Mokelay")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mokelay")
    }

    private var uuidInput: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)

            TextField("请输入页面UUID", text: $pageUUID)
                .focused($isUUIDFieldFocused)
                .submitLabel(.go)
                .mokelayUUIDInputBehavior()
                .onSubmit(navigateToPage)
                .font(.body)
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .background(inputBackgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
    }

    private var jumpButton: some View {
        Button(action: navigateToPage) {
            Text("跳转")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!canNavigate)
    }

    private func navigateToPage() {
        guard canNavigate else {
            return
        }

        destinationUUID = trimmedUUID
        isUUIDFieldFocused = false
        isShowingPage = true
    }

    private var systemBackgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.systemBackground)
        #elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.clear
        #endif
    }

    private var inputBackgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }
}

private extension View {
    @ViewBuilder
    func mokelayUUIDInputBehavior() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
        #else
        self
        #endif
    }
}
