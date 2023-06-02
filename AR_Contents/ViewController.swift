import UIKit
import Metal
import MetalKit
import ARKit

class ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate {
    
    var session: ARSession!
    var renderer: Renderer!
    var planeAnchor: ARPlaneAnchor? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        session = ARSession()
        session.delegate = self
        
        // Set the view to use the default device
        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self
            
            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }
            
            // Configure the renderer to draw to the view
            renderer = Renderer(metalView: view, session: session)
            renderer.mtkView(view, drawableSizeWillChange: view.drawableSize)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        
        // シーンデプス有効化
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth){
            configuration.frameSemantics.insert(.sceneDepth)
        } else {
            fatalError("このデバイスはScene Depthに対応していません")
        }
        // スムースシーンデプス有効化
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        } else {
            fatalError("このデバイスはSmoothed Scene Depthに対応していません")
        }

        // Run the view's session
        session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        session.pause()
    }
    
    // MARK: - MTKViewDelegate
    
    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer?.mtkView(view, drawableSizeWillChange: size)
    }
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.update(view: view, session: session)
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                if self.planeAnchor != nil { return }
                if planeAnchor.alignment == ARPlaneAnchor.Alignment.horizontal {
                    print("水平面が検出されました")
                    renderer.scene.createSceneWithHorizontalPlane(session: session, planeAnchor: planeAnchor)
                }
                self.planeAnchor = planeAnchor
            }
        }
    }
}
