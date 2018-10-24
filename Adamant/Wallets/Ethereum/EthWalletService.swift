//
//  EthWalletService.swift
//  Adamant
//
//  Created by Anokhov Pavel on 03.08.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation
import UIKit
import web3swift
import Swinject
import Alamofire
import BigInt

extension Web3Error {
	func asWalletServiceError() -> WalletServiceError {
		switch self {
		case .connectionError:
			return .networkError
			
		case .nodeError(let message):
			return .remoteServiceError(message: message)
			
		case .generalError(let error),
			 .keystoreError(let error as Error):
			return .internalError(message: error.localizedDescription, error: error)
			
		case .inputError(let message), .processingError(let message):
			return .internalError(message: message, error: nil)
			
		case .transactionSerializationError,
			 .dataError,
			 .walletError,
			 .unknownError:
			return .internalError(message: "Unknown error", error: nil)
		}
	}
}

class EthWalletService: WalletService {
	// MARK: - Constants
	let addressRegex = try! NSRegularExpression(pattern: "^0x[a-fA-F0-9]{40}$")
	
	static let currencySymbol = "ETH"
	static let currencyLogo = #imageLiteral(resourceName: "wallet_eth")
	static let currencyExponent = -18
	
	private (set) var transactionFee: Decimal = 0.0
	
	static let transferGas: Decimal = 21000
	static let kvsAddress = "eth:address"
	
	
	// MARK: - Dependencies
	weak var accountService: AccountService!
	var apiService: ApiService!
	var dialogService: DialogService!
	var router: Router!
	
	
	// MARK: - Notifications
	let walletUpdatedNotification = Notification.Name("adamant.ethWallet.walletUpdated")
	let serviceEnabledChanged = Notification.Name("adamant.ethWallet.enabledChanged")
	let transactionFeeUpdated = Notification.Name("adamant.ethWallet.feeUpdated")
	
    
    // MARK: RichMessageProvider properties
    static let richMessageType = "eth_transaction"
    let cellIdentifierSent = "ethTransferSent"
    let cellIdentifierReceived = "ethTransferReceived"
    let cellSource: CellSource? = CellSource.nib(nib: UINib(nibName: "TransferCollectionViewCell", bundle: nil))
    
    
	// MARK: - Properties
	
	let web3: web3
	private let baseUrl: String
	let defaultDispatchQueue = DispatchQueue(label: "im.adamant.ethWalletService", qos: .utility, attributes: [.concurrent])
	private (set) var enabled = true
	
	let stateSemaphore = DispatchSemaphore(value: 1)
	
	var walletViewController: WalletViewController {
		guard let vc = router.get(scene: AdamantScene.Wallets.Ethereum.wallet) as? EthWalletViewController else {
			fatalError("Can't get EthWalletViewController")
		}
		
		vc.service = self
		return vc
	}
    
    private var initialBalanceCheck = false
	
	// MARK: - State
	private (set) var state: WalletServiceState = .notInitiated
	private (set) var ethWallet: EthWallet? = nil
	
	var wallet: WalletAccount? { return ethWallet }
	
    // MARK: - Delayed KVS save
    private var balanceObserver: NSObjectProtocol? = nil
    
	// MARK: - Logic
	init(apiUrl: String) throws {
		// Init network
		guard let url = URL(string: apiUrl), let web3 = Web3.new(url) else {
			throw WalletServiceError.networkError
		}
		
		self.web3 = web3
		self.baseUrl = EthWalletService.buildBaseUrl(for: web3.provider.network)
		
		// Notifications
		NotificationCenter.default.addObserver(forName: Notification.Name.AdamantAccountService.userLoggedIn, object: nil, queue: nil) { [weak self] _ in
			self?.update()
		}
		
		NotificationCenter.default.addObserver(forName: Notification.Name.AdamantAccountService.accountDataUpdated, object: nil, queue: nil) { [weak self] _ in
			self?.update()
		}
		
		NotificationCenter.default.addObserver(forName: Notification.Name.AdamantAccountService.userLoggedOut, object: nil, queue: nil) { [weak self] _ in
			self?.ethWallet = nil
            self?.initialBalanceCheck = false
            if let balanceObserver = self?.balanceObserver {
                NotificationCenter.default.removeObserver(balanceObserver)
                self?.balanceObserver = nil
            }
		}
	}
	
