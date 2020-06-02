import TSCBasic
import Foundation
import TuistSupport
import XCTest
@testable import TuistCoreTesting
@testable import TuistSigning
@testable import TuistSupportTesting

final class SecurityControllerTests: TuistUnitTestCase {
    var subject: SecurityController!

    override func setUp() {
        super.setUp()
        subject = SecurityController()
    }

    override func tearDown() {
        subject = nil
        super.tearDown()
    }

    func test_decode_file() throws {
        // Given
        let decodeFilePath = try temporaryPath()

        let expectedOutput = "output"
        system.succeedCommand("/usr/bin/security", "cms", "-D", "-i", decodeFilePath.pathString, output: expectedOutput)

        // When
        let output = try subject.decodeFile(at: decodeFilePath)

        // Then
        XCTAssertEqual(expectedOutput, output)
    }

    func test_import_certificate_and_private_key_succeeds() throws {
        // Given
        let certificatePath = try temporaryPath()
        let privateKeyPath = try temporaryPath()
        let certificate = Certificate.test(publicKey: certificatePath, privateKey: privateKeyPath)
        let keychainPath = try temporaryPath()

        system.errorCommand("/usr/bin/security", "find-certificate", certificatePath.pathString, "-P", "")
        system.errorCommand("/usr/bin/security", "find-key", privateKeyPath.pathString, "-P", "")
        system.succeedCommand("/usr/bin/security", "import", certificatePath.pathString, "-P", "", "-k", keychainPath.pathString)
        system.succeedCommand("/usr/bin/security", "import", privateKeyPath.pathString, "-P", "", "-k", keychainPath.pathString)

        // When
        try subject.importCertificate(certificate, keychainPath: keychainPath)
        
        // Then
        XCTAssertPrinterContains("Imported certificate at \(certificate.publicKey.pathString)", at: .debug, ==)
        XCTAssertPrinterContains("Imported certificate private key at \(certificate.privateKey.pathString)", at: .debug, ==)
    }

    func test_skips_certificate_when_already_imported() throws {
        // Given
        let certificatePath = try temporaryPath()
        let privateKeyPath = try temporaryPath()
        let certificate = Certificate.test(publicKey: certificatePath, privateKey: privateKeyPath)
        let keychainPath = try temporaryPath()

        system.succeedCommand("/usr/bin/security", "find-certificate", certificatePath.pathString, "-P", "")
        system.succeedCommand("/usr/bin/security", "find-key", privateKeyPath.pathString, "-P", "")

        // When
        try subject.importCertificate(certificate, keychainPath: keychainPath)
        
        // Then
        XCTAssertPrinterContains(
            "Skipping importing certificate at \(certificate.publicKey.pathString) because it is already present",
            at: .debug, ==
        )
        XCTAssertPrinterContains(
            "Skipping importing private key at \(privateKeyPath.pathString) because it is already present",
            at: .debug, ==
        )
    }
    
    func test_keychain_is_created() throws {
        // Given
        let keychainPath = try temporaryPath()
        let password = ""
        system.succeedCommand("/usr/bin/security", "create-keychain", "-p", password, keychainPath.pathString)
        
        // When
        try subject.createKeychain(at: keychainPath, password: password)
        
        // Then
        XCTAssertPrinterContains("Created keychain at \(keychainPath.pathString)", at: .debug, ==)
    }
    
    func test_keychain_already_exists() throws {
        // Given
        let keychainPath = try temporaryPath()
        let password = ""
        system.errorCommand(
            ["/usr/bin/security", "create-keychain", "-p", password, keychainPath.pathString],
            error: "A keychain with the same name already exists."
        )
        
        // When
        try subject.createKeychain(at: keychainPath, password: password)
        
        // Then
        XCTAssertPrinterContains("Keychain at \(keychainPath.pathString) already exists", at: .debug, ==)
    }
    
    func test_keychain_is_unlocked() throws {
        // Given
        let keychainPath = try temporaryPath()
        let password = ""
        system.succeedCommand("/usr/bin/security", "unlock-keychain", "-p", password, keychainPath.pathString)
        
        // When
        try subject.unlockKeychain(at: keychainPath, password: password)
        
        // Then
        XCTAssertPrinterContains("Unlocked keychain at \(keychainPath.pathString)", at: .debug, ==)
    }
    
    func test_keychain_is_locked() throws {
        // Given
        let keychainPath = try temporaryPath()
        let password = ""
        system.succeedCommand("/usr/bin/security", "lock-keychain", "-p", password, keychainPath.pathString)
        
        // When
        try subject.lockKeychain(at: keychainPath, password: password)
        
        // Then
        XCTAssertPrinterContains("Locked keychain at \(keychainPath.pathString)", at: .debug, ==)
    }
}
