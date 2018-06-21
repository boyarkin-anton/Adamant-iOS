//
//  NodesListViewController.swift
//  Adamant
//
//  Created by Anton Boyarkin on 13/06/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit
import Eureka

// MARK: - SecuredStore keys
extension StoreKey {
    struct nodesList {
        static let userNodes = "nodesList.userNodes"
    }
}

// MARK: - Localization
extension String.adamantLocalized {
    struct nodesList {
        static let nodesListButton = NSLocalizedString("NodesList.NodesList", comment: "NodesList: Button label")
        static let title = NSLocalizedString("NodesList.Title", comment: "NodesList: scene title")
        static let saved = NSLocalizedString("NodesList.Saved", comment: "NodesList: 'Saved' message")
        static let unableToSave = NSLocalizedString("NodesList.UnableToSave", comment: "NodesList: 'Unable To Save' message")
        //static let nodeUrl = NSLocalizedString("NodesList.NodeUrl", comment: "NodesList: 'Node url' plaseholder")
		
		static let resetAlertTitle = NSLocalizedString("NodesList.ResetNodeList", comment: "NodesList: Reset nodes alert title")
		
        private init() {}
    }
}


// MARK: - NodesListViewController
class NodesListViewController: FormViewController {
	// Rows & Sections
	
	private enum Sections {
		case nodes
		case buttons
		case reset
		
		var tag: String {
			switch self {
			case .nodes: return "nds"
			case .buttons: return "bttns"
			case .reset: return "reset"
			}
		}
		
		var localized: String? {
			switch self {
			case .nodes: return nil
			case .buttons: return nil
			case .reset: return nil
			}
		}
	}
	
	private enum Rows {
		case addNode
		case save
		case reset
		
		var localized: String {
			switch self {
			case .addNode:
				return NSLocalizedString("NodesList.AddNewNode", comment: "NodesList: 'Add new node' button lable")
				
			case .save:
				return String.adamantLocalized.alert.save
				
			case .reset:
				return NSLocalizedString("NodesList.ResetButton", comment: "NodesList: 'Reset' button")
			}
		}
	}
	
	
    // MARK: Dependencies
    var dialogService: DialogService!
    var securedStore: SecuredStore!
    var apiService: ApiService!
	var router: Router!
	
	
	// Properties
	
	private var nodes = [Node]()
	
	
    // MARK: - Lifecycle
	
