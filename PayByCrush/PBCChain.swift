//
//  PBCChain.swift
//  PayByCrush
//
//  Created by CHENCHIAN on 7/29/15.
//  Copyright (c) 2015 KICKERCHEN. All rights reserved.
//

import UIKit

enum ChainType {
    case Horizontal, Vertical
}

class PBCChain: NSObject {

    lazy var payments = Array<PBCPayment>()
    var chainType: ChainType!
    var score: UInt = 0
    
    func addPayment(payment: PBCPayment) {
        self.payments.append(payment)
    }
    
    override var description: String {
        get {
            return "type:\(self.chainType) payments:\(self.payments)"
        }
    }
}
