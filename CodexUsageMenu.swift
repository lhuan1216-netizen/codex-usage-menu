import AppKit
import Foundation

struct UsageSettings: Codable {
    var autoRefreshMinutes: Int
    var shortWindowRemainingPercent: Int
    var weeklyRemainingPercent: Int
    var shortWindowReset: String
    var weeklyReset: String
    var usageWindowLabel: String
    var liveUsageUpdatedAt: Double
    var liveRefreshStatus: String
    var resetCreditCount: Int
    var resetCreditExpirations: [String]

    init(
        autoRefreshMinutes: Int,
        shortWindowRemainingPercent: Int,
        weeklyRemainingPercent: Int,
        shortWindowReset: String,
        weeklyReset: String,
        usageWindowLabel: String = "1 周",
        liveUsageUpdatedAt: Double = 0,
        liveRefreshStatus: String = "未刷新",
        resetCreditCount: Int = 0,
        resetCreditExpirations: [String] = []
    ) {
        self.autoRefreshMinutes = autoRefreshMinutes
        self.shortWindowRemainingPercent = shortWindowRemainingPercent
        self.weeklyRemainingPercent = weeklyRemainingPercent
        self.shortWindowReset = shortWindowReset
        self.weeklyReset = weeklyReset
        self.usageWindowLabel = usageWindowLabel
        self.liveUsageUpdatedAt = liveUsageUpdatedAt
        self.liveRefreshStatus = liveRefreshStatus
        self.resetCreditCount = resetCreditCount
        self.resetCreditExpirations = resetCreditExpirations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        autoRefreshMinutes = try container.decodeIfPresent(Int.self, forKey: .autoRefreshMinutes) ?? 2
        shortWindowRemainingPercent = try container.decodeIfPresent(Int.self, forKey: .shortWindowRemainingPercent) ?? 0
        weeklyRemainingPercent = try container.decodeIfPresent(Int.self, forKey: .weeklyRemainingPercent) ?? 0
        shortWindowReset = try container.decodeIfPresent(String.self, forKey: .shortWindowReset) ?? "未知"
        weeklyReset = try container.decodeIfPresent(String.self, forKey: .weeklyReset) ?? "未知"
        usageWindowLabel = try container.decodeIfPresent(String.self, forKey: .usageWindowLabel) ?? "1 周"
        liveUsageUpdatedAt = try container.decodeIfPresent(Double.self, forKey: .liveUsageUpdatedAt) ?? 0
        liveRefreshStatus = try container.decodeIfPresent(String.self, forKey: .liveRefreshStatus) ?? "未刷新"
        resetCreditCount = try container.decodeIfPresent(Int.self, forKey: .resetCreditCount) ?? 0
        resetCreditExpirations = try container.decodeIfPresent([String].self, forKey: .resetCreditExpirations) ?? []
    }

    static let `default` = UsageSettings(
        autoRefreshMinutes: 2,
        shortWindowRemainingPercent: 0,
        weeklyRemainingPercent: 0,
        shortWindowReset: "未知",
        weeklyReset: "未知",
        resetCreditCount: 0,
        resetCreditExpirations: []
    )
}

struct CodexProfile {
    var email: String
    var plan: String
}

struct CodexUsage {
    var profile: CodexProfile
    var todayTokens: Int
    var todayThreads: Int
    var weekTokens: Int
    var weekThreads: Int
    var totalTokens: Int
    var totalThreads: Int
    var latestThreadTitle: String
    var latestThreadTokens: Int
    var latestThreadUpdatedAt: String
    var lastRefresh: String
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var settings = UsageSettings.default
    private var usage = CodexUsage.empty
    private var refreshTimer: Timer?
    private var isRefreshing = false
    private var refreshStartedAt: Date?