    override func viewDidLoad() {
        super.viewDidLoad()
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editModeStart))
        navigationItem.title = String.adamantLocalized.nodesList.title
        navigationOptions = .Disabled
        
        if self.navigationController?.viewControllers.count == 1 {
            let cancelBtn = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(NodesListViewController.close))
            
            self.navigationItem.setLeftBarButton(cancelBtn, animated: false)
        }
		
		
		// MARK: Nodes
		
		let section = Section() {
			$0.tag = Sections.nodes.tag
		}
		
		let serverUrls: [String]
		if let usersNodesString = self.securedStore.get(StoreKey.nodesList.userNodes), let usersNodes = AdamantUtilities.toArray(text: usersNodesString) {
			serverUrls = usersNodes
		} else {
			serverUrls = AdamantResources.servers
		}
		
		for url in serverUrls {
			section <<< LabelRow() {
				$0.title = url
			}.cellUpdate({ (cell, _) in
				if let label = cell.textLabel {
					label.textColor = UIColor.adamantPrimary
				}
				
				cell.accessoryType = .disclosureIndicator
			}).onCellSelection { [weak self] (_, row) in
//				guard let node = row.value, let tag = row.tag else {
//					return
//				}
//
//				self?.editNode(node, tag: tag)
			}
		}
		
		form +++ section
		
		
		// MARK: Buttons
		
        +++ Section()
		
		// Add node
		<<< ButtonRow() {
			$0.title = Rows.addNode.localized
		}.cellSetup({ (cell, _) in
			cell.selectionStyle = .gray
		}).onCellSelection({ [weak self] (_, _) in
			self?.createNewNode()
		}).cellSetup({ (cell, row) in
			cell.textLabel?.font = UIFont.adamantPrimary(size: 17)
			cell.textLabel?.textColor = UIColor.adamantPrimary
		}).cellUpdate({ (cell, _) in
			cell.textLabel?.textColor = UIColor.adamantPrimary
		})
			
		// Save
		<<< ButtonRow() {
			$0.title = Rows.save.localized
		}.cellSetup({ (cell, _) in
			cell.selectionStyle = .gray
		}).onCellSelection({ [weak self] (_, _) in
			self?.save()
		}).cellSetup({ (cell, row) in
			cell.textLabel?.font = UIFont.adamantPrimary(size: 17)
			cell.textLabel?.textColor = UIColor.adamantPrimary
		}).cellUpdate({ (cell, _) in
			cell.textLabel?.textColor = UIColor.adamantPrimary
		})
			
			
		// MARK: Reset
			
		+++ Section()
		<<< ButtonRow() {
			$0.title = Rows.reset.localized
		}.onCellSelection({ [weak self] (_, _) in
			self?.resetToDefault()
		}).cellSetup({ (cell, row) in
			cell.textLabel?.font = UIFont.adamantPrimary(size: 17)
			cell.textLabel?.textColor = UIColor.adamantPrimary
		}).cellUpdate({ (cell, _) in
			cell.textLabel?.textColor = UIColor.adamantPrimary
		})
    }
	
	@objc func editModeStart() {
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(editModeStop))
		tableView.setEditing(true, animated: true)
	}
	
	@objc func editModeStop() {
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editModeStart))
		tableView.setEditing(false, animated: true)
	}
}


// MARK: - Manipulating node list
extension NodesListViewController {
	func createNewNode() {
		presentEditor(forNode: nil, tag: nil)
	}
	
	func removeNode(at index: Int) {
		nodes.remove(at: index)
		
		if let section = form.sectionBy(tag: Sections.nodes.tag) {
			section.remove(at: index)
		}
	}
	
	func editNode(_ node: Node, tag: String) {
		presentEditor(forNode: node, tag: tag)
	}
	
	@objc func close() {
		if self.navigationController?.viewControllers.count == 1 {
			self.dismiss(animated: true, completion: nil)
		} else {
			self.navigationController?.popViewController(animated: true)
		}
	}
	
	func save() {
		for node in nodes {
			print(node.toString())
		}
		
//		self.dialogService.showProgress(withMessage: nil, userInteractionEnable: false)
//		let values = self.form.values()
//		if let nodes = values["nodes"] as? [String] {
//
//			if let jsonNodesList = AdamantUtilities.json(from:nodes) {
//				self.securedStore.set(jsonNodesList, for: StoreKey.nodesList.userNodes)
//				print("\(jsonNodesList)")
//			} else {
//				self.dialogService.showError(withMessage: String.adamantLocalized.nodesList.unableToSave, error: nil)
//				return
//			}
//			self.apiService.updateServersList(servers: nodes)
//
//			self.dialogService.showSuccess(withMessage: String.adamantLocalized.nodesList.saved)
//			self.dialogService.dismissProgress()
//			self.close()
//		} else {
//			self.dialogService.dismissProgress()
//			self.dialogService.showError(withMessage: String.adamantLocalized.nodesList.unableToSave, error: nil)
//		}
	}
	
	func resetToDefault() {
		let alert = UIAlertController(title: String.adamantLocalized.nodesList.resetAlertTitle, message: nil, preferredStyle: .alert)
		
		alert.addAction(UIAlertAction(title: String.adamantLocalized.alert.cancel, style: .cancel, handler: nil))
		
		alert.addAction(UIAlertAction(title: Rows.reset.localized, style: .destructive, handler: { [weak self] (_) in
			let nodes: [Node] = [
				Node(protocol: .https, url: "endless.adamant.im", port: nil),
				Node(protocol: .https, url: "clown.adamant.im", port: nil),
				Node(protocol: .https, url: "lake.adamant.im", port: nil)
			]
			
			self?.setNodes(nodes: nodes)
		}))
		
		present(alert, animated: true, completion: nil)
	}
	
