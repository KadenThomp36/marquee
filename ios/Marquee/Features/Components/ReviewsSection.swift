import SwiftUI

/// The household's own reviews, then the wider world's.
///
/// The rule that shapes this: a review body is a spoiler until you've earned it. A
/// show's reviews stay veiled until you're caught up on every aired episode, an
/// episode's until you've watched it — and your own review is never veiled, because
/// you wrote it.
struct ReviewsSection: View {
    let itemType: String
    let itemID: Int
    /// True when the viewer has watched enough for the bodies to be safe.
    let hasEarnedSpoilers: Bool

    @Environment(Session.self) private var session
    @State private var reviews: [Review] = []
    @State private var external: [ExternalReview] = []
    @State private var editing: EditingReview?
    @State private var replyingTo: Review?
    @State private var deleteTarget: Review?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DetailSection(title: "Reviews", count: reviews.isEmpty ? nil : "\(reviews.count)") {
                VStack(spacing: 10) {
                    if let mine = reviews.first(where: \.mine) {
                        ReviewCard(review: mine, isVeiled: false,
                                   baseURL: session.server?.baseURL,
                                   onEdit: { editing = EditingReview(existing: mine) },
                                   onDelete: { deleteTarget = mine },
                                   onReply: { replyingTo = mine })
                    } else {
                        Button {
                            editing = EditingReview(existing: nil)
                        } label: {
                            Label("Write a review", systemImage: "square.and.pencil")
                                .font(.mqSub)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.mqBrass)
                        .mqPanel()
                    }

                    ForEach(reviews.filter { !$0.mine }) { review in
                        ReviewCard(review: review,
                                   isVeiled: !hasEarnedSpoilers,
                                   baseURL: session.server?.baseURL,
                                   onEdit: nil, onDelete: nil,
                                   onReply: { replyingTo = review })
                    }

                    if reviews.isEmpty {
                        Text("No reviews from the house yet — be the first.")
                            .font(.mqSub)
                            .foregroundStyle(Color.mqInkMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                }
                .padding(.horizontal, MQ.gutter)
            }

            if !external.isEmpty {
                DetailSection(title: "From the community", count: "\(external.count)") {
                    VStack(spacing: 10) {
                        ForEach(external.prefix(12)) { review in
                            ExternalReviewCard(review: review, isVeiled: !hasEarnedSpoilers)
                        }
                    }
                    .padding(.horizontal, MQ.gutter)
                }
            }
        }
        .task { await load() }
        .sheet(item: $editing) { draft in
            ReviewEditor(draft: draft) { rating, body in
                await post(rating: rating, body: body)
            }
        }
        .sheet(item: $replyingTo) { review in
            ReplyEditor(review: review) { body in
                await reply(to: review, body: body)
            }
        }
        .confirmationDialog("Delete your review?", isPresented: .init(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget { Task { await delete(target) } }
                deleteTarget = nil
            }
        }
    }

    // MARK: - Data

    private func load() async {
        guard let client = session.client else { return }
        if let response: ReviewsResponse = try? await client.get("reviews/\(itemType)/\(itemID)") {
            reviews = response.reviews
        }
        if let response: ExternalReviewsResponse =
            try? await client.get("external_reviews/\(itemType)/\(itemID)") {
            external = response.reviews
        }
    }

    private func post(rating: Int?, body: String) async {
        guard let client = session.client else { return }
        do {
            try await client.post("reviews/\(itemType)/\(itemID)",
                                  body: PostReviewRequest(rating: rating, body: body),
                                  as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .review(itemType: itemType, itemID: itemID, rating: rating, body: body)))
        }
        await load()
    }

    private func reply(to review: Review, body: String) async {
        guard let client = session.client else { return }
        _ = try? await client.post("review/\(review.id)/reply",
                                   body: PostReplyRequest(body: body), as: Empty.self)
        await load()
    }

    private func delete(_ review: Review) async {
        guard let client = session.client else { return }
        _ = try? await client.delete("review/\(review.id)", as: Empty.self)
        await load()
    }
}

struct EditingReview: Identifiable {
    let id = UUID()
    let existing: Review?
}

// MARK: - Cards

private struct ReviewCard: View {
    let review: Review
    let isVeiled: Bool
    let baseURL: URL?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    let onReply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                AvatarView(person: review.author, size: 30, baseURL: baseURL)
                VStack(alignment: .leading, spacing: 1) {
                    Text(review.author.name)
                        .font(MarqueeFont.body(13, .bold, relativeTo: .caption))
                        .foregroundStyle(Color.mqInk)
                    Text(MQTime.medium(review.updatedAt ?? review.createdAt))
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                }
                Spacer(minLength: 6)
                if let rating = review.rating {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").font(.system(size: 11))
                        Text("\(rating)").fontWeight(.bold)
                        Text("/10").font(.mqCaption).foregroundStyle(Color.mqInkMuted)
                    }
                    .font(MarqueeFont.body(13, .semibold, relativeTo: .caption))
                    .foregroundStyle(Color.mqBrass)
                }
                if onEdit != nil {
                    Menu {
                        Button("Edit", systemImage: "pencil") { onEdit?() }
                        Button("Delete", systemImage: "trash", role: .destructive) { onDelete?() }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.mqInkMuted)
                            .frame(width: 28, height: 28)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Review actions")
                }
            }

            if let body = review.body, !body.isEmpty {
                SpoilerVeil(isVeiled: isVeiled, label: "Spoiler") {
                    Text(body)
                        .font(.mqBody)
                        .foregroundStyle(Color.mqInkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if let replies = review.replies, !replies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(replies) { reply in
                        HStack(alignment: .top, spacing: 8) {
                            AvatarView(person: reply.author, size: 22, baseURL: baseURL)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(reply.author.name)
                                        .font(MarqueeFont.body(12, .bold, relativeTo: .caption2))
                                        .foregroundStyle(Color.mqInk)
                                    Text(MQTime.short(reply.createdAt))
                                        .font(MarqueeFont.body(11, .regular, relativeTo: .caption2))
                                        .foregroundStyle(Color.mqInkMuted)
                                }
                                Text(reply.body)
                                    .font(.mqSub)
                                    .foregroundStyle(Color.mqInkSoft)
                            }
                        }
                    }
                }
                .padding(.leading, 8)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.mqHairline).frame(width: 2)
                }
            }

            Button(action: onReply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
                    .font(.mqCaption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.mqInkMuted)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mqPanel()
    }
}

