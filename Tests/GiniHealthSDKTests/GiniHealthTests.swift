import XCTest
@testable import GiniHealthSDK
@testable import GiniHealthAPILibrary
@testable import GiniInternalPaymentSDK
@testable import GiniUtilites

final class GiniHealthTests: XCTestCase {
    
    var giniHealthAPI: GiniHealthAPI!
    var giniHealth: GiniHealth!
    private let versionAPI = 4

    override func setUp() {
        let sessionManagerMock = MockSessionManager()
        let documentService = DefaultDocumentService(sessionManager: sessionManagerMock, apiVersion: versionAPI)
        let paymentService = PaymentService(sessionManager: sessionManagerMock, apiVersion: versionAPI)
        let clientConfigurationService = ClientConfigurationService(sessionManager: sessionManagerMock, apiVersion: versionAPI)
        GiniHealthConfiguration.shared.clientConfiguration = nil
        giniHealthAPI = GiniHealthAPI(documentService: documentService,
                                      paymentService: paymentService,
                                      clientConfigurationService: clientConfigurationService)
        giniHealth = GiniHealth(giniApiLib: giniHealthAPI)
    }

    override func tearDown() {
        giniHealthAPI = nil
        giniHealth = nil
        super.tearDown()
    }
    
    func testSetConfiguration() throws {
        // Given
        let configuration = GiniHealthConfiguration()
        
        // When
        giniHealth.setConfiguration(configuration)
        
        // Then
        XCTAssertEqual(GiniHealthConfiguration.shared, configuration)
    }
    
    func testFetchBankingAppsSuccess() {
        // Given
        let expectedProviders: [GiniHealthSDK.PaymentProvider]? = loadProviders(fileName: "providers")

        // When
        let expectation = self.expectation(description: "Fetching banking apps")
        var receivedProviders: [GiniHealthSDK.PaymentProvider]?
        giniHealth.fetchBankingApps { result in
            switch result {
            case .success(let providers):
                receivedProviders = providers
            case .failure(_):
                receivedProviders = nil
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        
        // Then
        XCTAssertNotNil(receivedProviders)
        XCTAssertEqual(receivedProviders?.count, expectedProviders?.count)
        XCTAssertEqual(receivedProviders, expectedProviders)
    }
    
    func testOpenLinkSuccess() {
        let mockUIApplication = MockUIApplication(canOpen: true)
        let urlOpener = URLOpener(mockUIApplication)
        let waitForWebsiteOpen = expectation(description: "Link was opened")

        giniHealth.openPaymentProviderApp(requestID: "123", universalLink: "ginipay-bank://", urlOpener: urlOpener, completion: { open in
            waitForWebsiteOpen.fulfill()
            XCTAssert(open == true, "testOpenLink - FAILED to open link")
        })

        waitForExpectations(timeout: 0.1, handler: nil)
    }
    
    func testOpenLinkFailure() {
        let mockUIApplication = MockUIApplication(canOpen: false)
        let urlOpener = URLOpener(mockUIApplication)
        let waitForWebsiteOpen = expectation(description: "Link was not opened")

        giniHealth.openPaymentProviderApp(requestID: "123", universalLink: "ginipay-bank://", urlOpener: urlOpener, completion: { open in
            waitForWebsiteOpen.fulfill()
            XCTAssert(open == false, "testOpenLink - MANAGED to open link")
        })

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func testLoadClientConfigurationFromFile() {
        // Given
        let expectedCommunicationType: GiniHealthAPILibrary.CommunicationToneEnum = .formal
        let expectedBrandType: GiniHealthAPILibrary.IngredientBrandTypeEnum = .invisible

        // When
        let expectation = self.expectation(description: "Getting client configuration details")
        var receivedClientConfiguration: ClientConfiguration?

        giniHealth.clientConfigurationService?.fetchConfigurations { result in
            switch result {
            case .success(let clientConfiguration):
                receivedClientConfiguration = clientConfiguration
            case .failure(_):
                receivedClientConfiguration = nil
            }
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)

        XCTAssertNotNil(receivedClientConfiguration)
        XCTAssertEqual(receivedClientConfiguration?.communicationTone, expectedCommunicationType)
        XCTAssertEqual(receivedClientConfiguration?.ingredientBrandType, expectedBrandType)
    }

    func testLoadDefaultClientConfiguration() {
        // Given
        let clientConfiguration = ClientConfiguration()
        let expectedDefaultComunicationTone: GiniHealthAPILibrary.CommunicationToneEnum = .formal
        let expectedDefaultBrandType: GiniHealthAPILibrary.IngredientBrandTypeEnum = .invisible

        // Expected
        XCTAssertNotNil(clientConfiguration)
        XCTAssertEqual(clientConfiguration.communicationTone, expectedDefaultComunicationTone)
        XCTAssertEqual(clientConfiguration.ingredientBrandType, expectedDefaultBrandType)
    }
    
    func testFormalDE() {
        // Given
        let clientConfiguration = ClientConfiguration()
        let configuration = GiniHealthConfiguration()
        let expectedDefaultComunicationTone: GiniHealthAPILibrary.CommunicationToneEnum = .formal
        let expectedDefaultBrandType: GiniHealthAPILibrary.IngredientBrandTypeEnum = .invisible
        
        // When
        configuration.customLocalization = .de
        configuration.clientConfiguration = clientConfiguration
        giniHealth.setConfiguration(configuration)
        

        // Expected
        XCTAssertNotNil(clientConfiguration)
        XCTAssertEqual(clientConfiguration.communicationTone, expectedDefaultComunicationTone)
        XCTAssertEqual(clientConfiguration.ingredientBrandType, expectedDefaultBrandType)
        XCTAssertEqual(giniHealth.installAppStrings.moreInformationTipPattern, "Tipp: Tippen Sie auf 'Weiter', um die Zahlung in der [BANK]-App abzuschließen.")
    }
    
    func testInformalDE() {
        // Given
        let clientConfiguration = ClientConfiguration(communicationTone: .informal)
        let configuration = GiniHealthConfiguration()
        let expectedDefaultComunicationTone: GiniHealthAPILibrary.CommunicationToneEnum = .informal
        let expectedDefaultBrandType: GiniHealthAPILibrary.IngredientBrandTypeEnum = .invisible
        
        // When
        configuration.clientConfiguration = clientConfiguration
        configuration.customLocalization = .de
        giniHealth.setConfiguration(configuration)

        // Expected
        XCTAssertNotNil(clientConfiguration)
        XCTAssertEqual(clientConfiguration.communicationTone, expectedDefaultComunicationTone)
        XCTAssertEqual(clientConfiguration.ingredientBrandType, expectedDefaultBrandType)
        XCTAssertEqual(giniHealth.installAppStrings.moreInformationTipPattern, "Tipp: Tippe auf 'Weiter', um die Zahlung in der [BANK]-App abzuschließen.")
    }
}
