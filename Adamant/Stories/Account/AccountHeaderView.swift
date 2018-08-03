//
//  AccountHeaderView.swift
//  Adamant
//
//  Created by Anokhov Pavel on 29.06.2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import UIKit

protocol AccountHeaderViewDelegate: class {
    func addressLabelTapped(from: UIView)
}

class AccountHeaderView: UIView {
	
	// MARK: - IBOutlets
	@IBOutlet weak var avatarImageView: UIImageView!
	@IBOutlet weak var walletCollectionView: UICollectionView!
	@IBOutlet weak var addressButton: UIButton!
	@IBOutlet weak var backgroundTopConstraint: NSLayoutConstraint!
	
	weak var delegate: AccountHeaderViewDelegate?
	
	@IBAction func addressButtonTapped(_ sender: UIButton) {
        delegate?.addressLabelTapped(from: sender)
	}
}
