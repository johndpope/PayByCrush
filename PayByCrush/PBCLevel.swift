//
//  PBCLevel.swift
//  PayByCrush
//
//  Created by CHENCHIAN on 7/29/15.
//  Copyright (c) 2015 KICKERCHEN. All rights reserved.
//

import UIKit

let NumColumns = 7
let NumRows = 7
let ScoreBase: UInt = 60000

class PBCLevel: NSObject {
    
    var payments: [[PBCPayment?]] = Array(count: NumColumns, repeatedValue: Array(count: NumRows, repeatedValue: nil))
    
    var tiles: [[Int]] = Array(count: NumColumns, repeatedValue: Array(count: NumRows, repeatedValue: 0))
    
    var possibleSwaps = NSSet()
    
    var targetScore: UInt = 0
    
    var maximumMoves: UInt = 0
    
    var scoreMultiplier: UInt = 1
    
    override init() {
        super.init()
    }
    
    convenience init(filename: String) {
        self.init()
        if let dictionary = self.loadJSON(filename) {
            if let tiles = dictionary["tiles"] as? NSArray {
            
                // Loop through the rows
                tiles.enumerateObjectsUsingBlock({(array, row, stop) in
                    
                    // Loop through the columns
                    (array as! NSArray).enumerateObjectsUsingBlock({(value, column, stop) in
                    
                        // Note: In Sprite Kit (0,0) is at the bottom of the screen,
                        // so we need to read this file upside down.
                        let tileRow = NumRows - row - 1
                        
                        // If the value is 1, create a tile object.
                        if (value as! NSNumber).integerValue == 1 {
                            self.tiles[column][tileRow] = 1
                        }
                        
                    })
                })
            }
            
            if let targetScore = dictionary["targetScore"] as? NSNumber {
                self.targetScore = targetScore.unsignedLongValue
            }

            if let moves = dictionary["moves"] as? NSNumber {
                self.maximumMoves = moves.unsignedLongValue
            }
        }
    }
    
    func paymentAtColumn(column: Int, row: Int) -> PBCPayment? {
        return payments[column][row]
    }
    
    func tileAtColumn(column: Int, row: Int) -> Int {
        return tiles[column][row]
    }
    
    
    func detectPossibleSwaps() {
        
        var set = NSMutableSet()
        
        for row in 0...NumRows-1 {
            for column in 0...NumColumns-1 {

                if let payment = payments[column][row] {
                    
                    // detect possible swaps of the payment
                    
                    // Is it possible to swap this payment with the one on the right?
                    if column < NumColumns - 1 {
                        
                        if let other = payments[column + 1][row] {
                            
                            // swap them 
                            payments[column][row] = other
                            payments[column + 1][row] = payment
                            
                            if self.hasChainAtColumn(column, row: row, paymentType: other.paymentType) || self.hasChainAtColumn(column + 1, row: row, paymentType: payment.paymentType) {
                                
                                let swap = PBCSwap()
                                swap.paymentA = payment
                                swap.paymentB = other
                                set.addObject(swap)
                            }
                            
                            // swap back
                            self.payments[column][row] = payment
                            self.payments[column + 1][row] = other
                        }
                    }
                    
                    if row < NumRows - 1 {
                        
                        if let other = payments[column][row + 1] {
                            
                            // swap them
                            payments[column][row] = other
                            payments[column][row + 1] = payment
                            
                            if self.hasChainAtColumn(column, row: row, paymentType: other.paymentType) || self.hasChainAtColumn(column, row: row + 1, paymentType: payment.paymentType) {
                                
                                let swap = PBCSwap()
                                swap.paymentA = payment
                                swap.paymentB = other
                                set.addObject(swap)
                            }
                            
                            // swap back
                            self.payments[column][row] = payment
                            self.payments[column][row + 1] = other
                        }
                    }
                    
                }
                    

            }
        }
        
        self.possibleSwaps = set
    }
    
