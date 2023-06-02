import Foundation
import MetalKit
import ARKit

class RenderGeometryPass : IRenderPass {
    var offscreenTexture: MTLTexture!
    var virtualDepthTexture: MTLTexture!
    var depthTexture: MTLTexture!
    
    var descriptor: MTLRenderPassDescriptor!
    var pipelineState: MTLRenderPipelineState!
    var depthStencilState: MTLDepthStencilState!
    var viewportSize: CGSize!
    
    // 検証用
    var geometry: MTKMesh!
    let MAX_REALDEPTH = 5.0
    
    init(view:MTKView, size:CGSize) {
        offscreenTexture = TextureController.createOffscreenTexture(width: Int(size.width),
                                                                    height: Int(size.height),
                                                                    pixelFormat: view.colorPixelFormat)
        virtualDepthTexture = TextureController.createDepthStencilTexture(width: Int(size.width),
                                                                          height: Int(size.height),
                                                                          pixelFormat: .r32Float)
        depthTexture = TextureController.createDepthStencilTexture(width: Int(size.width),
                                                                   height: Int(size.height),
                                                                   pixelFormat: .depth32Float)
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 1
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = 0
        vertexDescriptor.attributes[2].bufferIndex = 2
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        vertexDescriptor.layouts[1].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[1].stepRate = 1
        vertexDescriptor.layouts[1].stepFunction = .perVertex
        vertexDescriptor.layouts[2].stride = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.layouts[2].stepRate = 1
        vertexDescriptor.layouts[2].stepFunction = .perVertex
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.colorAttachments[1].pixelFormat = .r32Float
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexFunction = Renderer.library.makeFunction(name: "geometryVertex")
        pipelineDescriptor.fragmentFunction = Renderer.library.makeFunction(name: "geometryFragment")
        pipelineDescriptor.vertexDescriptor = MTLVertexDescriptor.defaultLayout
        pipelineDescriptor.label = "RenderGeometry Pass"
        do{
            try pipelineState = Renderer.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch { return }
        
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        depthStencilState = Renderer.device.makeDepthStencilState(descriptor: depthDesc)
        descriptor = MTLRenderPassDescriptor()
    }
    
    func resize(view: MTKView, size: CGSize) {
        viewportSize = size
        offscreenTexture = TextureController.createOffscreenTexture(width: Int(size.width),
                                                                    height: Int(size.height),
                                                                    pixelFormat: view.colorPixelFormat)
        virtualDepthTexture = TextureController.createOffscreenTexture(width: Int(size.width),
                                                                       height: Int(size.height),
                                                                       pixelFormat: .r32Float)
        depthTexture = TextureController.createDepthStencilTexture(width: Int(size.width),
                                                                   height: Int(size.height),
                                                                   pixelFormat: .depth32Float)
    }
    // 以下の処理内容をレンダリングパスに移す
    func draw(view: MTKView, commandBuffer: MTLCommandBuffer, uniforms: SharedUniforms, scene: ARScene) {
        guard var descriptor = descriptor else { return }
        descriptor.colorAttachments[0].texture = offscreenTexture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = .init(red: 0, green: 0, blue: 0, alpha: 0)
        descriptor.colorAttachments[1].texture = virtualDepthTexture
        descriptor.colorAttachments[1].loadAction = .clear
        descriptor.colorAttachments[1].storeAction = .store
        descriptor.colorAttachments[1].clearColor = .init(red: MAX_REALDEPTH, green: MAX_REALDEPTH, blue: MAX_REALDEPTH, alpha: 1)
        descriptor.depthAttachment.texture = depthTexture
        descriptor.depthAttachment.storeAction = .store
        descriptor.depthAttachment.loadAction = .clear
        
        //descriptor = view.currentRenderPassDescriptor
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else
        { return }
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        for geometry in scene.geometries
        {
            var geometryUniforms = GeometryUniforms(model: geometry.modelMatrix)
            var sharedUniforms = uniforms
            // リソースセット
            renderEncoder.setVertexBytes(&sharedUniforms,
                                         length: MemoryLayout<SharedUniforms>.stride,
                                         index: RENDER_GEOMETRY_BUFFER_INDEX.SHARED_UNIFORMS.rawValue)
            renderEncoder.setVertexBytes(&geometryUniforms,
                                         length: MemoryLayout<GeometryUniforms>.stride,
                                         index: RENDER_GEOMETRY_BUFFER_INDEX.GEOMETRY_UNIFORMS.rawValue)
            
            for bufferIndex in 0..<geometry.mtkMesh.vertexBuffers.count {
                let vertexBuffer = geometry.mtkMesh.vertexBuffers[bufferIndex]
                renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: bufferIndex) // 0:頂点 1:法線 2:UV
            }
            renderEncoder.setFragmentBytes(&sharedUniforms,
                                           length: MemoryLayout<SharedUniforms>.stride,
                                           index: RENDER_GEOMETRY_BUFFER_INDEX.SHARED_UNIFORMS.rawValue)
            renderEncoder.setFragmentTexture(geometry.material.baseColor, index: 0)
            // 描画
            for submesh in geometry.mtkMesh.submeshes {
                renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer.buffer,
                                                    indexBufferOffset: submesh.indexBuffer.offset)
            }
        }
        renderEncoder.endEncoding()
    }
}
