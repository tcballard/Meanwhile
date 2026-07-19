import AppKit
import CryptoKit
import MeanwhileCore
import UserNotifications

enum NeedsYouNotificationDeliveryOutcome: Equatable {
    case delivered
    case cancelled
    case failed
}

@MainActor
final class NeedsYouNotificationController: NSObject, UNUserNotificationCenterDelegate {
    nonisolated static let identifierPrefix = "Meanwhile.needs-you."
    nonisolated static let testIdentifier = "Meanwhile.attention-test"

    var onPermissionChange: ((NeedsYouNotificationPermission) -> Void)?
    var onResponse: ((String) -> Void)?
    var onTestResponse: (() -> Void)?

    private(set) var permission: NeedsYouNotificationPermission = .unknown {
        didSet {
            guard permission != oldValue else { return }
            onPermissionChange?(permission)
        }
    }

    private struct RequestSpec: Equatable {
        var identifier: String
        var title: String
    }

    private let center: UNUserNotificationCenter
    private var desiredRequests: [String: RequestSpec] = [:]
    private var retainedIdentifiers: Set<String> = []

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
    }

    func start() {
        center.delegate = self
        refreshPermission()
    }

    func refreshPermission() {
        center.getNotificationSettings { [weak self] settings in
            let permission = Self.permission(from: settings)
            Task { @MainActor [weak self] in
                self?.permission = permission
            }
        }
    }

    func requestPermission() {
        guard permission == .notDetermined || permission == .unknown else {
            refreshPermission()
            return
        }
        center.requestAuthorization(options: [.alert]) { [weak self] _, error in
            guard error == nil else {
                Task { @MainActor [weak self] in
                    self?.permission = .unavailable
                }
                return
            }
            Task { @MainActor [weak self] in
                self?.refreshPermission()
            }
        }
    }

    func deliver(
        identifier: String,
        title: String,
        completion: @escaping (NeedsYouNotificationDeliveryOutcome) -> Void
    ) {
        guard permission == .authorized,
              identifier.hasPrefix(Self.identifierPrefix) else {
            completion(.cancelled)
            return
        }
        let spec = RequestSpec(
            identifier: identifier,
            title: title
        )
        desiredRequests = [identifier: spec]
        retainedIdentifiers = [identifier]
        removeStaleManagedNotifications()

        center.getDeliveredNotifications { [weak self] notifications in
            let wasDelivered = notifications.contains {
                $0.request.identifier == identifier
            }
            Task { @MainActor [weak self] in
                guard let self else {
                    completion(.cancelled)
                    return
                }
                finishScheduling(
                    spec,
                    wasDelivered: wasDelivered,
                    completion: completion
                )
            }
        }
    }

    func deliverTest(
        completion: @escaping (NeedsYouNotificationDeliveryOutcome) -> Void
    ) {
        guard permission == .authorized else {
            completion(.cancelled)
            return
        }
        center.removePendingNotificationRequests(withIdentifiers: [Self.testIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.testIdentifier])
        let content = UNMutableNotificationContent()
        content.title = "Meanwhile attention test"
        content.body = "This is a test. Click to return to Meanwhile Settings."
        let request = UNNotificationRequest(
            identifier: Self.testIdentifier,
            content: content,
            trigger: nil
        )
        center.add(request) { [weak self] error in
            Task { @MainActor [weak self] in
                if error == nil {
                    completion(.delivered)
                } else {
                    self?.refreshPermission()
                    completion(.failed)
                }
            }
        }
    }

    func cancel(itemID: String) {
        let identifier = Self.identifier(for: itemID)
        desiredRequests.removeValue(forKey: identifier)
        retainedIdentifiers.remove(identifier)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func retainOnly(itemID: String?) {
        let identifiers: Set<String>
        if let itemID {
            identifiers = [Self.identifier(for: itemID)]
        } else {
            identifiers = []
        }
        guard identifiers != retainedIdentifiers else { return }
        retainedIdentifiers = identifiers
        desiredRequests = desiredRequests.filter { identifiers.contains($0.key) }
        removeStaleManagedNotifications()
    }

    func cancelAllManaged() {
        desiredRequests.removeAll()
        retainedIdentifiers.removeAll()
        removeStaleManagedNotifications()
    }

    func openSystemSettings() {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.meanwhile.Meanwhile"
        let specific = URL(
            string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleIdentifier)"
        )
        if let specific, NSWorkspace.shared.open(specific) { return }
        if let notifications = URL(
            string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        ) {
            NSWorkspace.shared.open(notifications)
        }
    }

    static func identifier(for itemID: String) -> String {
        let digest = SHA256.hash(data: Data(itemID.utf8))
        let value = digest.map { String(format: "%02x", $0) }.joined()
        return identifierPrefix + value
    }

    private func finishScheduling(
        _ spec: RequestSpec,
        wasDelivered: Bool,
        completion: @escaping (NeedsYouNotificationDeliveryOutcome) -> Void
    ) {
        guard permission == .authorized,
              desiredRequests[spec.identifier] == spec else {
            completion(.cancelled)
            return
        }
        guard !wasDelivered else {
            completion(.delivered)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = spec.title
        content.body = "Click to return to the waiting task."
        let request = UNNotificationRequest(
            identifier: spec.identifier,
            content: content,
            trigger: nil
        )
        center.add(request) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else {
                    completion(.cancelled)
                    return
                }
                guard desiredRequests[spec.identifier] == spec else {
                    center.removePendingNotificationRequests(
                        withIdentifiers: [spec.identifier]
                    )
                    center.removeDeliveredNotifications(
                        withIdentifiers: [spec.identifier]
                    )
                    completion(.cancelled)
                    return
                }
                guard error == nil else {
                    desiredRequests.removeValue(forKey: spec.identifier)
                    center.removePendingNotificationRequests(
                        withIdentifiers: [spec.identifier]
                    )
                    center.removeDeliveredNotifications(
                        withIdentifiers: [spec.identifier]
                    )
                    completion(.failed)
                    refreshPermission()
                    return
                }
                completion(.delivered)
            }
        }
    }

    private func removeStaleManagedNotifications() {
        center.getPendingNotificationRequests { [weak self] requests in
            let managed = requests.map(\.identifier).filter {
                $0.hasPrefix(Self.identifierPrefix)
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let identifiers = managed.filter {
                    self.desiredRequests[$0] == nil
                        && !self.retainedIdentifiers.contains($0)
                }
                center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        }
        center.getDeliveredNotifications { [weak self] notifications in
            let managed = notifications.map { $0.request.identifier }.filter {
                $0.hasPrefix(Self.identifierPrefix)
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let identifiers = managed.filter {
                    self.desiredRequests[$0] == nil
                        && !self.retainedIdentifiers.contains($0)
                }
                center.removeDeliveredNotifications(withIdentifiers: identifiers)
            }
        }
    }

    nonisolated private static func permission(
        from settings: UNNotificationSettings
    ) -> NeedsYouNotificationPermission {
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return settings.notificationCenterSetting == .enabled
                ? .authorized
                : .limited
        @unknown default:
            return .unavailable
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard notification.request.identifier.hasPrefix(Self.identifierPrefix)
                || notification.request.identifier == Self.testIdentifier else {
            completionHandler([])
            return
        }
        completionHandler([.banner, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        if identifier == Self.testIdentifier,
           response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
            Task { @MainActor [weak self] in self?.onTestResponse?() }
            completionHandler()
            return
        }
        guard identifier.hasPrefix(Self.identifierPrefix),
              response.actionIdentifier == UNNotificationDefaultActionIdentifier else {
            completionHandler()
            return
        }
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        Task { @MainActor [weak self] in
            self?.desiredRequests.removeValue(forKey: identifier)
            self?.retainedIdentifiers.remove(identifier)
            self?.onResponse?(identifier)
        }
        completionHandler()
    }
}
