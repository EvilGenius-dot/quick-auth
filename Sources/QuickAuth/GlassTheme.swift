import AppKit
import SwiftUI

extension Color {
  static let authAccent = Color(red: 0.88, green: 0.91, blue: 0.97)
  static let authCanvas = Color(red: 0.035, green: 0.039, blue: 0.050)
  static let authText = Color(red: 0.95, green: 0.96, blue: 0.98)
  static let authMuted = Color(red: 0.58, green: 0.61, blue: 0.67)
  static let authLine = Color.white.opacity(0.10)
}

/// The blur is drawn by the window server, so it samples the desktop behind
/// the app rather than blurring the account text inside the window.
private struct DesktopGlass: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .hudWindow
    view.blendingMode = .behindWindow
    view.state = .active
    view.appearance = NSAppearance(named: .darkAqua)
    return view
  }
  func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct AuthGlassBackground: View {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorSchemeContrast) private var contrast

  var body: some View {
    ZStack(alignment: .top) {
      if reduceTransparency || contrast == .increased {
        Color.authCanvas
      } else {
        DesktopGlass()
        LinearGradient(
          colors: [Color.black.opacity(0.42), Color.authCanvas.opacity(0.74)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
        RadialGradient(
          colors: [Color.white.opacity(0.055), .clear], center: .topLeading,
          startRadius: 0, endRadius: 390)
      }
      Rectangle()
        .fill(LinearGradient(colors: [.clear, .white.opacity(0.22), .clear],
                             startPoint: .leading, endPoint: .trailing))
        .frame(height: 1)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

extension View {
  func authGlassSurface() -> some View {
    self.background { AuthGlassBackground() }
      .foregroundStyle(Color.authText)
      .tint(.authAccent)
      .preferredColorScheme(.dark)
  }
}

struct AuthPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(Color(red: 0.07, green: 0.08, blue: 0.10))
      .padding(.horizontal, 14).padding(.vertical, 9)
      .background(
        LinearGradient(colors: [.white, .authAccent.opacity(0.9)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 8))
      .opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.35)
  }
}

struct AuthToolbarButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .padding(.horizontal, 10).padding(.vertical, 8)
      .foregroundStyle(Color.authText)
      .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.045),
                  in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.authLine))
      .opacity(enabled ? 1 : 0.35)
  }
}
