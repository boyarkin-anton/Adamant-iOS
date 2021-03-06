//
//  TransactionDetailsViewController.swift
//  Adamant
//
//  Created by Anokhov Pavel on 09.01.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import SafariServices


// MARK: - Localization
extension String.adamantLocalized.alert {
	static let exportUrlButton = NSLocalizedString("TransactionDetailsScene.Share.URL", comment: "Export transaction: 'Share transaction URL' button")
	static let exportSummaryButton = NSLocalizedString("TransactionDetailsScene.Share.Summary", comment: "Export transaction: 'Share transaction summary' button")
}


// MARK: - 
class TransactionDetailsViewController: UIViewController {
	fileprivate enum Row: Int {
		case transactionNumber = 0
		case from
		case to
		case date
		case amount
		case fee
		case confirmations
		case block
		case openInExplorer
		
		static let total = 9
		
		var localized: String {
			switch self {
			case .transactionNumber: return NSLocalizedString("TransactionDetailsScene.Row.Id", comment: "Transaction details: Id row.")
			case .from: return NSLocalizedString("TransactionDetailsScene.Row.From", comment: "Transaction details: sender row.")
			case .to: return NSLocalizedString("TransactionDetailsScene.Row.To", comment: "Transaction details: recipient row.")
			case .date: return NSLocalizedString("TransactionDetailsScene.Row.Date", comment: "Transaction details: date row.")
			case .amount: return NSLocalizedString("TransactionDetailsScene.Row.Amount", comment: "Transaction details: amount row.")
			case .fee: return NSLocalizedString("TransactionDetailsScene.Row.Fee", comment: "Transaction details: fee row.")
			case .confirmations: return NSLocalizedString("TransactionDetailsScene.Row.Confirmations", comment: "Transaction details: confirmations row.")
			case .block: return NSLocalizedString("TransactionDetailsScene.Row.Block", comment: "Transaction details: Block id row.")
			case .openInExplorer: return NSLocalizedString("TransactionDetailsScene.Row.Explorer", comment: "Transaction details: 'Open transaction in explorer' row.")
			}
		}
	}
	
	// MARK: - Dependencies
	var dialogService: DialogService!
	
	// MARK: - Properties
	private let cellIdentifier = "cell"
	var transaction: TransferTransaction?
	var explorerUrl: URL!
	
	// MARK: - IBOutlets
	@IBOutlet weak var tableView: UITableView!
	
	override func viewDidLoad() {
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share))
		tableView.dataSource = self
		tableView.delegate = self
		
		if let transaction = transaction {
			tableView.reloadData()
			
			if let id = transaction.transactionId {
				explorerUrl = URL(string: "https://explorer.adamant.im/tx/\(id)")
			}
		} else {
			self.navigationItem.rightBarButtonItems = nil
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if let indexPath = tableView.indexPathForSelectedRow {
			tableView.deselectRow(at: indexPath, animated: animated)
		}
	}
	
	@IBAction func share(_ sender: Any) {
		guard let transaction = transaction, let url = explorerUrl else {
			return
		}
		
		let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
		alert.addAction(UIAlertAction(title: String.adamantLocalized.alert.cancel, style: .cancel, handler: nil))
		
		// URL
		alert.addAction(UIAlertAction(title: String.adamantLocalized.alert.exportUrlButton, style: .default) { [weak self] _ in
			let alert = UIActivityViewController(activityItems: [url], applicationActivities: nil)
			self?.present(alert, animated: true, completion: nil)
		})
		
		// Description
		alert.addAction(UIAlertAction(title: String.adamantLocalized.alert.exportSummaryButton, style: .default, handler: { [weak self] _ in
			let text = AdamantFormattingTools.summaryFor(transaction: transaction, url: url)
			let alert = UIActivityViewController(activityItems: [text], applicationActivities: nil)
			self?.present(alert, animated: true, completion: nil)
		}))
		
		present(alert, animated: true, completion: nil)
	}
}


// MARK: - UITableView
extension TransactionDetailsViewController: UITableViewDataSource, UITableViewDelegate {
	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if transaction != nil {
			return Row.total
		} else {
			return 0
		}
	}
	
	func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		return UIView()
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return 50
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if indexPath.row == Row.openInExplorer.rawValue,
			let url = explorerUrl {
			let safari = SFSafariViewController(url: url)
			safari.preferredControlTintColor = UIColor.adamantPrimary
			present(safari, animated: true, completion: nil)
			return
		}
		
		guard let cell = tableView.cellForRow(at: indexPath),
			let row = Row(rawValue: indexPath.row),
			let details = cell.detailTextLabel?.text else {
			tableView.deselectRow(at: indexPath, animated: true)
			return
		}
		
		let payload: String
		switch row {
		case .amount:
			payload = "\(row.localized): \(details)"
			
		case .date:
			payload = "\(row.localized): \(details)"
			
		case .confirmations:
			payload = "\(row.localized): \(details)"
			
		case .fee:
			payload = "\(row.localized): \(details)"
			
		case .transactionNumber:
			payload = "\(row.localized): \(details)"
			
		case .from:
			payload = "\(row.localized): \(details)"
			
		case .to:
			payload = "\(row.localized): \(details)"
			
		case .block:
			payload = "\(row.localized): \(details)"
			
		case .openInExplorer:
			payload = ""
		}
		
		dialogService.presentShareAlertFor(string: payload,
										   types: [.copyToPasteboard, .share],
										   excludedActivityTypes: nil,
										   animated: true) {
			tableView.deselectRow(at: indexPath, animated: true)
		}
	}
}


// MARK: - UITableView Cells
extension TransactionDetailsViewController {
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let transaction = transaction, let row = Row(rawValue: indexPath.row) else {
			// TODO: Display & Log error
			return UITableViewCell(style: .default, reuseIdentifier: cellIdentifier)
		}
		
		var cell: UITableViewCell
		if let c = tableView.dequeueReusableCell(withIdentifier: cellIdentifier) {
			cell = c
			cell.accessoryType = .none
		} else {
			cell = UITableViewCell(style: .value1, reuseIdentifier: cellIdentifier)
			cell.textLabel?.textColor = UIColor.adamantPrimary
			cell.detailTextLabel?.textColor = UIColor.adamantSecondary
			
			let font = UIFont.adamantPrimary(size: 17)
			cell.textLabel?.font = font
			cell.detailTextLabel?.font = font
		}
		
		cell.textLabel?.text = row.localized
		
		switch row {
		case .amount:
			if let amount = transaction.amount {
				cell.detailTextLabel?.text = AdamantUtilities.format(balance: amount)
			}
			
		case .date:
			if let date = transaction.date as Date? {
				cell.detailTextLabel?.text = DateFormatter.localizedString(from: date, dateStyle: .short, timeStyle: .medium)
			}
			
		case .confirmations:
			cell.detailTextLabel?.text = String(transaction.confirmations)
			
		case .fee:
			if let fee = transaction.fee {
				cell.detailTextLabel?.text = AdamantUtilities.format(balance: fee)
			}
			
		case .transactionNumber:
			if let id = transaction.transactionId {
				cell.detailTextLabel?.text = String(id)
			}
			
		case .from:
			cell.detailTextLabel?.text = transaction.senderId
			
		case .to:
			cell.detailTextLabel?.text = transaction.recipientId
			
		case .block:
			cell.detailTextLabel?.text = transaction.blockId
			
		case .openInExplorer:
			cell.detailTextLabel?.text = nil
			cell.accessoryType = .disclosureIndicator
		}
		
		return cell
	}
}
