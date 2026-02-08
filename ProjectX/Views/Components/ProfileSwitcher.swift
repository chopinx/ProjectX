import SwiftUI
import SwiftData

struct ProfileSwitcher: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Bindable var settings: AppSettings

    var activeProfile: Profile? {
        profiles.first { $0.id == settings.activeProfileId }
    }

    var body: some View {
        Menu {
            ForEach(profiles) { profile in
                Button {
                    settings.activeProfileId = profile.id
                } label: {
                    HStack {
                        Label(profile.name, systemImage: profile.iconName)
                        if profile.id == settings.activeProfileId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if let profile = activeProfile {
                    Image(systemName: profile.iconName)
                        .foregroundStyle(profile.color)
                    Text(profile.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "person.fill")
                    Text("Profile")
                        .font(.subheadline)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.regularMaterial)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Toolbar Profile Button

struct ProfileToolbarButton: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Bindable var settings: AppSettings

    var activeProfile: Profile? {
        profiles.first { $0.id == settings.activeProfileId }
    }

    var body: some View {
        Menu {
            ForEach(profiles) { profile in
                Button {
                    settings.activeProfileId = profile.id
                } label: {
                    HStack {
                        Label(profile.name, systemImage: profile.iconName)
                        if profile.id == settings.activeProfileId {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            if let profile = activeProfile {
                Image(systemName: profile.iconName)
                    .foregroundStyle(profile.color)
            } else {
                Image(systemName: "person.fill")
            }
        }
    }
}
