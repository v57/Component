import Foundation
import Observation
import SwiftUI

/// A value kept in `UserDefaults`, like `@AppStorage`, that updates a view only when its own value changes.
///
/// `@AppStorage` updates its view on every change to the defaults, whatever the key: a window whose container held one
/// (a sidebar, a split) built everything inside it again each time an app saved anything (a session on every tab
/// switch). Here each key is one observable value, read again when the defaults change and set only when it differs,
/// so a view reads only its own keys. It takes the same types (`Bool`, `Int`, `Double`, `String`, `Data`, and
/// `RawRepresentable` with a `String` or `Int` raw value) and its binding is `$name`.
///
/// ```swift
/// @KitStorage("sidebar.showsExtensions") private var showsExtensions = false
/// @KitStorage("welcome.collapsedGroups") private var collapsedGroups = KitIDSet()
/// Toggle("Show Extensions", isOn: $showsExtensions)
/// ```
///
/// It hears changes made in the app (`UserDefaults.didChangeNotification`), not a `defaults write` from outside.
@MainActor @propertyWrapper
public struct KitStorage<Value: Equatable>: DynamicProperty {
  private let stored: KitStoredValue<Value>

  public var wrappedValue: Value {
    get { stored.value }
    nonmutating set { stored.value = newValue }
  }

  public var projectedValue: Binding<Value> {
    Binding(get: { stored.value }, set: { stored.value = $0 })
  }

  init(key: String, store: UserDefaults, read: @escaping (UserDefaults) -> Value?, write: @escaping (UserDefaults, Value) -> Void, defaultValue: Value) {
    stored = KitStoredValues.shared.value(key: key, store: store) {
      KitStoredValue(key: key, store: store, defaultValue: defaultValue, read: read, write: write)
    }
  }
}

extension KitStorage {
  public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == Bool {
    self.init(
      key: key, store: store, read: { $0.object(forKey: key) as? Bool }, write: { $0.set($1, forKey: key) },
      defaultValue: wrappedValue)
  }

  public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == Int {
    self.init(
      key: key, store: store, read: { ($0.object(forKey: key) as? NSNumber)?.intValue },
      write: { $0.set($1, forKey: key) }, defaultValue: wrappedValue)
  }

  public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == Double {
    self.init(
      key: key, store: store, read: { ($0.object(forKey: key) as? NSNumber)?.doubleValue },
      write: { $0.set($1, forKey: key) }, defaultValue: wrappedValue)
  }

  public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == String {
    self.init(
      key: key, store: store, read: { $0.string(forKey: key) }, write: { $0.set($1, forKey: key) },
      defaultValue: wrappedValue)
  }

  public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) where Value == Data {
    self.init(
      key: key, store: store, read: { $0.data(forKey: key) }, write: { $0.set($1, forKey: key) },
      defaultValue: wrappedValue)
  }

  public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard)
  where Value: RawRepresentable, Value.RawValue == String {
    self.init(
      key: key, store: store, read: { $0.string(forKey: key).flatMap(Value.init(rawValue:)) },
      write: { $0.set($1.rawValue, forKey: key) }, defaultValue: wrappedValue)
  }

  public init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard)
  where Value: RawRepresentable, Value.RawValue == Int {
    self.init(
      key: key, store: store,
      read: { ($0.object(forKey: key) as? NSNumber).flatMap { Value(rawValue: $0.intValue) } },
      write: { $0.set($1.rawValue, forKey: key) }, defaultValue: wrappedValue)
  }
}

/// One key's value, shared by every `KitStorage` of that key.
@MainActor @Observable
final class KitStoredValue<Value: Equatable> {
  /// Setting it writes the defaults.
  var value: Value {
    didSet {
      guard !isReading, value != oldValue else { return }
      write(store, value)
    }
  }
  @ObservationIgnored private let store: UserDefaults
  @ObservationIgnored private let defaultValue: Value
  @ObservationIgnored private let read: (UserDefaults) -> Value?
  @ObservationIgnored private let write: (UserDefaults, Value) -> Void
  @ObservationIgnored private var isReading = false

  init(
    key: String, store: UserDefaults, defaultValue: Value, read: @escaping (UserDefaults) -> Value?,
    write: @escaping (UserDefaults, Value) -> Void
  ) {
    self.store = store
    self.defaultValue = defaultValue
    self.read = read
    self.write = write
    value = read(store) ?? defaultValue
  }

  /// Reads the defaults again; a view that reads the value updates only if it changed.
  func refresh() {
    let new = read(store) ?? defaultValue
    guard new != value else { return }
    isReading = true
    value = new
    isReading = false
  }
}

/// Every key's value, read again when the app changes its defaults.
@MainActor
final class KitStoredValues {
  static let shared = KitStoredValues()

  private struct Key: Hashable {
    let key: String
    let store: ObjectIdentifier
  }

  private var values: [Key: AnyObject] = [:]
  private var refreshers: [() -> Void] = []
  private var observer: NSObjectProtocol?

  private init() {
    observer = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification, object: nil, queue: .main
    ) { _ in
      MainActor.assumeIsolated { KitStoredValues.shared.refresh() }
    }
  }

  /// The value of `key`, made on first use. A key read as two types keeps the first.
  func value<Value: Equatable>(key: String, store: UserDefaults, make: () -> KitStoredValue<Value>)
    -> KitStoredValue<Value>
  {
    let id = Key(key: key, store: ObjectIdentifier(store))
    if let existing = values[id] as? KitStoredValue<Value> { return existing }
    let value = make()
    if values[id] == nil {
      values[id] = value
      refreshers.append { [weak value] in value?.refresh() }
    }
    return value
  }

  private func refresh() {
    for refresh in refreshers { refresh() }
  }
}
