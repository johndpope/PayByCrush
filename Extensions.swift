//
//  Extensions.swift
//  PayByCrush
//
//  Created by CHENCHIAN on 8/2/15.
//  Copyright (c) 2015 KICKERCHEN. All rights reserved.
//

import Foundation

extension UInt {
    
    var stringWithCommaSeparator: String {
        let nf = NSNumberFormatter()
        nf.groupingSeparator = ","
        nf.numberStyle = .DecimalStyle
        return nf.stringFromNumber(self)!
    }
    
}
