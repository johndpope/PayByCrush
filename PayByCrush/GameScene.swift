//
//  GameScene.swift
//  PayByCrush
//
//  Created by CHENCHIAN on 7/29/15.
//  Copyright (c) 2015 KICKERCHEN. All rights reserved.
//

import SpriteKit

let TileWidth: CGFloat = 44.0
let TileHeight: CGFloat = 44.0

typealias swipeResponder = (swap: PBCSwap) -> Void

class GameScene: SKScene {
    
    var level: PBCLevel!
    var swipeHandler: swipeResponder?
    
    var gameLayer: SKNode!
    var paymentLayer: SKNode!
    var tilelayer: SKNode!
    
    var swipeFromColumn: Int = NSNotFound
    var swipeFromRow: Int = NSNotFound
    
    var selectedSprite: SKSpriteNode = SKSpriteNode()
    
    let matchSound: SKAction = SKAction.playSoundFileNamed("Sounds/cash register.wav", waitForCompletion: false)
    let fascinating: SKAction = SKAction.playSoundFileNamed("Sounds/Spock_Fascinating.wav", waitForCompletion: false)
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initialize()
    }
    
    override init(size: CGSize) {
        super.init(size: size)
        self.initialize()
    }
    
    func initialize() {
        
        self.anchorPoint = CGPointMake(0.5, 0.5)
        
        // set backgorund
        let background = SKSpriteNode(imageNamed: "Background")
        background.alpha = 0.2
        self.addChild(background)
        
        //
        self.gameLayer = SKNode()
        self.gameLayer.hidden = true
        self.addChild(gameLayer)
        
        let layerPosition = CGPointMake(-TileWidth*CGFloat(NumColumns)/2.0, -TileHeight*CGFloat(NumRows)/2.0)
        
        self.tilelayer = SKNode()
        self.tilelayer.position = layerPosition
        self.gameLayer.addChild(self.tilelayer)
        
        self.paymentLayer = SKNode()
        self.paymentLayer.position = layerPosition
        self.gameLayer.addChild(self.paymentLayer)
    }
    
    override func touchesBegan(touches: Set<NSObject>, withEvent event: UIEvent) {
        /* Called when a touch begins */
        
        for touch in (touches as! Set<UITouch>) {
        
            let location = touch.locationInNode(self.paymentLayer)
            var column: Int = NSNotFound, row: Int = NSNotFound
            if self.convertPoint(location, toColumn: &column, toRow: &row) {
                
                // Check the touch is on a payment rather than on an empty square
                if let payment = self.level.paymentAtColumn(column, row: row) {
                    
                    // Record the column and row where the swipe started
                    // so you can compare them later to find the direction of the swipe
                    self.swipeFromColumn = column
                    self.swipeFromRow = row
                    
                    self.showSelectionIndicatorForPayment(payment)
                }
            }
            
        }
    }
    
    override func touchesMoved(touches: Set<NSObject>, withEvent event: UIEvent) {
        
        // Ignore
        if self.swipeFromColumn == NSNotFound { return }
        
        for touch in (touches as! Set<UITouch>) {
            
            let location = touch.locationInNode(self.paymentLayer)
            
            var column: Int = NSNotFound, row: Int = NSNotFound
            if self.convertPoint(location, toColumn: &column, toRow: &row) {
                
                // Diagonal swipe is not allowed,
                // so we use else if statements, only one of horzDelta or vertDelta will be set.
                var horzDelta: Int = 0, vertDelta: Int = 0
                if column < self.swipeFromColumn {
                    horzDelta = -1
                } else if column > self.swipeFromColumn {
                    horzDelta = 1
                } else if row < self.swipeFromRow {
                    vertDelta = -1
                } else if row > self.swipeFromRow {
                    vertDelta = 1
                }
                
                if horzDelta != 0 || vertDelta != 0 {
                    
                    // try swap
                    self.trySwapHorizontal(horzDelta, vertDelta: vertDelta)
                    
                    // reset
                    self.hideSelectionIndicator()
                    self.swipeFromColumn = NSNotFound
                    self.swipeFromRow = NSNotFound
                }
            }
        }
    }
    
    override func touchesEnded(touches: Set<NSObject>, withEvent event: UIEvent) {
        
        // If the user just taps on the screen rather than swipes,
        // you want to fade out the highlighted sprite, too.
        if let parent = self.selectedSprite.parent {
            if self.swipeFromColumn != NSNotFound {
                self.hideSelectionIndicator()
            }
        }
        
        self.swipeFromColumn = NSNotFound
        self.swipeFromRow = NSNotFound
    }
   
    override func touchesCancelled(touches: Set<NSObject>!, withEvent event: UIEvent!) {
        self.touchesEnded(touches, withEvent: event)
    }
    
    
    // MARK: - Instance Methods
    
    
    func addSpritesForPayments(payments: NSSet) {
        
        self.paymentLayer.removeAllChildren()
        
        for payment in payments {
            
            if let payment = payment as? PBCPayment {
                let sprite = SKSpriteNode(imageNamed: payment.spriteName)
                sprite.position = self.pointForColumn(payment.column, row: payment.row)
            
                self.paymentLayer.addChild(sprite)
                payment.sprite = sprite
                
                payment.sprite?.alpha = 0
                payment.sprite?.xScale = 0.5
                payment.sprite?.yScale = 0.5
                
                payment.sprite?.runAction(SKAction.sequence([
                    SKAction.waitForDuration(0.25, withRange: 0.5),
                    SKAction.group([
                        SKAction.fadeInWithDuration(0.25),
                        SKAction.scaleTo(1.0, duration: 0.25)
                        ])
                    ]))
            }
        }
    }
    
    func addTiles() {
        
        self.tilelayer.removeAllChildren()
        
        for row in 0...NumRows-1 {
            for column in 0...NumColumns-1 {
                
                if self.level.tileAtColumn(column, row: row) == 1 {
                    
                    let tileNode = SKSpriteNode(imageNamed: "Tile")
                    tileNode.position = self.pointForColumn(column, row: row)
                    self.tilelayer.addChild(tileNode)
                }
            }
        }
    }
    
    
    // MARK: - Animation Related Instance Methods
    
    
    func animateSwap(swap: PBCSwap, completion: dispatch_block_t) {
        
        // Put the payment you started with on top.
        swap.paymentA.sprite!.zPosition = 100
        swap.paymentB.sprite!.zPosition = 90
        
        let duration: NSTimeInterval = 0.3
        
        let moveA = SKAction.moveTo(swap.paymentB.sprite!.position, duration: duration)
        moveA.timingMode = .EaseOut
        swap.paymentA.sprite!.runAction(SKAction.sequence([moveA, SKAction.runBlock(completion)]))
        
        let moveB = SKAction.moveTo(swap.paymentA.sprite!.position, duration: duration)
        moveB.timingMode = .EaseOut
        swap.paymentB.sprite!.runAction(moveB)
    }
    
    func animateInvalidSwap(swap: PBCSwap, completion: dispatch_block_t) {
        
        swap.paymentA.sprite!.zPosition = 100
        swap.paymentB.sprite!.zPosition = 90
        
        let duration: NSTimeInterval = 0.2
        
        let moveA = SKAction.moveTo(swap.paymentB.sprite!.position, duration: duration)
        moveA.timingMode = .EaseOut
        let moveB = SKAction.moveTo(swap.paymentA.sprite!.position, duration: duration)
        moveB.timingMode = .EaseOut
        
        swap.paymentA.sprite!.runAction(SKAction.sequence([moveA, moveB, SKAction.runBlock(completion)]))
        swap.paymentB.sprite!.runAction(SKAction.sequence([moveB, moveA]))
    }
    
    
    func animateMatchedPayments(chains: Set<PBCChain>, completion: dispatch_block_t) {
        
        for chain in chains {
            
            self.animateScoreForChain(chain)
            
            for payment in chain.payments {
                
                // The same PBCPayment could be part of two chains (one horizontal and one vertical), but you only want to add one animation to the sprite. This check ensures that you only animate the sprite once.
                if payment.sprite != nil {
                    
                    //
                    let scaleAction = SKAction.scaleTo(0.1, duration: 0.3)
                    scaleAction.timingMode = .EaseOut
                    payment.sprite!.runAction(SKAction.sequence([scaleAction, SKAction.removeFromParent()]))
                    
                    // remove the link between the PBCPayment and its sprite as soon as you’ve added the animation.
                    payment.sprite = nil
                }
            }
        }
        
        // play sound
        self.runAction(self.matchSound)
        
        // only continue with the rest of the game after the animations finish
        self.runAction(SKAction.sequence([
            SKAction.waitForDuration(0.3),
            SKAction.runBlock(completion)
            ]))
    }
    
    
    func animateFallingPayments(columns: Array<Array<PBCPayment>>, completion: dispatch_block_t) {
        
        var longestDuration: Double = 0
        
        for array in columns {
            
            (array as NSArray).enumerateObjectsUsingBlock({(object, index, stop) in
                
                let payment = object as! PBCPayment
                let newPosition = self.pointForColumn(payment.column, row: payment.row)
                
                // The higher up the payment is, the bigger the delay on the animation. That looks more dynamic than dropping all the payments at the same time. This calculation works because fillHoles guarantees that lower payments are first in the array.
                let delay: Double = 0.1 * NSTimeInterval(index)
                
                // Falling speed is 10 tiles/sec = 0.1 sec/tile
                let duration: Double = (Double(payment.sprite!.position.y - newPosition.y) / Double(TileHeight)) * 0.1
                
                // Calculate the longest duration to wait for animation to finish
                longestDuration = max(longestDuration, duration + delay)
                
                // Perform animations
                let moveAction = SKAction.moveTo(newPosition, duration: duration)
                moveAction.timingMode = .EaseOut
                payment.sprite!.runAction(SKAction.sequence([
                    SKAction.waitForDuration(delay),
                    moveAction
                    ]))
            })
        }
        
        self.runAction(SKAction.sequence([
            SKAction.waitForDuration(longestDuration),
            SKAction.runBlock(completion)
            ]))
    }
    
    
    func animateNewPayments(columns: Array<Array<PBCPayment>>, completion: dispatch_block_t) {
        
        var longestDuration: Double = 0
        
        for array in columns {
            
            var startRow = array.first!.row + 1
            
            (array as NSArray).enumerateObjectsUsingBlock({(object, index, stop) in
                
                let payment = object as! PBCPayment
                let sprite = SKSpriteNode(imageNamed: payment.spriteName)
                sprite.position = self.pointForColumn(payment.column, row: startRow)
                self.paymentLayer.addChild(sprite)
                payment.sprite = sprite
                
                // The higher the payment, the longer you make the delay, so the payments appear to fall after one another.
                let delay: Double = 0.2 * Double(array.count - index - 1)
                let duration: Double = Double(startRow - payment.row) * 0.1
                longestDuration = max(longestDuration, duration + delay)
                
                // Perform animation
                let newPosition = self.pointForColumn(payment.column, row: payment.row)
                let moveAction = SKAction.moveTo(newPosition, duration: duration)
                moveAction.timingMode = .EaseOut
                payment.sprite!.alpha = 0 // for fade in 
                payment.sprite!.runAction(SKAction.sequence([
                    SKAction.waitForDuration(delay),
                    SKAction.group([
                        moveAction,
                        SKAction.fadeInWithDuration(0.05)
                        ])
                    ]))
            })
        }
        
        self.runAction(SKAction.sequence([
            SKAction.waitForDuration(longestDuration),
            SKAction.runBlock(completion)
            ]))
    }
    
    func animateScoreForChain(chain: PBCChain) {
        
        // Figure out where the midpoint of the chain is
        if let firstPayment = chain.payments.first {
            if let lastPayment = chain.payments.last {
                
                let firstPos = self.pointForColumn(firstPayment.column, row: firstPayment.row)
                let lastPos = self.pointForColumn(lastPayment.column, row: lastPayment.row)
                
                let centerPoint = CGPointMake( (firstPos.x + lastPos.x)/2, (firstPos.y + lastPos.y)/2 - 8 )
                
        
                // Add a label for the score that slowly floats up
                let scoreLabel = SKLabelNode(fontNamed: "AmericanTypewriter-Bold")
                scoreLabel.fontSize = 17
                scoreLabel.text = "$" + chain.score.stringWithCommaSeparator
                scoreLabel.position = centerPoint
                scoreLabel.zPosition = 300
                self.paymentLayer.addChild(scoreLabel)
                
                let moveAction = SKAction.moveBy(CGVectorMake(0, 6), duration: 0.7)
                moveAction.timingMode = .EaseOut
                scoreLabel.runAction(SKAction.sequence([
                    SKAction.group([
                        moveAction,
                        SKAction.colorizeWithColorBlendFactor(0.5, duration: 0.7)]),
                    SKAction.removeFromParent()]))
            }
        }
        
    }
    
    
    func animateGameOver() {
        
        let action = SKAction.moveBy(CGVectorMake(0, -self.size.height), duration: 0.3)
        action.timingMode = .EaseIn
        self.gameLayer.runAction(action)
    }
    
    
    func animateBeginGame() {
        
        self.gameLayer.hidden = false
        
        self.gameLayer.position = CGPointMake(0, self.size.height)
        let action = SKAction.moveBy(CGVectorMake(0, -self.size.height), duration: 0.3)
        action.timingMode = .EaseOut
        self.gameLayer.runAction(action)
    }
        
    // MARK: - Helper Functions
    
    
    func preloadResources() {
    
        // When using SKLabelNode, Sprite Kit needs to load the font and convert it to a texture. That only happens once, but it does create a small delay, so it’s smart to pre-load this font before the game starts in earnest.
        SKLabelNode(fontNamed: "AmericanTypewriter-Bold")
    }
    
    func pointForColumn(column: Int, row: Int) -> CGPoint {
        return CGPointMake(CGFloat(column)*TileWidth + TileWidth/2, CGFloat(row)*TileHeight + TileHeight/2)
    }
    
    func convertPoint(point: CGPoint, inout toColumn column: Int, inout toRow row: Int) -> Bool {
        
        // Is this a valid location within the payments layer? If yes,
        // calculate the corresponding row and column numbers.
        if (point.x >= 0 && point.x < CGFloat(NumColumns)*TileWidth &&
            point.y >= 0 && point.y < CGFloat(NumRows)*TileHeight) {
                
                column = Int(point.x / TileWidth)
                row = Int(point.y / TileHeight)
                return true
        } else {
            column = NSNotFound // invalid location
            row = NSNotFound
            return false
        }
    }
    
    func showSelectionIndicatorForPayment(payment: PBCPayment) {
        
        if let parent = self.selectedSprite.parent {
            self.selectedSprite.removeFromParent()
        }
        
        let texture = SKTexture(imageNamed: payment.hightlightedSpriteName)
        
        self.selectedSprite.size = texture.size()
        self.selectedSprite.runAction(SKAction.setTexture(texture))
        
        payment.sprite!.addChild(self.selectedSprite)
        self.selectedSprite.alpha = 1.0
    }
    
    func hideSelectionIndicator() {
        self.selectedSprite.runAction(SKAction.sequence([
            SKAction.fadeOutWithDuration(0.3),
            SKAction.removeFromParent()
            ]))
    }
    
    func trySwapHorizontal(horzDelta: Int, vertDelta: Int) {
        
        var toColumn = self.swipeFromColumn + horzDelta
        var toRow = self.swipeFromRow + vertDelta
        
        if toColumn < 0 || toColumn > NumColumns { return }
        if toRow < 0 || toRow > NumRows { return }
        
        if let toPayment = self.level.paymentAtColumn(toColumn, row: toRow) {
            
            if let fromPayment = self.level.paymentAtColumn(self.swipeFromColumn, row: self.swipeFromRow) {
                
                    let swap = PBCSwap()
                    swap.paymentA = fromPayment
                    swap.paymentB = toPayment
                    
                    self.swipeHandler?(swap: swap)
            }
        }
    }
}
