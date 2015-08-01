//
//  PBCSwap.swift
//  PayByCrush
//
//  Created by CHENCHIAN on 7/29/15.
//  Copyright (c) 2015 KICKERCHEN. All rights reserved.
//

import UIKit

class PBCSwap: NSObject {
    
    var paymentA: PBCPayment!
    var paymentB: PBCPayment!
    
    override var description: String {
        get {
            return NSString(format: "%@ swap %@ with %@", super.description, self.paymentA, self.paymentB) as! String
        }
    }
    
    override var hash: Int {
        get {
            return self.paymentA.hash ^ self.paymentB.hash
        }
    }
    
    override func isEqual(object: AnyObject?) -> Bool {
        
        if object?.isKindOfClass(PBCSwap) == false {
            return false
        }
        
        let other = object as! PBCSwap
        return (other.paymentA == self.paymentA && other.paymentB == self.paymentB) || (other.paymentA == self.paymentB && other.paymentB == self.paymentA)
    }
}
