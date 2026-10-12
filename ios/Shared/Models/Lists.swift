import Foundation

// MARK: - Lists

public enum ListVisibility: String, Codable, Sendable, CaseIterable {
    case `private`
    case `public`
    /// Jointly editable — anyone in the audience can add and remove titles.
    case collab

    public var label: String {
        switch self {
        case .private: "Private"
        case .public: "Public"
        case .collab: "Collab"
        }
    }

    public var explanation: String {
        switch self {
        case .private: "Only you can see this list."
        case .public: "Household members can see this on your profile."
        case .collab: "Household members can see it and add or remove titles."
        }
    }

    public var symbol: String {
        switch self {
        case .private: "lock.fill"
        case .public: "globe"
        case .collab: "person.2.fill"
        }
    }
}

/// `GET /api/lists`
public struct ListsResponse: Codable, Sendable, Equatable {
    public var lists: [ListCard]
    /// Other members' collab lists whose audience includes you.
    public var shared: [ListCard]?
}

public struct ListCard: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var name: String
    public var isDefault: Bool
    public var count: Int
    /// Up to four cover posters, newest first.
    public var posters: [String]
    public var visibility: ListVisibility?
    /// Set only for lists someone else owns.
    public var owner: String?

    enum CodingKeys: String, CodingKey {
        case id, name, count, posters, visibility, owner
        case isDefault = "is_default"
    }
}

/// `GET /api/list/{id}`
public struct ListDetail: Codable, Sendable, Equatable {
    public var id: Int
    public var name: String
    public var isDefault: Bool
    public var visibility: ListVisibility?
    public var isOwner: Bool
    /// Owners always; collaborators on a collab list.
    public var canEdit: Bool?
    /// Owner-only: the explicit audience, empty meaning the whole household.
    public var sharedWith: [Int]?
    public var owner: Person
    public var items: [ListItem]

    public var editable: Bool { canEdit ?? isOwner }

    enum CodingKeys: String, CodingKey {
        case id, name, visibility, owner, items
        case isDefault = "is_default"
        case isOwner = "is_owner"
        case canEdit = "can_edit"
        case sharedWith = "shared_with"
    }
}

public struct ListItem: Codable, Sendable, Hashable, Identifiable {
    public var type: String
    public var id: Int
    public var title: String?
    public var poster: String?
    public var year: FlexInt?
    public var addedAt: String?
    public var ended: Bool?
    /// Episodes in the show (or 1 for a film).
    public var total: Int?
    public var watched: Int?
    public var firstWatched: String?
    public var lastWatched: String?
    public var archived: Bool?

    public var uniqueID: String { "\(type):\(id)" }
    public var isShow: Bool { type == "show" }
    public var displayTitle: String { title ?? "Untitled" }
    public var isComplete: Bool { (total ?? 0) > 0 && (watched ?? 0) >= (total ?? 0) }
    public var progress: Double {
        guard let total, total > 0 else { return 0 }
        return min(1, Double(watched ?? 0) / Double(total))
    }

    enum CodingKeys: String, CodingKey {
        case type, id, title, poster, year, ended, total, watched, archived
        case addedAt = "added_at"
        case firstWatched = "first_watched"
        case lastWatched = "last_watched"
    }
}

/// `GET /api/item/{type}/{id}/lists` — which of my lists already hold this title.
public struct ItemListsResponse: Codable, Sendable, Equatable {
    public var lists: [ItemListRow]
}

public struct ItemListRow: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var name: String
    public var isDefault: Bool
    public var has: Bool
    /// Someone else's collab list.
    public var collab: Bool
    public var owner: String?

    enum CodingKeys: String, CodingKey {
        case id, name, has, collab, owner
        case isDefault = "is_default"
    }
}

/// `GET /api/lists/members` — `{"show:1396": 2}`, so any tile can show a bookmark
/// without opening every list.
public struct ListMembership: Codable, Sendable, Equatable {
    public var members: [String: Int]
}

public struct ListItemToggle: Codable, Sendable, Equatable {
    public var itemType: String
    public var itemID: Int
    public var remove: Bool?

    public init(itemType: String, itemID: Int, remove: Bool? = nil) {
        self.itemType = itemType
        self.itemID = itemID
        self.remove = remove
    }

    enum CodingKeys: String, CodingKey {
        case remove
        case itemType = "item_type"
        case itemID = "item_id"
    }
}

public struct CreateListRequest: Codable, Sendable, Equatable {
    public var name: String
    public var visibility: String
    public var sharedWith: [Int]

    public init(name: String, visibility: ListVisibility, sharedWith: [Int] = []) {
        self.name = name
        self.visibility = visibility.rawValue
        self.sharedWith = sharedWith
    }

    enum CodingKeys: String, CodingKey {
        case name, visibility
        case sharedWith = "shared_with"
    }
}

public struct VisibilityRequest: Codable, Sendable, Equatable {
    public var visibility: String
    public var sharedWith: [Int]?

    public init(visibility: ListVisibility, sharedWith: [Int]? = nil) {
        self.visibility = visibility.rawValue
        self.sharedWith = sharedWith
    }

    enum CodingKeys: String, CodingKey {
        case visibility
        case sharedWith = "shared_with"
    }
}

public struct CreatedList: Codable, Sendable, Equatable {
    public var id: Int
    public var name: String
    public var visibility: String?
}

// MARK: - Favorites

public struct FavoritesResponse: Codable, Sendable, Equatable {
    public var favorites: [Favorite]
}

public struct Favorite: Codable, Sendable, Hashable, Identifiable {
    public var type: String
    public var id: Int
    public var title: String?
    public var poster: String?
    public var year: FlexInt?
    public var position: Int?

    public var uniqueID: String { "\(type):\(id)" }
    public var displayTitle: String { title ?? "Untitled" }
}

public struct FavoriteRequest: Codable, Sendable, Equatable {
    public var itemType: String
    public var itemID: Int
    public init(itemType: String, itemID: Int) {
        self.itemType = itemType
        self.itemID = itemID
    }
    enum CodingKeys: String, CodingKey {
        case itemType = "item_type"
        case itemID = "item_id"
    }
}

public struct FavoriteReorder: Codable, Sendable, Equatable {
    /// `[["show", "1396"], …]` — the server takes the pair as strings.
    public var order: [[String]]
    public init(order: [[String]]) { self.order = order }
}
