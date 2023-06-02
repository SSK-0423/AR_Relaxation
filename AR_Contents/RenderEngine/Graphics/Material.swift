import Foundation
import Metal

struct Material {
    var isReflection: Bool
    
    var textures: Dictionary<String,MTLTexture> = [:]
    
    var baseColor: MTLTexture! = nil
    var metallic: MTLTexture! = nil
    var roughness: MTLTexture! = nil
    
    init(baseColor:SIMD3<Float> = SIMD3<Float>(0,0,0),metallic:SIMD3<Float> = SIMD3<Float>(0,0,0), isReflection:Bool = false) {
        self.baseColor = TextureController.createTextureFromConstantData(constantData: baseColor,
                                                                         pixelFormat: .rgba32Float,
                                                                         type: .type2D,
                                                                         width: 32,
                                                                         height: 32,
                                                                         label: "ConstantBaseColorTexture")
        self.metallic = TextureController.createTextureFromConstantData(constantData: metallic,
                                                                        pixelFormat: .rgba32Float,
                                                                        type: .type2D,
                                                                        width: 32,
                                                                        height: 32,
                                                                        label: "ConstantMetallicTexture")
        self.isReflection = isReflection
    }
    
    init(baseColorTexName:String = "", metallicTexName:String = "",isReflection:Bool = false) {
        self.baseColor = TextureController.texture(filename: baseColorTexName)
        self.metallic = TextureController.texture(filename: metallicTexName)
        self.isReflection = isReflection
    }
}