	func update() {
		guard let wallet = ethWallet else {
			return
		}
		
		defer { stateSemaphore.signal() }
		stateSemaphore.wait()
		
		switch state {
		case .notInitiated, .updating:
			return
			
		case .initiated, .updated:
			break
		}
		
		state = .updating
		
		getBalance(forAddress: wallet.ethAddress) { [weak self] result in
            if let stateSemaphore = self?.stateSemaphore {
                defer {
                    stateSemaphore.signal()
                }
                stateSemaphore.wait()
                self?.state = .updated
            }
            
			switch result {
			case .success(let balance):
                let notification: Notification.Name?
                
				if wallet.balance != balance {
					wallet.balance = balance
                    notification = self?.walletUpdatedNotification
                    self?.initialBalanceCheck = false
                } else if let initialBalanceCheck = self?.initialBalanceCheck, initialBalanceCheck {
                    self?.initialBalanceCheck = false
                    notification = self?.walletUpdatedNotification
                } else {
                    notification = nil
                }
                
                if let notification = notification {
                    NotificationCenter.default.post(name: notification, object: self, userInfo: [AdamantUserInfoKey.WalletService.wallet: wallet])
                }
				
			case .failure(let error):
				self?.dialogService.showRichError(error: error)
			}
		}
		
		getGasPrices { [weak self] result in
			switch result {
			case .success(let price):
				guard let fee = self?.transactionFee else {
					return
				}
				
				let newFee = price * EthWalletService.transferGas
				
				if fee != newFee {
					self?.transactionFee = newFee
					
					if let notification = self?.transactionFeeUpdated {
						NotificationCenter.default.post(name: notification, object: self, userInfo: nil)
					}
				}
				
			case .failure:
				break
			}
		}
	}
	
	// MARK: - Tools
	
	func validate(address: String) -> AddressValidationResult {
		return addressRegex.perfectMatch(with: address) ? .valid : .invalid
	}
	
	func getGasPrices(completion: @escaping (WalletServiceResult<Decimal>) -> Void) {
		switch web3.eth.getGasPrice() {
		case .success(let price):
			completion(.success(result: price.asDecimal(exponent: EthWalletService.currencyExponent)))
			
		case .failure(let error):
			completion(.failure(error: error.asWalletServiceError()))
		}
	}
	
	private static func buildBaseUrl(for network: Networks?) -> String {
		let suffix: String
		
		guard let network = network else {
			return "https://api.etherscan.io/api"
		}
		
		switch network {
		case .Mainnet:
			suffix = ""
			
		default:
			suffix = "-\(network)"
		}
		
		return "https://api\(suffix).etherscan.io/api"
	}
	
	private func buildUrl(queryItems: [URLQueryItem]? = nil) throws -> URL {
		guard let url = URL(string: baseUrl), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			throw AdamantApiService.InternalError.endpointBuildFailed
		}
		
		components.queryItems = queryItems
		
		return try components.asURL()
	}
}


