import SwiftUI
import SDWebImage
import SDWebImageSwiftUI

// MARK: - ExerciseImageLoader
//
// The ExerciseDB GIF endpoint (`/image?exerciseId=…`) requires the RapidAPI
// auth headers — a plain `AnimatedImage(url:)` returns 401 without them.
// We inject the headers into SDWebImage's downloader, scoped to the
// ExerciseDB host so no other image requests are affected.

enum ExerciseImageLoader {
    static func configure() {
        SDWebImageDownloader.shared.requestModifier =
            SDWebImageDownloaderRequestModifier { request in
                guard let host = request.url?.host,
                      host.contains(ExerciseDBService.imageHost) else { return request }
                var r = request
                r.setValue(Constants.exerciseDBAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
                r.setValue(ExerciseDBService.imageHost, forHTTPHeaderField: "X-RapidAPI-Host")
                return r
            }
    }
}

// MARK: - ExerciseCard
//
// Reusable card showing a looping GIF preview, the exercise name and a
// muscle-group tag. GIF decoding, lazy loading and disk caching are handled
// by SDWebImage's `AnimatedImage`.

struct ExerciseCard: View {
    let exercise: LibraryExercise

    var body: some View {
        HStack(spacing: 14) {
            ExerciseGIFView(urlString: exercise.gifUrl, cornerRadius: 14)
                .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    MuscleTag(text: exercise.bodyPart)
                    if !exercise.equipment.isEmpty {
                        Text(exercise.equipment.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - MuscleTag

struct MuscleTag: View {
    let text: String
    var body: some View {
        Text(text.capitalized)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(text.muscleColor.opacity(0.15))
            .foregroundStyle(text.muscleColor)
            .clipShape(Capsule())
    }
}

// MARK: - ExerciseGIFView
//
// Wraps `AnimatedImage` with a placeholder + fade, auto-looping by default.
// Reused by both the card and the detail screen (and ExerciseDetailView).

struct ExerciseGIFView: View {
    let urlString: String
    var cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            Color(.tertiarySystemBackground)

            if let url = URL(string: urlString), !urlString.isEmpty {
                AnimatedImage(url: url)
                    .indicator(SDWebImageActivityIndicator.medium)
                    .transition(.fade(duration: 0.25))
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
