//
//  ViewController.swift
//  ARPokerDice
//
//  Created by Thibaut Coutard on 15/05/2020.
//  Copyright © 2020 Thibaut Coutard. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {
  
  // MARK: - Properties
  
  var gameState: GameState = .detectSurface
  var statusMessage: String = ""
  var trackingStatus: String = ""
  var focusPoint:CGPoint!
  var diceNodes: [SCNNode] = []
  var diceCount: Int = 5
  var diceStyle: Int = 0
    var diceOffset: [SCNVector3] = [SCNVector3(0.0,0.0,0.0),
                                  SCNVector3(-0.05, 0.00, 0.0),
                                  SCNVector3(0.05, 0.00, 0.0),
                                  SCNVector3(-0.05, 0.05, 0.02),
                                  SCNVector3(0.05, 0.05, 0.02)]
  var focusNode: SCNNode!
  
  enum GameState: Int16 {
    case detectSurface
    case pointToSurface
    case swipeToPlay
  }
  
  // MARK: - Outlets
  
  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet weak var statusLabel: UILabel!
  @IBOutlet weak var styleButton: UIButton!
  @IBOutlet weak var resetButton: UIButton!
  @IBOutlet weak var startButton: UIButton!
  
  // MARK: - View Management
  
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    initSceneView()
    initCoachingOverlayView()
    initScene()
    initARSession()
    loadModels()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    print("*** ViewWillAppear()")
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    sceneView.session.pause()
    print("*** ViewWillDisappear()")
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    print("*** DidReceiveMemoryWarning()")
  }
  
  // MARK: - Initializations
  
  private func initSceneView() {
    sceneView.delegate = self
    sceneView.showsStatistics = true
    focusPoint = CGPoint(x: view.center.x,
                         y: view.center.y + view.center.y * 0.25)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(ViewController.orientationChanged),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
  }
  
  private func initScene() {
    let scene = SCNScene()
    scene.isPaused = false
    sceneView.scene = scene
    sceneView.debugOptions = [
      .showWorldOrigin,
      .showFeaturePoints,
      .showBoundingBoxes,
      .showWireframe
    ]
    scene.physicsWorld.timeStep = 1.0 / 60.0
  }
  
  private func initARSession() {
    guard ARWorldTrackingConfiguration.isSupported else { print("*** ARConfig: AR World Tracking Not Supported")
      return
    }
    let config = ARWorldTrackingConfiguration()
    config.worldAlignment = .gravity
    config.providesAudioData = false
    config.environmentTexturing = .automatic
    config.planeDetection = .horizontal
    config.isLightEstimationEnabled = true
    sceneView.session.run(config)
  }

  func initCoachingOverlayView() {
    let coachingOverlay = ARCoachingOverlayView()
    coachingOverlay.session = self.sceneView.session
    coachingOverlay.activatesAutomatically = true
    coachingOverlay.goal = .horizontalPlane
    coachingOverlay.delegate = self
    self.sceneView.addSubview(coachingOverlay)

    // 1
    coachingOverlay.translatesAutoresizingMaskIntoConstraints =
    false
    // 2
    NSLayoutConstraint.activate([
      NSLayoutConstraint(item: coachingOverlay,
                         attribute: .top,
                         relatedBy: .equal,
                         toItem: self.view,
                         attribute: .top,
                         multiplier: 1,
                         constant: 0),
      NSLayoutConstraint(item: coachingOverlay,
                         attribute: .bottom,
                         relatedBy: .equal,
                         toItem: self.view,
                         attribute: .bottom,
                         multiplier: 1,
                         constant: 0),
      NSLayoutConstraint(item: coachingOverlay,
                         attribute: .leading,
                         relatedBy: .equal,
                         toItem: self.view,
                         attribute: .leading,
                         multiplier: 1,
                         constant: 0),
      NSLayoutConstraint(item: coachingOverlay,
                         attribute: .trailing,
                         relatedBy: .equal,
                         toItem: self.view,
                         attribute: .trailing,
                         multiplier: 1,
                         constant: 0)
    ])
  }
  
  // MARK: - Actions

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)

    DispatchQueue.main.async {
      if let location = touches.first?.location(in: self.sceneView) {
        if let hit = self.sceneView.hitTest(location, options: nil).first {
          if hit.node.name == "dice" {
            hit.node.removeFromParentNode()
            self.diceCount += 1
          }
        }
      }
    }
  }
  
  @IBAction func styleButtonPressed(_ sender: Any) {
    diceStyle = diceStyle >= 4 ? 0 : diceStyle + 1
  }
  
  @IBAction func resetButtonPressed(_ sender: Any) {
    resetGame()
  }
  
  @IBAction func startButtonPressed(_ sender: Any) {
    startGame()
  }

  @IBAction func swipeUpGestureHandler(_ sender: Any) {
    guard gameState == .swipeToPlay else { return }
    guard let frame = sceneView.session.currentFrame else { return }
    for count in 0..<diceCount {
      throwDiceNode(transform: SCNMatrix4(frame.camera.transform),
                    offset: diceOffset[count])
    }
  }

  func startGame() {
    DispatchQueue.main.async {
      self.suspendARPlaneDetection()
      self.hideARPlaneNodes()
      self.gameState = .pointToSurface
    }
  }
  
  func loadModels() {
    let diceScene = SCNScene(named: "PokerDice.scnassets/DiceScene.scn")!
    for i in 0..<5 {
      diceNodes.append(
        diceScene
          .rootNode
          .childNode(withName: "dice\(i)", recursively: false)!)
    }
    let focusScene = SCNScene(named: "PokerDice.scnassets/FocusScene.scn")!
    focusNode = focusScene.rootNode.childNode(withName: "focus",
                                              recursively: false)!
    sceneView.scene.rootNode.addChildNode(focusNode)
  }
  
  func throwDiceNode(transform: SCNMatrix4, offset: SCNVector3) {
    let position = SCNVector3(transform.m41 + offset.x,
                              transform.m42 + offset.y,
                              transform.m43 + offset.z)
    let rotation = SCNVector3(Double.random(min: 0, max: .pi),
                              Double.random(min: 0, max: .pi),
                              Double.random(min: 0, max: .pi))
    
    let diceNode = diceNodes[diceStyle].clone()
    diceNode.name = "dice"
    diceNode.position = position
    diceNode.eulerAngles = rotation

    // 1
    let distance = simd_distance(focusNode.simdPosition,
                                 simd_make_float3(transform.m41,
                                                  transform.m42,
                                                  transform.m43))
    // 2
    let direction = SCNVector3(-(distance * 2.5) * transform.m31,
                               -(distance * 2.5) * (transform.m32 - Float.pi / 4),
                               -(distance * 2.5) * transform.m33)

    diceNode.physicsBody?.resetTransform()
    diceNode.physicsBody?.applyForce(direction, asImpulse: true)
    
    sceneView.scene.rootNode.addChildNode(diceNode)
    diceCount -= 1
  }
  
  func updateStatus() {
    // 1
    switch gameState {
    case .detectSurface:
      statusMessage = "Scan entire table surface..."
    case .pointToSurface:
      statusMessage = "Point at designated surface first!"
    case .swipeToPlay:
      statusMessage = "Swipe UP to throw!\nTap die to collect."
    }
    // 2
    self.statusLabel.text = trackingStatus != "" ? "\(trackingStatus)" : "\(statusMessage)"
  }

  func updateDiceNodes() {
    // 1
    for node in sceneView.scene.rootNode.childNodes { // 2
      if node.name == "dice" {
        if node.presentation.position.y < -2 {
          // 3
          node.removeFromParentNode()
          diceCount += 1
        }
      }

    }
  }

  func suspendARPlaneDetection() {
    let config = sceneView.session.configuration as! ARWorldTrackingConfiguration

    config.planeDetection = []

    sceneView.session.run(config)
  }

  func hideARPlaneNodes() {
    for anchor in (self.sceneView.session.currentFrame?.anchors)! {
      if let node = self.sceneView.node(for: anchor) {
        for child in node.childNodes {
          let material = child.geometry?.materials.first!
          material?.colorBufferWriteMask = .init(rawValue: 0)
        }
      }
    }
  }

  func resetGame() {
    DispatchQueue.main.async {
      self.resetARSession()
      self.startButton.isHidden = false
      self.gameState = .detectSurface

    }
  }

  func resetARSession() {
    let config = self.sceneView.session.configuration as! ARWorldTrackingConfiguration

    config.planeDetection = .horizontal

    sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
  }
  
  // MARK: - View Management
  @objc func orientationChanged() {
    focusPoint = CGPoint(x: view.center.x,
                         y: view.center.y + view.center.y * 0.25)
  }
  
  // MARK: - Helper functions
  func createARPlaneNode(planeAnchor: ARPlaneAnchor, color: UIColor) -> SCNNode {
    let planeGeometry = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                 height: CGFloat(planeAnchor.extent.z))
    let planeMaterial = SCNMaterial()
    planeMaterial.diffuse.contents = "PokerDice.scnassets/Textures/Surface_DIFFUSE.png"
    planeGeometry.materials = [planeMaterial]
    // 1 - Create plane node
    let planeNode = SCNNode(geometry: planeGeometry)
    // 2
    planeNode.position = SCNVector3Make(planeAnchor.center.x,
                                        0,
                                        planeAnchor.center.z)
    // 3
    planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2,
                                                 1,
                                                 0,
                                                 0)
    planeNode.physicsBody = createARPlanePhysics(geometry: planeGeometry)
    // 4
    return planeNode
  }
  
  func updateARPlaneNode(
    planeNode: SCNNode, planeAchor: ARPlaneAnchor) {
    // Add code here
    let planeGeometry = planeNode.geometry as! SCNPlane
    planeGeometry.width = CGFloat(planeAchor.extent.x)
    planeGeometry.height = CGFloat(planeAchor.extent.z)
    planeNode.position = SCNVector3Make(planeAchor.center.x,
                                        0,
                                        planeAchor.center.z)
    planeNode.physicsBody = nil
    planeNode.physicsBody = createARPlanePhysics(geometry: planeGeometry)
  }

  func removeARPlaneNode(node: SCNNode) {
    for childNode in node.childNodes {
      childNode.removeFromParentNode()
    }
  }
  
  func updateFocusNode() {
    let results = self.sceneView.hitTest(self.focusPoint,
                                         types: [.existingPlaneUsingExtent])
    if results.count == 1 {
      if let match = results.first {
        let t = match.worldTransform // 4
        self.focusNode.position = SCNVector3( x: t.columns.3.x,
                                              y: t.columns.3.y,
                                              z: t.columns.3.z)
        self.gameState = .swipeToPlay
        focusNode.isHidden = false
      }
    } else {
      self.gameState = .pointToSurface
      focusNode.isHidden = true
    }
  }

  func createARPlanePhysics(geometry: SCNGeometry) -> SCNPhysicsBody {
  let physicsBody = SCNPhysicsBody(type: .kinematic,
                                   shape: SCNPhysicsShape(geometry: geometry,
                                                          options: nil))
  physicsBody.restitution = 0.5
  physicsBody.friction = 0.5
  return physicsBody
  }
}

