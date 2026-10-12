import Testing
import Foundation
@testable import pastepCore

@Suite struct FileHistoryPersistenceTests {
    let directory: URL
    let fileURL: URL

    init() throws {
        directory = try makeTemporaryDirectory()
        fileURL = directory.appendingPathComponent("nested/dir/history.json")
    }

    /// テスト専用の UserDefaults ドメイン。使い終わったら消す。
    private func withLegacyDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "pastep.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }

    @Test func load_missingFileReturnsEmpty() {
        #expect(FileHistoryPersistence(fileURL: fileURL).load().isEmpty)
    }

    @Test func saveThenLoad_roundTrips() throws {
        let entries = [text("a\nb"), file("/tmp/x y.txt"), text("日本語 🎉")]
        try FileHistoryPersistence(fileURL: fileURL).save(entries)

        let loaded = FileHistoryPersistence(fileURL: fileURL).load()
        #expect(loaded == entries)
        #expect(loaded.map(\.id) == entries.map(\.id))
        #expect(loaded.map(\.createdAt) == entries.map(\.createdAt))
    }

    @Test func save_createsIntermediateDirectories() throws {
        try FileHistoryPersistence(fileURL: fileURL).save([text("a")])
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func save_overwritesPreviousContent() throws {
        let persistence = FileHistoryPersistence(fileURL: fileURL)
        try persistence.save([text("a"), text("b")])
        try persistence.save([text("c")])
        #expect(persistence.load().map(\.content) == ["c"])
    }

    @Test func save_emptyListIsValid() throws {
        let persistence = FileHistoryPersistence(fileURL: fileURL)
        try persistence.save([text("a")])
        try persistence.save([])
        #expect(persistence.load().isEmpty)
    }

    @Test func save_fileIsReadableOnlyByOwner() throws {
        try FileHistoryPersistence(fileURL: fileURL).save([text("secret")])
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
        #expect(permissions.intValue == 0o600)
    }

    @Test func save_intoUnwritableLocationThrows() throws {
        // 既存の「ファイル」の下にディレクトリは作れない
        let blocker = directory.appendingPathComponent("blocker")
        try Data().write(to: blocker)
        let persistence = FileHistoryPersistence(fileURL: blocker.appendingPathComponent("history.json"))
        #expect(throws: (any Error).self) {
            try persistence.save([text("a")])
        }
    }

    @Test func load_corruptFileReturnsEmpty() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0xFF, 0xFE, 0x00]).write(to: fileURL)
        #expect(FileHistoryPersistence(fileURL: fileURL).load().isEmpty)
    }

    @Test func load_wrongJSONShapeReturnsEmpty() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(#"{"entries": []}"#.utf8).write(to: fileURL)
        #expect(FileHistoryPersistence(fileURL: fileURL).load().isEmpty)
    }

    // MARK: - 旧 UserDefaults からの移行

    @Test func legacy_migratesDataAndRemovesOldKey() throws {
        try withLegacyDefaults { defaults in
            let old = [text("old1"), file("/tmp/old2")]
            defaults.set(try JSONEncoder().encode(old), forKey: FileHistoryPersistence.legacyDefaultsKey)

            let loaded = FileHistoryPersistence(fileURL: fileURL, legacyDefaults: defaults).load()
            #expect(loaded == old)
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
            #expect(defaults.data(forKey: FileHistoryPersistence.legacyDefaultsKey) == nil)

            // 2回目以降はファイルから読む
            #expect(FileHistoryPersistence(fileURL: fileURL, legacyDefaults: defaults).load() == old)
        }
    }

    @Test func legacy_isIgnoredWhenFileAlreadyExists() throws {
        try withLegacyDefaults { defaults in
            try FileHistoryPersistence(fileURL: fileURL).save([text("current")])
            defaults.set(try JSONEncoder().encode([text("old")]), forKey: FileHistoryPersistence.legacyDefaultsKey)

            let loaded = FileHistoryPersistence(fileURL: fileURL, legacyDefaults: defaults).load()
            #expect(loaded.map(\.content) == ["current"])
        }
    }

    @Test func legacy_corruptDataIsLeftUntouched() throws {
        try withLegacyDefaults { defaults in
            defaults.set(Data([0xFF, 0xFE]), forKey: FileHistoryPersistence.legacyDefaultsKey)
            let loaded = FileHistoryPersistence(fileURL: fileURL, legacyDefaults: defaults).load()
            #expect(loaded.isEmpty)
            #expect(defaults.data(forKey: FileHistoryPersistence.legacyDefaultsKey) != nil)
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func legacy_keptWhenMigrationWriteFails() throws {
        try withLegacyDefaults { defaults in
            let blocker = directory.appendingPathComponent("blocker")
            try Data().write(to: blocker)
            let badURL = blocker.appendingPathComponent("history.json")
            defaults.set(try JSONEncoder().encode([text("old")]), forKey: FileHistoryPersistence.legacyDefaultsKey)

            let loaded = FileHistoryPersistence(fileURL: badURL, legacyDefaults: defaults).load()
            #expect(loaded.map(\.content) == ["old"])
            #expect(defaults.data(forKey: FileHistoryPersistence.legacyDefaultsKey) != nil)
        }
    }

    // MARK: - HistoryStore と組み合わせ

    @Test func storeFlushPersistsAcrossInstances() throws {
        let scheduler = ManualScheduler()
        let store = HistoryStore(persistence: FileHistoryPersistence(fileURL: fileURL), scheduler: scheduler)
        store.add(text("first"))
        store.add(file("/tmp/second"))
        store.flush()

        let reopened = HistoryStore(persistence: FileHistoryPersistence(fileURL: fileURL), scheduler: scheduler)
        #expect(reopened.entries.map(\.content) == ["/tmp/second", "first"])
    }
}
