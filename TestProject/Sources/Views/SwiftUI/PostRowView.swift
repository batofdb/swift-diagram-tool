import SwiftUI
import Combine

// MARK: - Post Row View

@available(iOS 14.0, *)
public struct PostRowView: View {
    let post: Post
    
    @StateObject private var viewModel: PostRowViewModel
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var postStore: PostStore
    
    @State private var isShowingComments = false
    @State private var isShowingShareSheet = false
    @State private var isShowingOptions = false
    @State private var hasAppeared = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    // MARK: - Initializer
    
    public init(post: Post) {
        self.post = post
        self._viewModel = StateObject(wrappedValue: PostRowViewModel(post: post))
    }
    
    // MARK: - Body
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            contentView
            attachmentsView
            tagsView
            actionButtonsView
            statisticsView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: shadowColor, radius: 2, x: 0, y: 1)
        .onAppear {
            if !hasAppeared {
                viewModel.trackView()
                hasAppeared = true
            }
        }
        .sheet(isPresented: $isShowingComments) {
            CommentsView(postId: post.id)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(items: [viewModel.shareURL])
        }
        .actionSheet(isPresented: $isShowingOptions) {
            optionsActionSheet
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 12) {
            AsyncImage(url: viewModel.authorAvatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(viewModel.authorDisplayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if viewModel.isAuthorVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                HStack {
                    Text(viewModel.formattedPublishDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if post.hasBeenEdited {
                        Text("• Edited")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(viewModel.estimatedReadTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { isShowingOptions = true }) {
                Image(systemName: "ellipsis")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.leading)
                .foregroundColor(.primary)
            
            if let excerpt = post.excerpt {
                Text(excerpt)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            } else {
                Text(viewModel.contentPreview)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            if post.content.count > 500 {
                Button("Read more...") {
                    // Navigate to full post
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
    }
    
    // MARK: - Attachments View
    
    @ViewBuilder
    private var attachmentsView: some View {
        if !post.attachments.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(post.imageAttachments, id: \.id) { attachment in
                        AsyncImage(url: attachment.url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .overlay {
                                    ProgressView()
                                }
                        }
                        .frame(width: 120, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    if post.attachments.count > post.imageAttachments.count {
                        Button("+\(post.attachments.count - post.imageAttachments.count) more") {
                            // Show all attachments
                        }
                        .frame(width: 120, height: 80)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
    
    // MARK: - Tags View
    
    @ViewBuilder
    private var tagsView: some View {
        if !post.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(post.tags), id: \.id) { tag in
                        TagView(tag: tag)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }
    
    // MARK: - Action Buttons View
    
    private var actionButtonsView: some View {
        HStack(spacing: 24) {
            Button(action: { viewModel.toggleLike() }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.isLiked ? "heart.fill" : "heart")
                        .foregroundColor(viewModel.isLiked ? .red : .secondary)
                    Text("\(viewModel.likeCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: { isShowingComments = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(.secondary)
                    Text("\(post.statistics.commentCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: { isShowingShareSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.secondary)
                    Text("\(post.statistics.shareCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { viewModel.toggleBookmark() }) {
                Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundColor(viewModel.isBookmarked ? .accentColor : .secondary)
            }
        }
        .font(.title3)
    }
    
    // MARK: - Statistics View
    
    private var statisticsView: some View {
        HStack(spacing: 16) {
            Label("\(post.statistics.viewCount)", systemImage: "eye")
            
            if post.statistics.engagementRate > 0 {
                Label("\(Int(post.statistics.engagementRate * 100))%", systemImage: "chart.line.uptrend.xyaxis")
            }
            
            Spacer()
            
            Text(viewModel.relativePublishDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    
    // MARK: - Computed Properties
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(colorScheme == .dark ? Color(.systemGray6) : Color(.systemBackground))
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.clear : Color.black.opacity(0.1)
    }
    
    private var optionsActionSheet: ActionSheet {
        ActionSheet(
            title: Text(post.title),
            buttons: [
                .default(Text("Share")) { isShowingShareSheet = true },
                .default(Text("Report")) { viewModel.reportPost() },
                .default(Text("Hide")) { viewModel.hidePost() },
                .cancel()
            ]
        )
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: { viewModel.toggleBookmark() }) {
            Label(viewModel.isBookmarked ? "Remove Bookmark" : "Bookmark", 
                  systemImage: viewModel.isBookmarked ? "bookmark.slash" : "bookmark")
        }
        
        Button(action: { isShowingShareSheet = true }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        
        Button(action: { viewModel.copyLink() }) {
            Label("Copy Link", systemImage: "link")
        }
        
        Divider()
        
        Button(action: { viewModel.reportPost() }) {
            Label("Report", systemImage: "flag")
        }
        
        Button(action: { viewModel.hidePost() }) {
            Label("Hide", systemImage: "eye.slash")
        }
    }
}

// MARK: - Post Row View Model

@MainActor
public class PostRowViewModel: ObservableObject {
    let post: Post
    
    @Published var isLiked: Bool = false
    @Published var isBookmarked: Bool = false
    @Published var likeCount: Int = 0
    @Published var authorDisplayName: String = ""
    @Published var authorAvatarURL: URL?
    @Published var isAuthorVerified: Bool = false
    
    private let userService: UserService
    private let postService: PostService
    private let analyticsService: AnalyticsService
    private var cancellables = Set<AnyCancellable>()
    
    public init(post: Post, 
                userService: UserService = UserService.shared,
                postService: PostService = PostService.shared,
                analyticsService: AnalyticsService = AnalyticsService.shared) {
        self.post = post
        self.userService = userService
        self.postService = postService
        self.analyticsService = analyticsService
        
        setupInitialState()
        loadAuthorInfo()
    }
    
    private func setupInitialState() {
        likeCount = post.statistics.likeCount
        // Load user-specific data from services
        Task {
            isLiked = await postService.isPostLiked(post.id)
            isBookmarked = await postService.isPostBookmarked(post.id)
        }
    }
    
    private func loadAuthorInfo() {
        Task {
            if let author = await userService.getUser(id: post.authorId) {
                authorDisplayName = author.fullDisplayName
                authorAvatarURL = author.profile?.avatarURL
                isAuthorVerified = author.isVerified
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var contentPreview: String {
        let plainContent = post.content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return String(plainContent.prefix(200))
    }
    
    var formattedPublishDate: String {
        guard let publishedAt = post.publishedAt else {
            return "Draft"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }
    
    var relativePublishDate: String {
        guard let publishedAt = post.publishedAt else {
            return "Draft"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .abbreviated
        return formatter.localizedString(for: publishedAt, relativeTo: Date())
    }
    
    var estimatedReadTime: String {
        let minutes = max(1, Int(post.estimatedReadingTime / 60))
        return "\(minutes) min read"
    }
    
    var shareURL: URL {
        return URL(string: "https://example.com/posts/\(post.id)")!
    }
    
    // MARK: - Actions
    
    func toggleLike() {
        Task {
            let wasLiked = isLiked
            
            // Optimistic update
            isLiked.toggle()
            likeCount += isLiked ? 1 : -1
            
            do {
                if wasLiked {
                    await postService.unlikePost(post.id)
                } else {
                    await postService.likePost(post.id)
                }
                analyticsService.track(event: isLiked ? "post_liked" : "post_unliked", 
                                     parameters: ["post_id": post.id.uuidString])
            } catch {
                // Revert optimistic update on failure
                isLiked = wasLiked
                likeCount += wasLiked ? 1 : -1
            }
        }
    }
    
    func toggleBookmark() {
        Task {
            let wasBookmarked = isBookmarked
            
            // Optimistic update
            isBookmarked.toggle()
            
            do {
                if wasBookmarked {
                    await postService.removeBookmark(post.id)
                } else {
                    await postService.addBookmark(post.id)
                }
                analyticsService.track(event: isBookmarked ? "post_bookmarked" : "post_unbookmarked",
                                     parameters: ["post_id": post.id.uuidString])
            } catch {
                // Revert optimistic update on failure
                isBookmarked = wasBookmarked
            }
        }
    }
    
    func trackView() {
        Task {
            await postService.trackPostView(post.id)
            analyticsService.track(event: "post_viewed", 
                                 parameters: ["post_id": post.id.uuidString])
        }
    }
    
    func reportPost() {
        Task {
            await postService.reportPost(post.id, reason: "Inappropriate content")
            analyticsService.track(event: "post_reported",
                                 parameters: ["post_id": post.id.uuidString])
        }
    }
    
    func hidePost() {
        Task {
            await postService.hidePost(post.id)
            analyticsService.track(event: "post_hidden",
                                 parameters: ["post_id": post.id.uuidString])
        }
    }
    
    func copyLink() {
        #if os(iOS)
        UIPasteboard.general.url = shareURL
        #endif
        analyticsService.track(event: "post_link_copied",
                             parameters: ["post_id": post.id.uuidString])
    }
}

// MARK: - Tag View

@available(iOS 14.0, *)
public struct TagView: View {
    let tag: Tag
    
    public init(tag: Tag) {
        self.tag = tag
    }
    
    public var body: some View {
        Text("#\(tag.name)")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tagColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(tagColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(tagColor)
    }
    
    private var tagColor: Color {
        if let colorHex = tag.color {
            return Color(hex: colorHex) ?? .accentColor
        }
        return .accentColor
    }
}

// MARK: - Supporting Views

@available(iOS 14.0, *)
public struct CommentsView: View {
    let postId: UUID
    
    public init(postId: UUID) {
        self.postId = postId
    }
    
    public var body: some View {
        NavigationView {
            Text("Comments for post: \(postId)")
                .navigationTitle("Comments")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

@available(iOS 14.0, *)
public struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    public init(items: [Any]) {
        self.items = items
    }
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Extensions

extension Color {
    init?(hex: String) {
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hexString.hasPrefix("#") ? String(hexString.dropFirst()) : hexString)
        
        var color: UInt64 = 0
        guard scanner.scanHexInt64(&color) else { return nil }
        
        let r = Double((color & 0xFF0000) >> 16) / 255.0
        let g = Double((color & 0x00FF00) >> 8) / 255.0
        let b = Double(color & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

extension Post {
    var hasBeenEdited: Bool {
        return updatedAt > createdAt.addingTimeInterval(300) // 5 minutes threshold
    }
}