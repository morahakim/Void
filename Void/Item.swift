//
//  Item.swift
//  Void
//
//  Created by Mora Hakim on 17/11/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
