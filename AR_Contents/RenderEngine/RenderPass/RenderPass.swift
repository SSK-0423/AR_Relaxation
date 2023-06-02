import Foundation
import MetalKit

protocol IRenderPass {
    var offscreenTexture : MTLTexture! { get }
    var descriptor : MTLRenderPassDescriptor! { get set }
    var pipelineState : MTLRenderPipelineState! { get set }
    func resize(view: MTKView, size: CGSize)
}
