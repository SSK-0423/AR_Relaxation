import Foundation
import MetalKit
import ARKit

class RenderScreenPass : IRenderPass {
    var offscreenTexture: MTLTexture!
    var descriptor: MTLRenderPassDescriptor!
    var pipelineState: MTLRenderPipelineState!
    
    var renderedTexture: MTLTexture!
    var viewportSize: CGSize!
    var imagePlaneVertexBuffer: MTLBuffer!
    
    // 左が座標、右がUV
    let imagePlaneVertexData: [Float] = [
        -1.0, -1.0,  0.0, 1.0,
         1.0, -1.0,  1.0, 1.0,
         -1.0,  1.0,  0.0, 0.0,
         1.0,  1.0,  1.0, 0.0,
    ]
    
    init(view:MTKView,size: CGSize) {
        offscreenTexture = TextureController.createOffscreenTexture(width: Int(size.width),
                                                                    height: Int(size.height),
                                                                    pixelFormat: view.colorPixelFormat)
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
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.vertexFunction = Renderer.library.makeFunction(name: "fullScreenQuadVertex")
        pipelineDescriptor.fragmentFunction = Renderer.library.makeFunction(name: "fullScreenQuadFragment")
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
        
        descriptor = MTLRenderPassDescriptor()
        viewportSize = CGSize()
    }
    
    func resize(view: MTKView, size: CGSize) {
        viewportSize = size
        offscreenTexture = TextureController.createOffscreenTexture(width: Int(size.width),
                                                                    height: Int(size.height),
                                                                    pixelFormat: .rgba8Unorm)
    }
    func update(frame: ARFrame) {
        //updateImagePlane(frame: frame)
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
    
    func draw(view: MTKView, commandBuffer: MTLCommandBuffer, uniforms: SharedUniforms) {
        descriptor = view.currentRenderPassDescriptor
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: ENCODE_YCBCR_TO_RGB_BUFFER_INDEX.VERTEX.rawValue)
        renderEncoder.setFragmentTexture(renderedTexture,
                                         index: RENDER_SCREEN_TEXTURE_INDEX.RENDER_RESULT.rawValue)

        
        var uniformsBytes = uniforms
        renderEncoder.setFragmentBytes(&uniformsBytes,
                                       length: MemoryLayout<SharedUniforms>.stride,
                                       index: RENDER_SCREEN_BUFFER_INDEX.SHARED_UNIFORMS.rawValue)
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
    }
}
