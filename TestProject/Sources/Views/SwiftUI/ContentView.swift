import SwiftUI
import Combine
import Foundation

// MARK: - Main Content View

@available(iOS 14.0, *)
public struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @StateObject private var userStore = UserStore.shared
    @StateObject private var postStore = PostStore()
    @StateObject private var navigationManager = NavigationManager()
    
    @State private var selectedTab: TabSelection = .home
    @State private var isShowingProfile = false
    @State private var searchText = ""
    @State private var refreshTrigger = UUID()
    
    @AppStorage("theme") private var selectedTheme: Theme = .system
    @AppStorage("showOnboarding") private var showOnboarding = true
    @AppStorage("lastRefreshDate") private var lastRefreshDate = Date()
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    
    // MARK: - Nested Types
    
    public enum TabSelection: String, CaseIterable {
        case home = "home"
        case explore = "explore"
        case notifications = "notifications"
        case profile = "profile"
        
        public var title: String {
            switch self {
            case .home: return "Home"
            case .explore: return "Explore"
            case .notifications: return "Notifications"
            case .profile: return "Profile"
            }
        }
        
        public var iconName: String {
            switch self {
            case .home: return "house"
            case .explore: return "globe"
            case .notifications: return "bell"
            case .profile: return "person"
            }
        }
        
        public var selectedIconName: String {
            switch self {
            case .home: return "house.fill"
            case .explore: return "globe.fill"
            case .notifications: return "bell.fill"
            case .profile: return "person.fill"
            }
        }
    }
    
    public enum Theme: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        public var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
        
        public var colorScheme: ColorScheme? {
            switch self {
            case .light: return .light
            case .dark: return .dark
            case .system: return nil
            }
        }
    }
    
    // MARK: - Body
    
    public var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: selectedTab == .home ? "house.fill" : "house")
                        Text("Home")
                    }
                    .tag(TabSelection.home)
                
                ExploreView(searchText: $searchText)
                    .tabItem {
                        Image(systemName: selectedTab == .explore ? "globe.fill" : "globe")
                        Text("Explore")
                    }
                    .tag(TabSelection.explore)
                
                NotificationsView()
                    .tabItem {
                        Image(systemName: selectedTab == .notifications ? "bell.fill" : "bell")
                        Text("Notifications")
                    }
                    .tag(TabSelection.notifications)
                    .badge(viewModel.unreadNotificationsCount > 0 ? viewModel.unreadNotificationsCount : nil)
                
                ProfileView()
                    .tabItem {
                        Image(systemName: selectedTab == .profile ? "person.fill" : "person")
                        Text("Profile")
                    }
                    .tag(TabSelection.profile)
            }
            .accentColor(viewModel.accentColor)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
            .refreshable {
                await refreshContent()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .environmentObject(viewModel)
        .environmentObject(userStore)
        .environmentObject(postStore)
        .environmentObject(navigationManager)
        .preferredColorScheme(selectedTheme.colorScheme)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
        .onChange(of: scenePhase) { phase in
            handleScenePhaseChange(phase)
        }
        .onAppear {
            Task {
                await viewModel.loadInitialData()
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func refreshContent() async {
        lastRefreshDate = Date()
        refreshTrigger = UUID()
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await viewModel.refreshData()
            }
            group.addTask {
                await postStore.refreshPosts()
            }
            group.addTask {
                await userStore.refreshCurrentUser()
            }
        }
    }
    
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            Task {
                await viewModel.handleAppDidBecomeActive()
            }
        case .background:
            viewModel.handleAppDidEnterBackground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Content View Model

@MainActor
public class ContentViewModel: ObservableObject {
    @Published var unreadNotificationsCount: Int = 0
    @Published var accentColor: Color = .blue
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var networkStatus: NetworkStatus = .connected
    @Published var lastUpdateTime: Date = Date()
    
    private let notificationService: NotificationService
    private let analyticsService: AnalyticsService
    private var cancellables = Set<AnyCancellable>()
    private let refreshThrottle = PassthroughSubject<Void, Never>()
    
    public enum NetworkStatus {
        case connected
        case disconnected
        case slow
        
        var displayName: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Offline"
            case .slow: return "Slow Connection"
            }
        }
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .red
            case .slow: return .orange
            }
        }
    }
    
    public init(notificationService: NotificationService = NotificationService.shared,
                analyticsService: AnalyticsService = AnalyticsService.shared) {
        self.notificationService = notificationService
        self.analyticsService = analyticsService
        setupBindings()
    }
    
    private func setupBindings() {
        // Throttle refresh requests
        refreshThrottle
            .throttle(for: .seconds(2), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] in
                Task {
                    await self?.performRefresh()
                }
            }
            .store(in: &cancellables)
        
        // Monitor notification count
        notificationService.unreadCountPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.unreadNotificationsCount, on: self)
            .store(in: &cancellables)
        
        // Monitor network status
        NetworkMonitor.shared.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.networkStatus = status
            }
            .store(in: &cancellables)
    }
    
    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let notifications = notificationService.getUnreadCount()
            async let userPreferences = UserPreferencesService.shared.loadPreferences()
            
            unreadNotificationsCount = await notifications
            let preferences = await userPreferences
            accentColor = Color(preferences.accentColorHex ?? "#007AFF")
            
            analyticsService.track(event: "app_launched")
        } catch {
            errorMessage = error.localizedDescription
        }
        
        lastUpdateTime = Date()
    }
    
    func refreshData() async {
        refreshThrottle.send()
    }
    
    private func performRefresh() async {
        do {
            await loadInitialData()
            analyticsService.track(event: "data_refreshed")
        } catch {
            errorMessage = "Failed to refresh data: \(error.localizedDescription)"
        }
    }
    
    func handleAppDidBecomeActive() async {
        await loadInitialData()
        analyticsService.track(event: "app_became_active")
    }
    
    func handleAppDidEnterBackground() {
        analyticsService.track(event: "app_entered_background")
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Home View

@available(iOS 14.0, *)
public struct HomeView: View {
    @EnvironmentObject private var postStore: PostStore
    @EnvironmentObject private var userStore: UserStore
    
    @State private var isShowingCreatePost = false
    @State private var scrollPosition: UUID?
    @State private var selectedPost: Post?
    
    public var body: some View {
        ScrollViewReader { proxy in
            LazyVStack(spacing: 16) {
                ForEach(postStore.homeFeedPosts) { post in
                    PostRowView(post: post)
                        .id(post.id)
                        .onTapGesture {
                            selectedPost = post
                        }
                        .onAppear {
                            if post.id == postStore.homeFeedPosts.last?.id {
                                Task {
                                    await postStore.loadMorePosts()
                                }
                            }
                        }
                }
                
                if postStore.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { isShowingCreatePost = true }) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $isShowingCreatePost) {
            CreatePostView()
        }
        .sheet(item: $selectedPost) { post in
            PostDetailView(post: post)
        }
        .refreshable {
            await postStore.refreshPosts()
        }
        .onAppear {
            Task {
                await postStore.loadHomeFeed()
            }
        }
    }
}

// MARK: - Explore View

@available(iOS 14.0, *)
public struct ExploreView: View {
    @Binding var searchText: String
    @EnvironmentObject private var postStore: PostStore
    
    @State private var selectedCategory: Category?
    @State private var isShowingFilters = false
    @State private var searchResults: [Post] = []
    @State private var isSearching = false
    
    public init(searchText: Binding<String>) {
        self._searchText = searchText
    }
    
    public var body: some View {
        VStack {
            if searchText.isEmpty {
                CategoryGridView(selectedCategory: $selectedCategory)
                TrendingPostsView()
            } else {
                SearchResultsView(searchText: searchText, results: $searchResults, isSearching: $isSearching)
            }
        }
        .navigationTitle("Explore")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { isShowingFilters = true }) {
                    Image(systemName: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $isShowingFilters) {
            SearchFiltersView()
        }
        .onChange(of: searchText) { newValue in
            performSearch(query: newValue)
        }
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        Task {
            do {
                let results = await postStore.search(query: query)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            }
        }
    }
}

// MARK: - Support Views

@available(iOS 14.0, *)
public struct NotificationsView: View {
    public var body: some View {
        Text("Notifications")
            .navigationTitle("Notifications")
    }
}

@available(iOS 14.0, *)
public struct ProfileView: View {
    public var body: some View {
        Text("Profile")
            .navigationTitle("Profile")
    }
}

@available(iOS 14.0, *)
public struct OnboardingView: View {
    @Binding var isPresented: Bool
    
    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
    public var body: some View {
        Text("Onboarding")
    }
}

@available(iOS 14.0, *)
public struct CategoryGridView: View {
    @Binding var selectedCategory: Category?
    
    public init(selectedCategory: Binding<Category?>) {
        self._selectedCategory = selectedCategory
    }
    
    public var body: some View {
        Text("Categories")
    }
}

@available(iOS 14.0, *)
public struct TrendingPostsView: View {
    public var body: some View {
        Text("Trending Posts")
    }
}

@available(iOS 14.0, *)
public struct SearchResultsView: View {
    let searchText: String
    @Binding var results: [Post]
    @Binding var isSearching: Bool
    
    public init(searchText: String, results: Binding<[Post]>, isSearching: Binding<Bool>) {
        self.searchText = searchText
        self._results = results
        self._isSearching = isSearching
    }
    
    public var body: some View {
        Text("Search Results for: \(searchText)")
    }
}

@available(iOS 14.0, *)
public struct SearchFiltersView: View {
    public var body: some View {
        Text("Search Filters")
    }
}

@available(iOS 14.0, *)
public struct CreatePostView: View {
    public var body: some View {
        Text("Create Post")
    }
}

@available(iOS 14.0, *)
public struct PostDetailView: View {
    let post: Post
    
    public init(post: Post) {
        self.post = post
    }
    
    public var body: some View {
        Text("Post Detail: \(post.title)")
    }
}