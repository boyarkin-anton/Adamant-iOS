//
//  AddressBookService.swift
//  Adamant
//
//  Created by Anton Boyarkin on 24/07/2018.
//  Copyright © 2018 Adamant. All rights reserved.
//

import Foundation

protocol AddressBookService: class {
    
    var addressBook: [String:String] { get }
    
    func getAddressBook(completion: @escaping (ApiServiceResult<[String:String]>) -> Void)

}
