import Foundation
import MetalKit
import ARKit
// キャプチャしたカメラ画像をYCbCrからRGBへ変換するレンダリングパス
class RenderCapturedImagePass: IRenderPass {
    var offscreenTexture: MTLTexture!
    var depthTexture: MTLTexture!
    var descriptor: MTLRenderPassDescriptor!
    var pipelineState: MTLRenderPipelineState!
    var viewportSize: CGSize!
    
    // シェーダーリソース
    var capturedImageTextureY: CVMetalTexture!
    var capturedImageTextureCbCr: CVMetalTexture!
    var realDepthTexture: CVMetalTexture!
    var imagePlaneVertexBuffer: MTLBuffer!
    
    // 左が座標、右がUV
    let imagePlaneVertexData: [Float] = [
        -1.0, -1.0,  0.0, 1.0,
         1.0, -1.0,  1.0, 1.0,
         -1.0,  1.0,  0.0, 0.0,
         1.0,  1.0,  1.0, 0.0,
    ]
    
    init(view:MTKView,size:CGSize) {
        offscreenTexture = TextureController.createOffscreenTexture(width: Int(size.width),
                                                                    height: Int(size.height),
                                                                    pixelFormat: view.colorPixelFormat)
        depthTexture = TextureController.createOffscreenTexture(width: Int(size.width),
                                                                height: Int(size.height),
                                                                pixelFormat: .r32Float)
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = ENCODE_YCBCR_TO_RGB_BUFFER_INDEX.VERTEX.rawValue
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = 8
        vertexDescriptor.attributes[1].bufferIndex = ENCODE_YCBCR_TO_RGB_BUFFER_INDEX.VERTEX.rawValue
        vertexDescriptor.layouts[0].stride = 16
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.colorAttachments[1].pixelFormat = .r32Float
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.vertexFunction = Renderer.library.makeFunction(name: "renderCapturedImageVertex")
        pipelineDescriptor.fragmentFunction = Renderer.library.makeFunction(name: "renderCapturedImageFragment")
        pipelineDescriptor.label = "RenderScreen Pass"
        do {
            try pipelineState = Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("パイプラインステートの生成失敗 RenderScreenPass")
        }
        
        descriptor = MTLRenderPassDescriptor()
        viewportSize = CGSize()
        
        let imagePlaneVertexDataCount = imagePlaneVertexData.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = Renderer.device.makeBuffer(bytes: imagePlaneVertexData,
                                                            length: imagePlaneVertexDataCount, options: [])
        imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
    }
    func resize(view: MTKView, size: CGSize) {
        viewportSize = size
        offscreenTexture = TextureController.createOffscreenTexture(width: Int(size.width),
                                                                    height: Int(size.height),
                                                                    pixelFormat: view.colorPixelFormat)
        depthTexture = TextureController.createOffscreenTexture(width: Int(size.width),
                                                                height: Int(size.height),
                                                                pixelFormat: .r32Float)
    }
    
    func update(frame: ARFrame, uiInterfaceOrientation: UIInterfaceOrientation) {
        updateCapturedImage(frame: frame)
        updateImagePlane(frame: frame,uiInterfaceOrientation: uiInterfaceOrientation)
    }
    func updateCapturedImage(frame: ARFrame)
    {
        let pixelBuffer = frame.capturedImage
        let depthBuffer = frame.smoothedSceneDepth!.depthMap
        
        capturedImageTextureY = TextureController.createCVMetalTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        capturedImageTextureCbCr = TextureController.createCVMetalTextureFromCVPixelBuffer(pixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
        realDepthTexture = TextureController.createCVMetalTextureFromCVPixelBuffer(pixelBuffer: depthBuffer,
                                                                                   pixelFormat: .r32Float,
                                                                                   planeIndex: 0)
    }
    
    func updateImagePlane(frame: ARFrame, uiInterfaceOrientation: UIInterfaceOrientation) {
        // アスペクト比に合わせてテクスチャ座標を更新している⇨アスペクト比にあった結果が得られる
        let displayToCameraTransform = frame.displayTransform(for: uiInterfaceOrientation,
                                                              viewportSize: viewportSize).inverted()
        
        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(imagePlaneVertexData[textureCoordIndex]), y: CGFloat(imagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
        }
    }
    
    func draw(view: MTKView, commandBuffer: MTLCommandBuffer) {
        // ディスクリプタセット
        guard let descriptor = descriptor else { return }
        descriptor.colorAttachments[0].texture = offscreenTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0.5, blue: 1, alpha: 1)
        descriptor.colorAttachments[1].texture = depthTexture
        descriptor.colorAttachments[1].loadAction = .clear
        descriptor.colorAttachments[1].storeAction = .store
        descriptor.colorAttachments[1].clearColor = .init(red: 1, green: 1, blue: 1, alpha: 1)
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setCullMode(.none)
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0,
                                      index: ENCODE_YCBCR_TO_RGB_BUFFER_INDEX.VERTEX.rawValue)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureY),
                                         index: ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX.Y.rawValue)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr),
                                         index: ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX.CBCR.rawValue)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(realDepthTexture),
                                         index: ENCODE_YCBCR_TO_RGB_TEXTURE_INDEX.DEPTH.rawValue)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
    }
}