// MARK: - WalletInitiatedWithPassphrase
extension EthWalletService: InitiatedWithPassphraseService {
	func initWallet(withPassphrase passphrase: String, completion: @escaping (WalletServiceResult<WalletAccount>) -> Void) {
        guard let adamant = accountService.account else {
            completion(.failure(error: .notLogged))
            return
        }
        
		// MARK: 1. Prepare
		stateSemaphore.wait()
		
		state = .notInitiated
		
		if enabled {
			enabled = false
			NotificationCenter.default.post(name: serviceEnabledChanged, object: self)
		}
		
		// MARK: 2. Create keys and addresses
		let keystore: BIP32Keystore
		do {
			guard let store = try BIP32Keystore(mnemonics: passphrase, password: "", mnemonicsPassword: "", language: .english) else {
				completion(.failure(error: .internalError(message: "ETH Wallet: failed to create Keystore", error: nil)))
				stateSemaphore.signal()
				return
			}
			
			keystore = store
		} catch {
			completion(.failure(error: .internalError(message: "ETH Wallet: failed to create Keystore", error: error)))
			stateSemaphore.signal()
			return
		}
		
		web3.addKeystoreManager(KeystoreManager([keystore]))
		
		guard let ethAddress = keystore.addresses?.first else {
			completion(.failure(error: .internalError(message: "ETH Wallet: failed to create Keystore", error: nil)))
			stateSemaphore.signal()
			return
		}
		
		// MARK: 3. Update
        let eWallet = EthWallet(address: ethAddress.address, ethAddress: ethAddress, keystore: keystore)
		ethWallet = eWallet
		state = .initiated
		
		if !enabled {
			enabled = true
			NotificationCenter.default.post(name: serviceEnabledChanged, object: self)
		}
		
		stateSemaphore.signal()
		
		// MARK: 4. Save into KVS
        getWalletAddress(byAdamantAddress: adamant.address) { [weak self] result in
            switch result {
            case .success(let address):
                // ETH already saved
                if address != ethAddress.address {
                    self?.save(ethAddress: ethAddress.address) { result in
                        self?.kvsSaveCompletionRecursion(ethAddress: ethAddress.address, result: result)
                    }
                }
                
                self?.initialBalanceCheck = true
                self?.update()
                
                completion(.success(result: eWallet))
                
            case .failure(let error):
                switch error {
                case .walletNotInitiated:
                    // Show '0' without waiting for balance update
                    if let notification = self?.walletUpdatedNotification, let wallet = self?.ethWallet {
                        NotificationCenter.default.post(name: notification, object: self, userInfo: [AdamantUserInfoKey.WalletService.wallet: wallet])
                    }
                    
                    self?.save(ethAddress: ethAddress.address) { result in
                        self?.kvsSaveCompletionRecursion(ethAddress: ethAddress.address, result: result)
                    }
                    
                    completion(.success(result: eWallet))
                    
                default:
                    completion(.failure(error: error))
                }
            }
        }
	}
    
    
    /// New accounts doesn't have enought money to save KVS. We need to wait for balance update, and then - retry save
    private func kvsSaveCompletionRecursion(ethAddress: String, result: WalletServiceSimpleResult) {
        if let observer = balanceObserver {
            NotificationCenter.default.removeObserver(observer)
            balanceObserver = nil
        }
        
        switch result {
        case .success:
            break
            
        case .failure(let error):
            switch error {
            case .notEnoughtMoney:  // Possibly new account, we need to wait for dropship
                // Register observer
                let observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.AdamantAccountService.accountDataUpdated, object: nil, queue: nil) { [weak self] _ in
                    guard let balance = self?.accountService.account?.balance, balance > AdamantApiService.KvsFee else {
                        return
                    }
                    
                    self?.save(ethAddress: ethAddress) { result in
                        self?.kvsSaveCompletionRecursion(ethAddress: ethAddress, result: result)
                    }
                }
                
                // Save referense to unregister it later
                balanceObserver = observer
                
            default:
                dialogService.showRichError(error: error)
            }
        }
    }
}


// MARK: - Dependencies
extension EthWalletService: SwinjectDependentService {
	func injectDependencies(from container: Container) {
		accountService = container.resolve(AccountService.self)
		apiService = container.resolve(ApiService.self)
		dialogService = container.resolve(DialogService.self)
		router = container.resolve(Router.self)
	}
}


// MARK: - Balances & addresses
extension EthWalletService {
	func getBalance(forAddress address: EthereumAddress, completion: @escaping (WalletServiceResult<Decimal>) -> Void) {
		DispatchQueue.global(qos: .utility).async { [weak self] in
			guard let web3 = self?.web3 else {
				print("Can't get web3 service")
				return
			}
			
			let result = web3.eth.getBalance(address: address)
			
			switch result {
			case .success(let balance):
				completion(.success(result: balance.asDecimal(exponent: EthWalletService.currencyExponent)))
				
			case .failure(let error):
				completion(.failure(error: error.asWalletServiceError()))
			}
		}
	}
	
	
	func getWalletAddress(byAdamantAddress address: String, completion: @escaping (WalletServiceResult<String>) -> Void) {
		apiService.get(key: EthWalletService.kvsAddress, sender: address) { (result) in
			switch result {
			case .success(let value):
				if let address = value {
					completion(.success(result: address))
				} else {
					completion(.failure(error: .walletNotInitiated))
				}
				
			case .failure(let error):
				completion(.failure(error: .internalError(message: "ETH Wallet: fail to get address from KVS", error: error)))
			}
		}
	}
}


