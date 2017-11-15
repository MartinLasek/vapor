import Async
import Foundation

/// Has create and update timestamps.
public protocol SoftDeletable: Model, _SoftDeletable {
    /// Key referencing deleted at property.
    typealias DeletedAtKey = ReferenceWritableKeyPath<Self, Date?>

    /// The date at which this model was deleted.
    /// nil if the model has not been deleted yet.
    /// If this property is true, the model will not
    /// be included in any query results unless
    /// `.withSoftDeleted()` is used.
    static var deletedAtKey: DeletedAtKey { get }
}

extension SoftDeletable {
    /// Fluent deleted at property.
    public var fluentDeletedAt: Date? {
        get { return self[keyPath: Self.deletedAtKey] }
        set { self[keyPath: Self.deletedAtKey] = newValue }
    }
}

// MARK: Model

extension Model where Self: SoftDeletable {
    /// Permanently deletes a soft deletable model.
    public func forceDelete(
        on connection: Self.Database.Connection
    ) -> Future<Void> {
        return connection.query(Self.self)._delete(self)
    }

    /// Restores a soft deleted model.
    public func restore(
        on connection: Self.Database.Connection
    ) -> Future<Void> {
        fluentDeletedAt = nil
        return self.update(on: connection)
    }
}

// MARK: Query

extension DatabaseQuery {
    /// If true, soft deleted models should be included.
    internal var withSoftDeleted: Bool {
        get { return extend["withSoftDeleted"] as? Bool ?? false }
        set { extend["withSoftDeleted"] = newValue }
    }
}

extension QueryBuilder where Model: SoftDeletable {
    /// Includes soft deleted models in the results.
    public func withSoftDeleted() {
        query.withSoftDeleted = true
    }
}

// MARK: Hack

/// Unfortunately we need this hack.
/// note: do not rely on this exterally.
public protocol _SoftDeletable {
    /// Pointer to type erased key path
    static var _deletedAtKey: AnyKeyPath { get }
}

extension SoftDeletable {
    public static var _deletedAtKey: AnyKeyPath {
        return deletedAtKey
    }
}
