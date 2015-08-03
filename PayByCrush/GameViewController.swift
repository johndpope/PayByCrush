//
//  GameViewController.swift
//  PayByCrush
//
//  Created by CHENCHIAN on 7/29/15.
//  Copyright (c) 2015 KICKERCHEN. All rights reserved.
//

import UIKit
import SpriteKit
import AVFoundation


let ImagePathGameOver = "Bankrupt"
let ImagePathPass = "Paid in full"

let NumLevels: UInt = 5

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
    
    var currentLevel: UInt = 0
    var movesLeft: UInt = 0
    var score: UInt = 0
    
    var tapGestureRecognizer: UITapGestureRecognizer? = nil
    
    var backgroundMusic: AVAudioPlayer? = nil
    
    @IBOutlet weak var targetNameLabel: UILabel!
    @IBOutlet weak var movesNameLabel: UILabel!
    @IBOutlet weak var scoreNameLabel: UILabel!
    
    @IBOutlet weak var targetLabel: UILabel!
    @IBOutlet weak var movesLabel: UILabel!
    @IBOutlet weak var scoreLabel: UILabel!

    @IBOutlet weak var gameOverPanel: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let scene = GameScene.unarchiveFromFile("GameScene") as? GameScene {
            // Configure the view.
            let skView = self.view as! SKView
            skView.multipleTouchEnabled = false
            
            scene.scaleMode = .AspectFill
            scene.size = skView.bounds.size
            self.scene = scene
            
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
                        self.decreaseMoves()
                    })
                }
            }
            
            self.scene.swipeHandler = closure
            
            self.gameOverPanel.hidden = true
            skView.presentScene(scene)
            
            // BGM
            let url = NSBundle.mainBundle().URLForResource("JewelBeat - Easy Groove", withExtension: "wav", subdirectory: "Sounds")
            self.backgroundMusic = AVAudioPlayer(contentsOfURL: url, error: nil)
            self.backgroundMusic?.numberOfLoops = -1
            self.backgroundMusic?.volume = 0.3
            self.backgroundMusic?.play()
            
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
        self.targetLabel.text = "$" + self.level.targetScore.stringWithCommaSeparator
        self.movesLabel.text = "\(self.movesLeft)"
        self.scoreLabel.text = "$" + self.score.stringWithCommaSeparator
    }
    
    func showGameOver() {
        
        self.scene.animateGameOver()
        
        self.gameOverPanel.alpha = 0.0
        self.gameOverPanel.hidden = false
        self.scene.userInteractionEnabled = false
        
        UIView.animateWithDuration(0.5, animations: {
            self.gameOverPanel.alpha = 1
        })
        
        self.tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "hideGameOver")
        self.view.addGestureRecognizer(self.tapGestureRecognizer!)
    }
    
    func hideGameOver() {
        
        self.view.removeGestureRecognizer(self.tapGestureRecognizer!)
        self.tapGestureRecognizer = nil
        
        self.gameOverPanel.hidden = true
        self.scene.userInteractionEnabled = true
        
        self.beginGame()
    }
    
    
    // MARK: - Game related functions
    
    
    func beginGame() {
        
        self.level = PBCLevel(filename: "Levels/Level_\(self.currentLevel)")
        self.scene.level = self.level
        self.scene.addTiles()
        
        self.movesLeft = self.level.maximumMoves
        self.score = 0
        
        self.updateLabels()
        
        self.level.resetScoreMultiplier()
        
        self.scene.animateBeginGame()
        
        self.shuffle()
    }
    
    func shuffle() {
        let payments = self.level.shuffle()
        self.scene.addSpritesForPayments(payments)
    }
    
    func beginNextTurn() {
        
        self.decreaseMoves()
        
        self.level.detectPossibleSwaps() // update for the new turn
        
        // no possible swap, shuffle
        if self.level.possibleSwaps.count == 0 {
            self.shuffle()
        }
        
        self.level.resetScoreMultiplier()
        
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
    
    func decreaseMoves() {
        
        self.movesLeft--
        self.updateLabels()
        
        if self.movesLeft == 0 {
            
            self.gameOverPanel.image = UIImage(named: ImagePathGameOver)
            self.showGameOver()
            
        } else if self.score >= self.level.targetScore {
            
            self.currentLevel = (self.currentLevel == NumLevels - 1) ? 0 : self.currentLevel + 1
            self.gameOverPanel.image = UIImage(named: ImagePathPass)
            self.showGameOver()
            
        }
    }
}
