//
//  GameViewController.swift
//  PayByCrush
//
//  Created by CHENCHIAN on 7/29/15.
//  Copyright (c) 2015 KICKERCHEN. All rights reserved.
//

import UIKit
import SpriteKit

extension SKNode {
    class func unarchiveFromFile(file : String) -> SKNode? {
        if let path = NSBundle.mainBundle().pathForResource(file, ofType: "sks") {
            var sceneData = NSData(contentsOfFile: path, options: .DataReadingMappedIfSafe, error: nil)!
            var archiver = NSKeyedUnarchiver(forReadingWithData: sceneData)
            
            archiver.setClass(self.classForKeyedUnarchiver(), forClassName: "SKScene")
            let scene = archiver.decodeObjectForKey(NSKeyedArchiveRootObjectKey) as! GameScene
            archiver.finishDecoding()
            return scene
        } else {
            return nil
        }
    }
}

class GameViewController: UIViewController {

    var scene: GameScene!
    var level: PBCLevel!
    
    var movesLeft: UInt = 0
    var score: UInt = 0
    
    @IBOutlet weak var targetNameLabel: UILabel!
    @IBOutlet weak var movesNameLabel: UILabel!
    @IBOutlet weak var scoreNameLabel: UILabel!
    
    @IBOutlet weak var targetLabel: UILabel!
    @IBOutlet weak var movesLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let scene = GameScene.unarchiveFromFile("GameScene") as? GameScene {
            // Configure the view.
            let skView = self.view as! SKView
            skView.multipleTouchEnabled = false
            
            scene.scaleMode = .AspectFill
            scene.size = skView.bounds.size
            self.scene = scene
            
            self.level = PBCLevel(filename: "Levels/Level_0")
            self.scene.level = self.level
            self.scene.addTiles()
            
            let closure: swipeResponder = {(swap: PBCSwap) in
                
                self.view.userInteractionEnabled = false
             
                if self.level.isPossibleSwap(swap) {
                    
                    self.level.performSwap(swap)
                    
                    // animation for swap
                    self.scene.animateSwap(swap, completion: {
                        
                        // after swaping, handle matches
                        self.handleMatches()
                    })
                    
                } else {
                    
                    // animation for invalid swap
                    self.scene.animateInvalidSwap(swap, completion: {
                        self.view.userInteractionEnabled = true
                    })
                }
            }
            
            self.scene.swipeHandler = closure
            
            skView.presentScene(scene)
            
            self.beginGame()
        }
    }

    override func shouldAutorotate() -> Bool {
        return true
    }

    override func supportedInterfaceOrientations() -> Int {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            return Int(UIInterfaceOrientationMask.AllButUpsideDown.rawValue)
        } else {
            return Int(UIInterfaceOrientationMask.All.rawValue)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    func updateLabels() {
        self.targetLabel.text = "\(self.level.targetScore)"
        self.movesLabel.text = "\(self.movesLeft)"
        self.scoreLabel.text = "\(self.score)"
    }

    
    // MARK: - Game related functions
    
    
    func beginGame() {
        
        self.movesLeft = self.level.maximumMoves
        self.score = 0
        
        self.updateLabels()
        
        self.shuffle()
    }
    
    func shuffle() {
        let payments = self.level.shuffle()
        self.scene.addSpritesForPayments(payments)
    }
    
    func beginNextTurn() {
        self.level.detectPossibleSwaps() // update for the new turn
        self.view.userInteractionEnabled = true
    }
    
    func handleMatches() {
        
        // remove matches
        let matches = self.level.removeMatches()
        
        // stop condition of recursion
        if matches.count == 0 {
            self.beginNextTurn()
            return
        }
        
        // animate matches => falling payments above => add new payment
        self.scene.animateMatchedPayments(matches, completion: {
            
            // Collect scores stored from removed chains
            for chain in matches {
                self.score += chain.score
            }
            self.updateLabels()
            
            // Get falling arrays and animate
            let columns = self.level.fillHoles()
            self.scene.animateFallingPayments(columns, completion: {
                
                // Get topup arrays and animate
                let columns = self.level.topUpPayments()
                self.scene.animateNewPayments(columns, completion: {
                    
                    // Recursively check if there's any new match
                    self.handleMatches()
                })
            })
        })
    }
}