	func setNodes(nodes: [Node]) {
		guard let section = form.sectionBy(tag: Sections.nodes.tag) else {
			return
		}
		
		section.removeAll()
		
		for node in nodes {
			let row = createRowFor(node: node, tag: generateRandomTag())
			section.append(row)
		}
		
		self.nodes.append(contentsOf: nodes)
	}
}


// MARK: - NodeEditorDelegate
extension NodesListViewController: NodeEditorDelegate {
	func nodeEditorViewController(_ editor: NodeEditorViewController, didFinishEditingWithResult result: NodeEditorResult) {
		switch result {
		case .new(let node):
			guard let section = form.sectionBy(tag: Sections.nodes.tag) else {
				return
			}
			
			nodes.append(node)
			
			let row = createRowFor(node: node, tag: generateRandomTag())
			section <<< row
			
		case .done(let node, let tag):
			guard let row: NodeRow = form.rowBy(tag: tag) else {
				return
			}
			
			if let prevNode = row.value, let index = nodes.index(of: prevNode) {
				nodes.remove(at: index)
			}
			
			nodes.append(node)
			row.value = node
			
		case .cancel:
			break
			
		case .delete(let editorNode, let tag):
			guard let row: NodeRow = form.rowBy(tag: tag), let node = row.value else {
				return
			}
			
			if let index = nodes.index(of: node) {
				nodes.remove(at: index)
			} else if let index = nodes.index(of: editorNode) {
				nodes.remove(at:index)
			}
			
			if let section = form.sectionBy(tag: Sections.nodes.tag), let index = section.index(of: row) {
				section.remove(at: index)
			}
		}
		
		dismiss(animated: true, completion: nil)
	}
}


// MARK: - Tools
extension NodesListViewController {
	private func createRowFor(node: Node, tag: String) -> BaseRow {
		let row = NodeRow() {
			$0.value = node
			$0.tag = tag
			
			let deleteAction = SwipeAction(style: .destructive, title: "Delete") { [weak self] (action, row, completionHandler) in
				if let node = row.baseValue as? Node, let index = self?.nodes.index(of: node) {
					self?.nodes.remove(at: index)
					self?.save()
				}
				completionHandler?(true)
			}
			
			$0.trailingSwipe.actions = [deleteAction]
			
			if #available(iOS 11,*) {
				$0.trailingSwipe.performsFirstActionWithFullSwipe = true
			}
		}.cellUpdate({ (cell, _) in
			if let label = cell.textLabel {
				label.textColor = UIColor.adamantPrimary
			}
			
			cell.accessoryType = .disclosureIndicator
		}).onCellSelection { [weak self] (_, row) in
			guard let node = row.value, let tag = row.tag else {
				return
			}
			
			self?.editNode(node, tag: tag)
		}
		
		return row
	}
	
	private func presentEditor(forNode node: Node?, tag: String?) {
		guard let editor = router.get(scene: AdamantScene.NodesEditor.nodeEditor) as? NodeEditorViewController else {
			fatalError("Failed to get editor")
		}
		
		editor.delegate = self
		editor.node = node
		editor.nodeTag = tag
		
		let navigator = UINavigationController(rootViewController: editor)
		present(navigator, animated: true, completion: nil)
	}
	
	private func generateRandomTag() -> String {
		let capacity = 6
		var nums = [UInt32](reserveCapacity: capacity);
		
		for _ in 0...capacity {
			nums.append(arc4random_uniform(10))
		}
		
		return nums.compactMap { String($0) }.joined()
	}
}
