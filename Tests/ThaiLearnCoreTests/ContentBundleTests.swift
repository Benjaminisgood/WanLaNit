import XCTest
import ThaiLearnCore

/// The Mac app looks for course JSON inside a real bundle. These tests build
/// the two layouts Xcode produces: files flattened into Contents/Resources,
/// and a Content folder reference.
final class ContentBundleTests: XCTestCase {
    func testFlatAppBundleLoadsCourse() throws {
        let bundle = try makeAppBundle(nested: false)
        let catalog = try XCTUnwrap(content(from: bundle))
        XCTAssertNotNil(catalog.phrase("greet-hello"))
        XCTAssertEqual(catalog.consonants.count, 44)
    }

    func testContentSubdirectoryBundleLoadsCourse() throws {
        let bundle = try makeAppBundle(nested: true)
        let catalog = try XCTUnwrap(content(from: bundle))
        XCTAssertEqual(catalog.phrase("greet-hello")?.thai, "สวัสดีครับ")
    }

    func testNestedPackageBundleInsideAppLoadsCourse() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wanlanit-bundle-\(UUID().uuidString)", isDirectory: true)
        let resources = root
            .appendingPathComponent(
                "Fake.app/Contents/Resources/ThaiLearn_ThaiLearnCore.bundle/Contents/Resources/Content",
                isDirectory: true
            )
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let source = contentDirectory()
        let names = try FileManager.default.contentsOfDirectory(atPath: source.path)
        for name in names where name.hasSuffix(".json") {
            try FileManager.default.copyItem(
                at: source.appendingPathComponent(name),
                to: resources.appendingPathComponent(name)
            )
        }
        let appURL = root.appendingPathComponent("Fake.app", isDirectory: true)
        let bundle = try XCTUnwrap(Bundle(url: appURL))
        let catalog = try XCTUnwrap(content(from: bundle))
        XCTAssertNotNil(catalog.phrase("greet-hello"))
    }

    func testSwiftPackageResourceBundleLoadsCourse() throws {
        switch ContentLoader.loadApplicationContent() {
        case .success(let catalog):
            XCTAssertNotNil(catalog.phrase("greet-hello"))
        case .failure(let error):
            XCTFail(error.description)
        }
    }

    func testMissingCourseListsEveryPathItTried() throws {
        let bundle = try makeAppBundle(nested: false, copyJSON: false)
        guard case .failure(let error) = ContentLoader.load(from: bundle) else {
            return XCTFail("empty bundle should fail")
        }
        let message = error.issues.joined(separator: "\n")
        XCTAssertTrue(message.contains("应用里没有课程文件。"))
        XCTAssertTrue(message.contains("找过这些位置："))
        let tried = ContentLoader.candidateDirectories(in: bundle).map {
            $0.appendingPathComponent(ContentLoader.markerFileName).path
        }
        XCTAssertFalse(tried.isEmpty)
        for path in tried {
            XCTAssertTrue(message.contains(path), "diagnostic missing \(path)\n\(message)")
        }
    }

    private func content(from bundle: Bundle) -> Catalog? {
        guard case .success(let catalog) = ContentLoader.load(from: bundle) else {
            return nil
        }
        return catalog
    }

    private func makeAppBundle(nested: Bool, copyJSON: Bool = true) throws -> Bundle {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wanlanit-bundle-\(UUID().uuidString)", isDirectory: true)
        let resources = root
            .appendingPathComponent("Fake.app/Contents/Resources", isDirectory: true)
            .appendingPathComponent(nested ? "Content" : "", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        if copyJSON {
            let source = contentDirectory()
            let names = try FileManager.default.contentsOfDirectory(atPath: source.path)
            for name in names where name.hasSuffix(".json") {
                try FileManager.default.copyItem(
                    at: source.appendingPathComponent(name),
                    to: resources.appendingPathComponent(name)
                )
            }
        }
        let appURL = root.appendingPathComponent("Fake.app", isDirectory: true)
        return try XCTUnwrap(Bundle(url: appURL))
    }
}

private func contentDirectory() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Content")
}