    func shuffle() -> NSSet {
        var set = NSSet()
        
        do {
        
            set = createInitialPayments()
            
            detectPossibleSwaps()
            
        } while (possibleSwaps.count == 0)
        
        return set
    }
    
    
    func isPossibleSwap(swap: PBCSwap) -> Bool {
        return self.possibleSwaps.containsObject(swap)
    }
    
    
    func performSwap(swap: PBCSwap) {
        
        let columnA = swap.paymentA.column
        let rowA = swap.paymentA.row
        let columnB = swap.paymentB.column
        let rowB = swap.paymentB.row
        
        payments[columnA][rowA] = swap.paymentB
        swap.paymentB.column = columnA
        swap.paymentB.row = rowA
        
        payments[columnB][rowB] = swap.paymentA
        swap.paymentA.column = columnB
        swap.paymentA.row = rowB
    }
    
    
    func removeMatches() -> Set<PBCChain> {
        
        let horizontalMatches = self.detectHorizontalMatches()
        let verticalMatches = self.detectVerticalMatches()
        
        self.removePayments(horizontalMatches)
        self.removePayments(verticalMatches)
        
        self.calculateScores(horizontalMatches)
        self.calculateScores(verticalMatches)
        
        return horizontalMatches.union(verticalMatches)
    }
    
    
    func fillHoles() -> Array<Array<PBCPayment>> {
        
        var columns = Array<Array<PBCPayment>>()
        
        for column in 0...NumColumns-1 {
            
            var array = Array<PBCPayment>()
            
            for row in 0...NumRows-1 {
                
                // if the position has a tile but no payment
                if self.tiles[column][row] == 1 && self.payments[column][row] == nil {
                    
                    // look up the first tile with valid payment
                    for (var lookup = row + 1; lookup < NumRows; lookup++) {
                        
                        if let payment = self.payments[column][lookup] {
                            
                            // swap and update row number
                            self.payments[column][lookup] = nil
                            self.payments[column][row] = payment
                            payment.row = row
                            
                            array.append(payment)
                            
                            // go to next row and repeat
                            break
                        }
                    }
                    
                }
            }
            
            if array.count > 0 {
                columns.append(array)
            }
        }
        
        return columns
    }
    
    
    func topUpPayments() -> Array<Array<PBCPayment>> {
        
        var columns = Array<Array<PBCPayment>>()
        var paymentType = 0
        
        for column in 0...NumColumns-1 {
            
            var array = Array<PBCPayment>()
            
            // from top to bottom
            for (var row = NumRows - 1; row >= 0 && self.payments[column][row] == nil; row--) {
                
                if self.tiles[column][row] == 1 {
                    
                    var newPaymentType = 0
                    do {
                        newPaymentType = Int(arc4random_uniform(UInt32(NumPaymentTypes))) + 1
                    } while (newPaymentType == paymentType)
                    paymentType = newPaymentType
                    
                    let payment = self.createPaymentAtColumn(column, row: row, type: paymentType)
                    
                    array.append(payment) // append order: top to bottom
                }                
            }
            
            if array.count > 0 {
                columns.append(array)
            }
        }
        
        return columns
    }
    
    
    // MARK: - Helper functions
    
    func createPaymentAtColumn(column: Int, row: Int, type: Int) -> PBCPayment {
        let payment = PBCPayment()
        payment.paymentType = type
        payment.column = column
        payment.row = row
        payments[column][row] = payment
        
        return payment
    }
    
    func createInitialPayments() -> NSSet {
        
        var set = NSMutableSet()
        for row in 0...NumRows-1 {
            
            for column in 0...NumColumns-1 {
                
                if tiles[column][row] == 1 {
                    
                    var paymentType: Int
                    
                    // If the new random number causes a chain of three—because there are already two payments of this type to the left or below—then the method tries again.
                    do {
                        
                        paymentType = Int(arc4random_uniform(UInt32(NumPaymentTypes)) + 1)
                        
                    } while (self.isValidPaymentType(column, row: row, paymentType: paymentType) == false)
                    
                    let payment = createPaymentAtColumn(column, row: row, type: paymentType)
                    set.addObject(payment)
                }
            }
        }
        return set
    }
    