    private var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/CodexUsageMenu", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        loadSettings()
        usage = Self.loadUsage()
        rebuildMenu()
        startTimer()
        refreshNow()
    }

    private func loadSettings() {
        guard let data = try? Data(contentsOf: settingsURL),
              let decoded = try? JSONDecoder().decode(UsageSettings.self, from: data) else {
            settings = .default
            saveSettings()
            return
        }

        settings = decoded
    }

    private func saveSettings() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(settings) else { return }
        try? FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: settingsURL)
    }

    private func rebuildMenu() {
        statusItem.button?.title = Self.isLiveUsageFresh(settings.liveUsageUpdatedAt)
            ? "Codex \(settings.weeklyRemainingPercent)%"
            : "Codex --%"

        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(label("Codex 用量", size: 17, weight: .semibold))
        menu.addItem(label("账号:  \(usage.profile.email)"))
        menu.addItem(label("套餐:  \(usage.profile.plan)"))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(label("剩余用量", size: 16, weight: .semibold))
        menu.addItem(label("\(settings.usageWindowLabel):  \(settings.weeklyRemainingPercent)%  \(settings.weeklyReset)"))
        menu.addItem(label("在线刷新:  \(settings.liveRefreshStatus)"))
        menu.addItem(label("在线更新时间:  \(Self.formatDateTime(settings.liveUsageUpdatedAt))"))
        menu.addItem(label("重置可用次数:  剩余 \(settings.resetCreditCount) 次"))
        if settings.resetCreditExpirations.isEmpty {
            menu.addItem(label("重置卡:  暂无可用"))
        } else {
            for (index, expiration) in settings.resetCreditExpirations.enumerated() {
                menu.addItem(label("重置卡 \(index + 1):  \(expiration)"))
            }
        }
        menu.addItem(NSMenuItem.separator())

        menu.addItem(label("今日用量:  \(Self.decimal(usage.todayTokens)) tokens"))
        menu.addItem(label("今日对话:  \(usage.todayThreads) 个"))
        menu.addItem(label("近 7 天用量:  \(Self.decimal(usage.weekTokens)) tokens"))
        menu.addItem(label("近 7 天对话:  \(usage.weekThreads) 个"))
        menu.addItem(label("累计本机用量:  \(Self.decimal(usage.totalTokens)) tokens"))
        menu.addItem(label("累计本机对话:  \(usage.totalThreads) 个"))
        menu.addItem(label("最后刷新:  \(usage.lastRefresh)"))
        menu.addItem(label("自动刷新:  当前每 \(settings.autoRefreshMinutes) 分钟"))
        menu.addItem(NSMenuItem.separator())

        menu.addItem(action("刷新", key: "r", selector: #selector(refreshNow)))
        menu.addItem(action("打开 Codex", key: "o", selector: #selector(openCodex)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(action("退出", key: "q", selector: #selector(quit)))

        statusItem.menu = menu
    }

    private func label(_ title: String, size: CGFloat = 15, weight: NSFont.Weight = .regular) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.72)
            ]
        )
        return item
    }

    private func action(_ title: String, key: String, selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        item.isEnabled = true
        return item
    }

    private func startTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(max(settings.autoRefreshMinutes, 1) * 60),
            repeats: true
        ) { [weak self] _ in
            self?.refreshNow()
        }
    }

    @objc private func refreshNow() {
        if isRefreshing {
            if let refreshStartedAt, Date().timeIntervalSince(refreshStartedAt) > 60 {
                isRefreshing = false
                self.refreshStartedAt = nil
            } else {
                return
            }
        }

        isRefreshing = true
        refreshStartedAt = Date()
        loadSettings()
        let currentSettings = settings

        DispatchQueue.global(qos: .utility).async { [weak self] in
            var refreshedSettings = currentSettings
            let liveLimitsResult = Self.loadLiveUsageLimits()
            if let liveLimits = liveLimitsResult.limits {
                refreshedSettings.usageWindowLabel = liveLimits.usageWindowLabel
                refreshedSettings.weeklyRemainingPercent = liveLimits.weeklyRemainingPercent
                refreshedSettings.weeklyReset = liveLimits.weeklyReset
                refreshedSettings.liveUsageUpdatedAt = Date().timeIntervalSince1970
                refreshedSettings.liveRefreshStatus = "正常 \(Self.currentTime())"
            } else {
                refreshedSettings.liveRefreshStatus = "失败 \(Self.currentTime()): \(liveLimitsResult.error ?? "未返回用量")"
            }
            if let resetCredits = Self.loadLiveResetCredits() {
                refreshedSettings.resetCreditCount = resetCredits.count
                refreshedSettings.resetCreditExpirations = resetCredits.expirations
            }
            let refreshedUsage = Self.loadUsage()

            DispatchQueue.main.async {
                guard let self else { return }
                self.settings = refreshedSettings
                self.usage = refreshedUsage
                self.saveSettings()
                self.rebuildMenu()
                self.startTimer()
                self.isRefreshing = false
                self.refreshStartedAt = nil
            }
        }
    }

    @objc private func openCodex() {
        let appPaths = [
            "/Applications/Codex.app",
            NSString(string: "~/Applications/Codex.app").expandingTildeInPath
        ]

        for path in appPaths where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            return
        }

        NSSound.beep()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private static func loadUsage() -> CodexUsage {
        let profile = loadProfile()
        let stateDB = NSString(string: "~/.codex/state_5.sqlite").expandingTildeInPath

        let today = sqliteRow(
            db: stateDB,
            sql: "select count(*), coalesce(sum(tokens_used),0) from threads where date(updated_at, 'unixepoch', 'localtime') = date('now','localtime');"
        )
        let week = sqliteRow(
            db: stateDB,
            sql: "select count(*), coalesce(sum(tokens_used),0) from threads where updated_at >= strftime('%s','now','-7 days');"
        )
        let total = sqliteRow(
            db: stateDB,
            sql: "select count(*), coalesce(sum(tokens_used),0) from threads;"
        )
        let latest = sqliteRow(
            db: stateDB,
            sql: "select replace(title, '|', '｜'), tokens_used, datetime(updated_at, 'unixepoch', 'localtime') from threads order by updated_at desc limit 1;"
        )

        return CodexUsage(
            profile: profile,
            todayTokens: Int(today[safe: 1] ?? "0") ?? 0,
            todayThreads: Int(today[safe: 0] ?? "0") ?? 0,
            weekTokens: Int(week[safe: 1] ?? "0") ?? 0,
            weekThreads: Int(week[safe: 0] ?? "0") ?? 0,
            totalTokens: Int(total[safe: 1] ?? "0") ?? 0,
            totalThreads: Int(total[safe: 0] ?? "0") ?? 0,
            latestThreadTitle: latest[safe: 0] ?? "无",
            latestThreadTokens: Int(latest[safe: 1] ?? "0") ?? 0,
            latestThreadUpdatedAt: latest[safe: 2] ?? "无",
            lastRefresh: currentTime()
        )
    }

    private static func loadLiveUsageLimits() -> UsageLimitsResult {
        let result = fetchCodexJSON(path: "/wham/usage")
        guard let json = result.json else {
            return UsageLimitsResult(limits: nil, error: result.error)
        }
        guard let rateLimit = json["rate_limit"] as? [String: Any] else {
            return UsageLimitsResult(limits: nil, error: "接口缺少 rate_limit")
        }

        let windows = [
            usageWindow(from: rateLimit["primary_window"] as? [String: Any]),
            usageWindow(from: rateLimit["secondary_window"] as? [String: Any])
        ].compactMap { $0 }

        guard let mainWindow = windows.max(by: { $0.minutes < $1.minutes }) else {
            return UsageLimitsResult(limits: nil, error: "接口缺少用量窗口")
        }

        return UsageLimitsResult(limits: UsageLimits(
            shortWindowRemainingPercent: 0,
            shortWindowReset: "",
            weeklyRemainingPercent: mainWindow.remainingPercent,
            weeklyReset: formatReset(mainWindow.resetAt, style: mainWindow.minutes >= 1440 ? .date : .time),
            usageWindowLabel: usageWindowLabel(minutes: mainWindow.minutes)
        ), error: nil)
    }

    private static func loadLiveResetCredits() -> ResetCredits? {
        guard let json = fetchCodexJSON(path: "/wham/rate-limit-reset-credits").json,
              let credits = json["credits"] as? [[String: Any]] else {
            return nil
        }

        let availableCredits = credits.filter { ($0["status"] as? String) == "available" }
        let expirations = availableCredits.compactMap { credit -> String? in
            guard let expiresAt = credit["expires_at"] as? String,
                  let date = parseISODate(expiresAt) else {
                return nil
            }
            return formatExpiration(date)
        }
        let count = (json["available_count"] as? NSNumber)?.intValue ?? availableCredits.count
        return ResetCredits(count: count, expirations: expirations)
    }

    private static func fetchCodexJSON(path: String) -> FetchJSONResult {
        let authURL = URL(fileURLWithPath: NSString(string: "~/.codex/auth.json").expandingTildeInPath)
        guard let data = try? Data(contentsOf: authURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty else {
            return FetchJSONResult(json: nil, error: "未读取到登录令牌")
        }

        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api\(path)")!)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("CodexUsageMenu/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 12

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        var response: URLResponse?
        var requestError: Error?

        URLSession.shared.dataTask(with: request) { data, urlResponse, error in
            responseData = data
            response = urlResponse
            requestError = error
            semaphore.signal()
        }.resume()

        guard semaphore.wait(timeout: .now() + 15) == .success else {
            return FetchJSONResult(json: nil, error: "请求超时")
        }
        if let requestError {
            return FetchJSONResult(json: nil, error: requestError.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            return FetchJSONResult(json: nil, error: "没有收到 HTTP 响应")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            return FetchJSONResult(json: nil, error: "HTTP \(httpResponse.statusCode)")
        }
        guard let responseData,
              let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            return FetchJSONResult(json: nil, error: "JSON 解析失败")
        }
        return FetchJSONResult(json: json, error: nil)
    }

    private static func usageWindow(from object: [String: Any]?) -> UsageWindow? {
        guard let object else { return nil }
        let seconds = number(object["limit_window_seconds"]) ?? 0
        let usedPercent = number(object["used_percent"]) ?? 0
        let resetAt = number(object["reset_at"])
        let remaining = Int(round(max(0, min(100, 100 - usedPercent))))
        return UsageWindow(
            minutes: Int(round(seconds / 60)),
            remainingPercent: remaining,
            resetAt: resetAt
        )
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private enum ResetStyle {
        case time
        case date
    }

    private static func formatReset(_ timestamp: Double?, style: ResetStyle) -> String {
        guard let timestamp else { return "未知" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = style == .time ? "HH:mm" : "M月d日"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    private static func isLiveUsageFresh(_ timestamp: Double) -> Bool {
        timestamp > 0 && Date().timeIntervalSince1970 - timestamp <= 10 * 60
    }

    private static func formatDateTime(_ timestamp: Double) -> String {
        guard timestamp > 0 else { return "无" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "M月d日 HH:mm:ss"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    private static func usageWindowLabel(minutes: Int) -> String {
        if minutes >= 1440 {
            let days = max(1, Int(round(Double(minutes) / 1440)))
            return days == 7 ? "1 周" : "\(days) 天"
        }
        if minutes >= 60 {
            let hours = max(1, Int(round(Double(minutes) / 60)))
            return "\(hours) 小时"
        }
        return "\(max(1, minutes)) 分钟"
    }

    private static func parseISODate(_ string: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: string) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func formatExpiration(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "M月d日 HH:mm 到期"

        let seconds = date.timeIntervalSince(Date())
        let days = max(0, Int(ceil(seconds / 86_400)))
        return "\(formatter.string(from: date)) (剩余 \(days) 天)"
    }

    private static func loadProfile() -> CodexProfile {
        let authURL = URL(fileURLWithPath: NSString(string: "~/.codex/auth.json").expandingTildeInPath)
        guard let data = try? Data(contentsOf: authURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any],
              let idToken = tokens["id_token"] as? String,
              let payload = decodeJWTPayload(idToken) else {
            return CodexProfile(email: "未知", plan: "未知")
        }

        let email = payload["email"] as? String ?? "未知"
        let auth = payload["https://api.openai.com/auth"] as? [String: Any]
        let plan = (auth?["chatgpt_plan_type"] as? String ?? "未知").uppercased()
        return CodexProfile(email: email, plan: plan)
    }

    private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var base64 = String(parts[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: padding)

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private static func sqliteRow(db: String, sql: String) -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = ["-separator", "|", db, sql]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !output.isEmpty else { return [] }
        return output.components(separatedBy: "|")
    }

    private static func currentTime() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    private static func decimal(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func shortNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

struct UsageLimits {
    var shortWindowRemainingPercent: Int
    var shortWindowReset: String
    var weeklyRemainingPercent: Int
    var weeklyReset: String
    var usageWindowLabel: String
}

struct UsageLimitsResult {
    var limits: UsageLimits?
    var error: String?
}

struct FetchJSONResult {
    var json: [String: Any]?
    var error: String?
}

struct UsageWindow {
    var minutes: Int
    var remainingPercent: Int
    var resetAt: Double?
}

struct ResetCredits {
    var count: Int
    var expirations: [String]
}

extension CodexUsage {
    static let empty = CodexUsage(
        profile: CodexProfile(email: "读取中", plan: "读取中"),
        todayTokens: 0,
        todayThreads: 0,
        weekTokens: 0,
        weekThreads: 0,
        totalTokens: 0,
        totalThreads: 0,
        latestThreadTitle: "读取中",
        latestThreadTokens: 0,
        latestThreadUpdatedAt: "读取中",
        lastRefresh: "读取中"
    )
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