// MARK: - KVS
extension EthWalletService {
	/// - Parameters:
	///   - ethAddress: Ethereum address to save into KVS
	///   - adamantAddress: Owner of Ethereum address
	///   - completion: success
    private func save(ethAddress: String, completion: @escaping (WalletServiceSimpleResult) -> Void) {
		guard let adamant = accountService.account, let keypair = accountService.keypair else {
			completion(.failure(error: .notLogged))
			return
		}
		
        guard adamant.balance >= AdamantApiService.KvsFee else {
            completion(.failure(error: .notEnoughtMoney))
            return
        }
        
        apiService.store(key: EthWalletService.kvsAddress, value: ethAddress, type: .keyValue, sender: adamant.address, keypair: keypair) { result in
            switch result {
            case .success:
                completion(.success)
                
            case .failure(let error):
                completion(.failure(error: .apiError(error)))
            }
        }
	}
}


// MARK: - Transactions
extension EthWalletService {
	func getTransactionsHistory(address: String, page: Int = 1, size: Int = 50, completion: @escaping (WalletServiceResult<[EthTransaction]>) -> Void) {
		let queryItems: [URLQueryItem] = [URLQueryItem(name: "module", value: "account"),
										  URLQueryItem(name: "action", value: "txlist"),
										  URLQueryItem(name: "address", value: address),
										  URLQueryItem(name: "page", value: "\(page)"),
										  URLQueryItem(name: "offset", value: "\(size)"),
										  URLQueryItem(name: "sort", value: "desc")
			//			            ,URLQueryItem(name: "apikey", value: "YourApiKeyToken")
		]
		
		let endpoint: URL
		do {
			endpoint = try buildUrl(queryItems: queryItems)
		} catch {
			let err = AdamantApiService.InternalError.endpointBuildFailed.apiServiceErrorWith(error: error)
			completion(.failure(error: WalletServiceError.apiError(err)))
			return
		}
		
		Alamofire.request(endpoint).responseData(queue: defaultDispatchQueue) { response in
			switch response.result {
			case .success(let data):
				do {
					let model: EthResponse = try JSONDecoder().decode(EthResponse.self, from: data)
					
					if model.status == 1 {
                        var transactions = model.result
                        
                        for index in 0..<transactions.count {
                            let from = transactions[index].from
                            transactions[index].isOutgoing = from == address
                        }
                        
						completion(.success(result: transactions))
					} else {
						completion(.failure(error: .remoteServiceError(message: model.message)))
					}
				} catch {
					completion(.failure(error: .internalError(message: "Failed to deserialize transactions", error: error)))
				}
				
			case .failure:
				completion(.failure(error: .networkError))
			}
		}
	}
	
    func getTransaction(by hash: String, completion: @escaping (WalletServiceResult<EthTransaction>) -> Void) {
        let sender = wallet?.address
        let eth = web3.eth
        
        DispatchQueue.global(qos: .utility).async {
            do {
                // MARK: 1. Transaction's details and receipt
                let details = try eth.getTransactionDetailsPromise(hash).wait()
                let receipt = try eth.getTransactionReceiptPromise(hash).wait()
                
                // MARK: 2. Determine if transaction is outcome or income
                let isOutgoing: Bool
                if let sender = sender {
                    isOutgoing = details.transaction.to.address != sender
                } else {
                    isOutgoing = false
                }
                
                // MARK: 3. Check if transaction is delivered
                guard receipt.status == .ok, let blockNumber = details.blockNumber else {
                    let transaction = details.transaction.asEthTransaction(date: nil, gasUsed: receipt.gasUsed, blockNumber: nil, confirmations: nil, receiptStatus: receipt.status, isOutgoing: isOutgoing)
                    completion(.success(result: transaction))
                    return
                }
                
                // MARK: 4. Block timestamp & confirmations
                let currentBlock = try eth.getBlockNumberPromise().wait()
                let block = try eth.getBlockByNumberPromise(blockNumber).wait()
                let confirmations = currentBlock - blockNumber
                
                let transaction = details.transaction.asEthTransaction(date: block.timestamp, gasUsed: receipt.gasUsed, blockNumber: String(blockNumber), confirmations: String(confirmations), receiptStatus: receipt.status, isOutgoing: isOutgoing)
                
                completion(.success(result: transaction))
                
            } catch let error as Web3Error {
                completion(.failure(error: error.asWalletServiceError()))
            } catch {
                completion(.failure(error: WalletServiceError.internalError(message: "Failed to get transaction", error: error)))
            }
        }
    }
}
