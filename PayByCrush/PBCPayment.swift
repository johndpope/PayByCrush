//
//  PBCPayment.swift
//  PayByCrush
//
//  Created by CHENCHIAN on 7/29/15.
//  Copyright (c) 2015 KICKERCHEN. All rights reserved.
//

import UIKit
import SpriteKit

let NumPaymentTypes = 6;

class PBCPayment: NSObject {
    
    var paymentType: Int
    var sprite: SKSpriteNode?
    var column: Int
    var row: Int
    
    struct StaticStrings {
        static let spriteNames = [
            "AE",
            "BC",
            "JCB",
            "MASTER",
            "PP",
            "VISA",
        ]
        static let highlightedSpriteNames = [
            "AE-Highlight",
            "BC-Highlight",
            "JCB-Highlight",
            "MASTER-Highlight",
            "PP-Highlight",
            "VISA-Highlight",
        ]
    }
    
    var spriteName: String {
        get {
            return StaticStrings.spriteNames[paymentType - 1]
        }
    }
    
    var hightlightedSpriteName: String {
        get {
            return StaticStrings.highlightedSpriteNames[paymentType - 1]
        }
    }
    
    override var description: String {
        get {
            return NSString(format: "type:%ld square:(%ld, %ld)", paymentType, column, row) as! String
        }
    }
    
    override init() {
        paymentType = NSNotFound
        column = NSNotFound
        row = NSNotFound
    }
}
