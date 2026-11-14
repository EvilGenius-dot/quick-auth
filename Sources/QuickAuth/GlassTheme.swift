import AppKit
import SwiftUI

extension Color {
  static let authAccent = Color(red: 0.68, green: 0.60, blue: 1.0)
  static let authBlue = Color(red: 0.51, green: 0.70, blue: 1.0)
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
          colors: [Color.black.opacity(0.64), Color.authCanvas.opacity(0.86)],
          startPoint: .topLeading, endPoint: .bottomTrailing)
        RadialGradient(
          colors: [Color.authAccent.opacity(0.12), .clear], center: .topLeading,
          startRadius: 0, endRadius: 390)
        RadialGradient(
          colors: [Color.authBlue.opacity(0.045), .clear], center: .bottomTrailing,
          startRadius: 0, endRadius: 280)
      }
      Rectangle()
        .fill(LinearGradient(colors: [.clear, .authAccent.opacity(0.45), .authBlue.opacity(0.3), .clear],
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
      .accentColor(.authAccent)
      .preferredColorScheme(.dark)
  }
}

struct AuthPrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(Color.white)
      .padding(.horizontal, 14).padding(.vertical, 9)
      .background(
        LinearGradient(colors: [Color(red: 0.46, green: 0.35, blue: 0.85),
                                Color(red: 0.23, green: 0.43, blue: 0.83)],
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
      .background(
        LinearGradient(colors: [Color.authAccent.opacity(configuration.isPressed ? 0.23 : 0.12),
                                Color.authBlue.opacity(0.045)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.authAccent.opacity(0.23)))
      .opacity(enabled ? 1 : 0.35)
  }
}