    func isValidPaymentType(column: Int, row: Int, paymentType: Int) -> Bool {
        
        if column >= 2 {
            if let paymentNext = self.payments[column - 1][row] {
                if paymentNext.paymentType == paymentType {
                    if let paymentNextNext = self.payments[column - 2][row] {
                        if paymentNextNext.paymentType == paymentType {
                            return false
                        }
                    }
                }
            }
        }
        
        if row >= 2 {
            if let paymentNext = self.payments[column][row - 1] {
                if paymentNext.paymentType == paymentType {
                    if let paymentNextNext = self.payments[column][row - 2] {
                        if paymentNextNext.paymentType == paymentType {
                            return false
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    func loadJSON(filename: String) -> NSDictionary? {
        
        if let path: String = NSBundle.mainBundle().pathForResource(filename, ofType: "json") {
        
            var error: NSError?
            if let data = NSData(contentsOfFile: path, options: nil, error: &error) {
                
                if let dictionary = NSJSONSerialization.JSONObjectWithData(data, options: nil, error: &error) as? NSDictionary {
                    return dictionary
                    
                } else {
                    
                    println("Level file \(filename) is not valid JSON: \(error)")
                    return nil
                }
                
            } else {
                
                println("Could not load level file: \(filename)")
                return nil
            }
            
        } else {
            
            println("Could not find level file: \(filename)")
            return nil
        }
        
    }
    
    func hasChainAtColumn(column: Int, row: Int, paymentType: Int) -> Bool {
        
        var horzLength = 1;
        for (var i = column - 1; i >= 0; i--) {
            if let other = self.payments[i][row] {
                if other.paymentType == paymentType {
                    horzLength++;
                } else {
                    break;
                }
            }
        }
        for (var i = column + 1; i < NumColumns; i++) {
            if let other = self.payments[i][row] {
                if other.paymentType == paymentType {
                    horzLength++;
                } else {
                    break;
                }
            }
        }
        if horzLength >= 3 {
            return true
        }
        
        var vertLength = 1
        for (var i = row - 1; i >= 0; i--) {
            if let other = self.payments[column][i] {
                if other.paymentType == paymentType {
                    vertLength++
                } else {
                    break
                }
            }
        }
        for (var i = row + 1; i < NumRows; i++) {
            if let other = self.payments[column][i] {
                if other.paymentType == paymentType {
                    vertLength++
                } else {
                    break
                }
            }
        }
        return (vertLength >= 3) ? true : false
    }
    
    func detectHorizontalMatches() -> Set<PBCChain> {
        
        var set = Set<PBCChain>()
        
        for row in 0...NumRows-1 {
            
            var column = 0
            while (column < NumColumns - 2) {
                
                if let payment = self.payments[column][row] {
                    let matchType = payment.paymentType
                    
                    if self.payments[column + 1][row]?.paymentType == matchType &&
                        self.payments[column + 2][row]?.paymentType == matchType {
                            
                            let chain = PBCChain()
                            chain.chainType = .Horizontal
                            do {
                                if let payment = self.payments[column][row] {
                                    chain.addPayment(payment)
                                }
                                column++
                            } while (column < NumColumns && self.payments[column][row]?.paymentType == matchType)
                            
                            set.insert(chain)
                            continue // column is already at the next index with different payment type
                    }
                }
                
                // no payment or no match at (column, row)
                column++
            }
        }
        
        return set
    }
    
    func detectVerticalMatches() -> Set<PBCChain> {
        
        var set = Set<PBCChain>()
        
        for column in 0...NumColumns-1 {
            
            var row = 0
            while (row < NumRows - 2) {
                
                if let payment = self.payments[column][row] {
                    let matchType = payment.paymentType
                    
                    if self.payments[column][row + 1]?.paymentType == matchType && self.payments[column][row + 2]?.paymentType == matchType {
                     
                        let chain = PBCChain()
                        chain.chainType = .Vertical
                    
                        do {
                            if let payment = self.payments[column][row] {
                                chain.addPayment(payment)
                            }
                            row++
                    
                        } while (row < NumRows && self.payments[column][row]?.paymentType == matchType)
                        
                        set.insert(chain)
                        continue // row is already at the next index with different payment type
                    }
                }
                
                // no payment or no match at (column, row)
                row++
            }
        }
        
        return set
    }
    
    func removePayments(chains: Set<PBCChain>) {
        
        for chain in chains {
            for payment in chain.payments {
                payments[payment.column][payment.row] = nil
            }
        }
    }
    
    func calculateScores(chains: Set<PBCChain>) {
        
        for chain in chains {
            
            chain.score = 0
            
            if chain.payments.count > 2 {
                chain.score = ScoreBase * (UInt(chain.payments.count) - 2) * self.scoreMultiplier
                self.scoreMultiplier++
            }            
        }
    }
    
    func resetScoreMultiplier() {
        self.scoreMultiplier = 1
    }
}
