import SwiftUI

struct AppearanceSection: View {
    @Environment(AppServices.self) private var services
    @Environment(\.appTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var changingIcon = false
    @State private var iconUnavailable = false

    var body: some View {
        @Bindable var preferences = services.preferences
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: typeSize >= .accessibility3 ? 1 : typeSize.isAccessibilitySize ? 2 : 3), spacing: 18) {
                ForEach(AppTheme.allCases) { option in
                    themeButton(option)
                }
            }
            .padding(.vertical, 12)
            Picker(L10n.text("Appearance"), selection: $preferences.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .pickerStyle(.menu)
        } header: { Text(L10n.text("Appearance")) } footer: {
            if iconUnavailable {
                Text(L10n.text("The theme changed. The app icon couldn't be changed this time."))
            }
        }
    }

    private func themeButton(_ option: AppTheme) -> some View {
        let selected = theme == option
        let layout = typeSize >= .accessibility3
            ? AnyLayout(HStackLayout(spacing: 16))
            : AnyLayout(VStackLayout(spacing: 8))
        return Button {
            services.preferences.theme = option
            Task { await changeIcon(to: option) }
        } label: {
            layout {
                Image(option.previewName).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(5)
                    .overlay {
                        RoundedRectangle(cornerRadius: 19)
                            .strokeBorder(selected ? theme.accent : .clear, lineWidth: 2)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(theme.onAccent, theme.accent)
                                .background(.background, in: Circle())
                        }
                    }
                Text(option.title).font(.subheadline.weight(selected ? .semibold : .regular))
                    .foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: typeSize >= .accessibility3 ? .leading : .center).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(changingIcon)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func changeIcon(to theme: AppTheme) async {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != theme.iconName else { return }
        changingIcon = true
        iconUnavailable = false
        defer { changingIcon = false }
        do { try await UIApplication.shared.setAlternateIconName(theme.iconName) }
        catch { iconUnavailable = true }
    }
}