// MARK:- ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {
  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    DispatchQueue.main.async {
      self.updateStatus()
      self.updateFocusNode()
      self.updateDiceNodes()
    }
  }
  
  // Session Error Management
  
  func session(_ session: ARSession, didFailWithError error: Error) {
    trackingStatus = "AR Session Failure: \(error)"
  }
  
  func sessionWasInterrupted(_ session: ARSession) {
    trackingStatus = "AR Session Was Interrupted!"
  }
  
  func sessionInterruptionEnded(_ session: ARSession) {
    trackingStatus = "AR Session Interruption Ended"
    resetGame()
  }
  
  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    switch camera.trackingState {
    // 1
    case .notAvailable:
      trackingStatus = "Tacking: Not available!"
    // 2
    case .normal: trackingStatus = ""
    // 3
    case .limited(let reason): switch reason {
    case .excessiveMotion:
      trackingStatus = "Tracking: Limited due to excessive motion!"
    case .insufficientFeatures:
      trackingStatus = "Tracking: Limited due to insufficient features!"
    case .initializing:
      trackingStatus = "Tracking: Initializing..."
    case .relocalizing:
      trackingStatus = "Tracking: Relocalizing..."
    @unknown default:
      trackingStatus = "Tracking: Unknown..."
      
      }
    }
  }
  
  // Plane Management
  // 1
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    // 2
    guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
    // 3
    DispatchQueue.main.async {
      let planeNode = self.createARPlaneNode(planeAnchor: planeAnchor,
                                             color: UIColor.yellow.withAlphaComponent(0.5))
      // 5
      node.addChildNode(planeNode)
      
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
    
    DispatchQueue.main.async {
      self.updateARPlaneNode(planeNode: node.childNodes[0],
                             planeAchor: planeAnchor)
    }
  }

  func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
    guard anchor is ARPlaneAnchor else { return }

    DispatchQueue.main.async {
      self.removeARPlaneNode(node: node)
    }
  }
}

// MARK: - AR Coaching Overlay View
extension ViewController : ARCoachingOverlayViewDelegate {
  func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {

  }

  func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
    startGame()
  }

  func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
    resetGame()
  }
}
