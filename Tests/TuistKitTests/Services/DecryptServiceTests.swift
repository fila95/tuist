import XCTest
import TSCBasic
import TuistSigningTesting
@testable import TuistSupportTesting
@testable import TuistKit

final class DecryptServiceTests: TuistUnitTestCase {
    var subject: DecryptService!
    var signingCipher: MockSigningCipher!
    
    override func setUp() {
        super.setUp()
        
        signingCipher = MockSigningCipher()
        subject = DecryptService(signingCipher: signingCipher)
    }
    
    override func tearDown() {
        super.tearDown()
        
        signingCipher = nil
        subject = nil
    }
    
    func test_calls_decrypt_with_provided_path() throws {
        // Given
        let expectedPath = AbsolutePath("/path")
        var path: AbsolutePath?
        signingCipher.decryptSigningStub = { decryptPath, _ in
            path = decryptPath
        }
        
        // When
        try subject.run(path: expectedPath.pathString)
        
        // Then
        XCTAssertEqual(path, expectedPath)
    }
}
