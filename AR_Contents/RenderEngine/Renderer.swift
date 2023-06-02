import Foundation
import MetalKit
import ARKit

enum RendererInitError: Error{
    case noLibrary
    case noCommandQueue
}

class Renderer: NSObject {
    static var device: MTLDevice!
    static var library: MTLLibrary!
    static var metalView: MTKView!
    static var session: ARSession!
    static var commandQueue: MTLCommandQueue!
    
    var renderCapturedImagePass: RenderCapturedImagePass!
    var renderGeometryPass: RenderGeometryPass!
    var renderSkyBoxPass: RenderSkyBoxPass!
    var postProcessPass: PostProcessPass!
    var renderScreenPass: RenderScreenPass!
    
    var scene: ARScene!
    var sharedUniforms: SharedUniforms = SharedUniforms()
    var viewportSize: CGSize!
    
    init?(metalView: MTKView,session:ARSession){
        Renderer.device = metalView.device!
        Renderer.metalView = metalView
        Renderer.session = session
        
        guard let commandQueue = Renderer.device.makeCommandQueue() else {
            fatalError("コマンドキュー生成失敗")
        }
        guard let library = Renderer.device.makeDefaultLibrary() else {
            fatalError("ライブラリー生成失敗")
        }
        Renderer.library = library
        Renderer.commandQueue = commandQueue
        
        let size = metalView.frame.size
        
        metalView.device = Renderer.device
        metalView.colorPixelFormat = .rgba8Unorm
        metalView.sampleCount = 1
        metalView.drawableSize = size
        metalView.autoResizeDrawable = true
        
        // テクスチャキャッシュ生成
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, Renderer.device, nil, &textureCache)
        TextureController.capturedImageTextureCache = textureCache
        
        super.init()
        
        // レンダーパス初期化
        renderCapturedImagePass = RenderCapturedImagePass(view: metalView, size: size)
        renderGeometryPass = RenderGeometryPass(view: metalView, size: size)
        renderSkyBoxPass = RenderSkyBoxPass(view: metalView, size: size)
        postProcessPass = PostProcessPass(view: metalView, size: size)
        renderScreenPass = RenderScreenPass(view: metalView, size: size)
        
        scene = ARScene()
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        viewportSize = size
        renderCapturedImagePass.resize(view: view, size: size)
        renderGeometryPass.resize(view: view, size: size)
        renderSkyBoxPass.resize(view: view, size: size)
        postProcessPass.resize(view: view, size: size)
        renderScreenPass.resize(view: view, size: size)
        
        sharedUniforms.width = UInt32(size.width)
        sharedUniforms.height = UInt32(size.height)
    }
    func update(view:MTKView, session: ARSession)
    {
        guard let currentFrame = session.currentFrame else { return }
        updateUniforms(frame: currentFrame)
        renderCapturedImagePass.updateCapturedImage(frame: currentFrame)
        renderCapturedImagePass.update(frame: currentFrame, uiInterfaceOrientation: .portrait)
        renderCapturedImagePass.updateImagePlane(frame: currentFrame, uiInterfaceOrientation: .portrait)
        
        postProcessPass.update(frame: currentFrame)
        
        renderScreenPass.update(frame: currentFrame)
        
        draw(in: view)
    }
    func draw(in view: MTKView) {
        guard let commandBuffer = Renderer.commandQueue.makeCommandBuffer() else { return }
        renderCapturedImagePass.draw(view: view, commandBuffer: commandBuffer)
        
        renderGeometryPass.draw(view: view, commandBuffer: commandBuffer, uniforms: sharedUniforms, scene: scene)
        
        renderSkyBoxPass.draw(view: view, commandBuffer: commandBuffer, uniforms: sharedUniforms, scene: scene)
        
        postProcessPass.renderedTexture = renderCapturedImagePass.offscreenTexture
        postProcessPass.lidarDepthTexture = renderCapturedImagePass.depthTexture
        postProcessPass.skyTexture = renderSkyBoxPass.offscreenTexture
        postProcessPass.geometryTexture = renderGeometryPass.offscreenTexture
        postProcessPass.draw(view: view, commandBuffer: commandBuffer)
        
        renderScreenPass.renderedTexture = postProcessPass.offscreenTexture
        renderScreenPass.draw(view: view, commandBuffer: commandBuffer, uniforms: sharedUniforms)
        
        // レンダリング終了
        guard let drawable = view.currentDrawable else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
    
    func updateUniforms(frame: ARFrame) {
        sharedUniforms.view = frame.camera.viewMatrix(for: .portrait)
        sharedUniforms.projection = frame.camera.projectionMatrix(for: .portrait, viewportSize: viewportSize, zNear: 0.001, zFar: 1000)
        sharedUniforms.eyePosition = [frame.camera.transform.columns.3.x,
                                      frame.camera.transform.columns.3.y,
                                      frame.camera.transform.columns.3.z]
    }
}