private struct ExternalReviewCard: View {
    let review: ExternalReview
    let isVeiled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(review.source)
                    .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(Color.mqInkMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.mqHairlineBold, lineWidth: 1))
                Text(review.author ?? "someone")
                    .font(MarqueeFont.body(12.5, .semibold, relativeTo: .caption))
                    .foregroundStyle(Color.mqInkSoft)
                Spacer(minLength: 4)
                if let rating = review.rating {
                    Label("\(rating)", systemImage: "star.fill")
                        .font(MarqueeFont.body(12, .semibold, relativeTo: .caption))
                        .foregroundStyle(Color.mqBrass)
                }
                if let likes = review.likes, likes > 0 {
                    Label("\(likes)", systemImage: "heart.fill")
                        .font(MarqueeFont.body(11, .medium, relativeTo: .caption2))
                        .foregroundStyle(Color.mqInkMuted)
                }
            }

            SpoilerVeil(isVeiled: isVeiled, label: "Spoiler") {
                ExpandableText(text: review.body, lineLimit: 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mqPanel()
    }
}

/// The frosted curtain over anything you haven't earned yet. One tap lifts it.
struct SpoilerVeil<Content: View>: View {
    let isVeiled: Bool
    var label = "Contains spoilers"
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var revealed = false

    private var covered: Bool { isVeiled && !revealed }

    var body: some View {
        content
            .blur(radius: covered && !reduceTransparency ? 9 : 0)
            .opacity(covered && reduceTransparency ? 0 : 1)
            .overlay {
                if covered {
                    ZStack {
                        RoundedRectangle(cornerRadius: MQ.radiusSmall)
                            .fill(Color.mqGround.opacity(reduceTransparency ? 1 : 0.55))
                        VStack(spacing: 2) {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(Color.mqBrass)
                            Text(label)
                                .font(MarqueeFont.body(11.5, .bold, relativeTo: .caption2))
                                .textCase(.uppercase)
                                .tracking(1.2)
                                .foregroundStyle(Color.mqBrassBright)
                            Text("Tap to reveal")
                                .font(MarqueeFont.body(11, .regular, relativeTo: .caption2))
                                .foregroundStyle(Color.mqInkSoft)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.mqPanelRaised.opacity(0.85), in: .capsule)
                    }
                }
            }
            .contentShape(.rect)
            .onTapGesture {
                guard covered else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { revealed = true }
            }
            .accessibilityElement(children: covered ? .ignore : .contain)
            .accessibilityLabel(covered ? "\(label). Double tap to reveal." : "")
            .accessibilityAddTraits(covered ? .isButton : [])
            .accessibilityAction(named: "Reveal") { revealed = true }
    }
}

// MARK: - Editors

private struct ReviewEditor: View {
    let draft: EditingReview
    let save: (Int?, String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int?
    @State private var text = ""
    @State private var busy = false

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your rating").mqEyebrowStyle()
                        Text("optional")
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                        Spacer()
                        StarRating(rating: $rating) { _ in }
                    }

                    TextEditor(text: $text)
                        .font(.mqBody)
                        .foregroundStyle(Color.mqInk)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 140)
                        .padding(10)
                        .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radiusSmall))
                        .overlay(RoundedRectangle(cornerRadius: MQ.radiusSmall)
                            .strokeBorder(Color.mqHairline, lineWidth: 1))
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("What did you think?")
                                    .font(.mqBody)
                                    .foregroundStyle(Color.mqInkMuted)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                    Spacer()
                }
                .padding(MQ.gutter)
            }
            .navigationTitle(draft.existing == nil ? "Write a review" : "Edit your review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(draft.existing == nil ? "Post" : "Save") {
                        busy = true
                        Task {
                            await save(rating, text.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(busy || (rating == nil && text.trimmingCharacters(in: .whitespaces).isEmpty))
                }
            }
        }
        .presentationBackground(Color.mqGround)
        .onAppear {
            rating = draft.existing?.rating
            text = draft.existing?.body ?? ""
        }
    }
}

private struct ReplyEditor: View {
    let review: Review
    let save: (String) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Replying to \(review.author.name)")
                        .font(.mqSub)
                        .foregroundStyle(Color.mqInkMuted)
                    TextEditor(text: $text)
                        .font(.mqBody)
                        .foregroundStyle(Color.mqInk)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 110)
                        .padding(10)
                        .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radiusSmall))
                        .overlay(RoundedRectangle(cornerRadius: MQ.radiusSmall)
                            .strokeBorder(Color.mqHairline, lineWidth: 1))
                    Spacer()
                }
                .padding(MQ.gutter)
            }
            .navigationTitle("Reply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        Task {
                            await save(text.trimmingCharacters(in: .whitespacesAndNewlines))
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.mqGround)
    }
}
