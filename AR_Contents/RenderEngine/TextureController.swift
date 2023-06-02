import Foundation
import Metal
import MetalKit


enum TextureController{
    static var textures: [String: MTLTexture] = [:]
    static var capturedImageTextureCache: CVMetalTextureCache!
    
    static func loadTexture(filename: String) throws -> MTLTexture?{
        let textureLoader = MTKTextureLoader(device: Renderer.device)
        
        // assets catalogからテクスチャを読み込む場合
        if let texture = try? textureLoader.newTexture(
            name: filename,
            scaleFactor: 1.0,
            bundle: Bundle.main,
            options: nil) {
            return texture
        }
        
        let textureLoaderOptions: [MTKTextureLoader.Option : Any] =
        [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        let fileExtension = URL(fileURLWithPath: filename).pathExtension.isEmpty ? "png" : nil
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: fileExtension)
        else{
            fatalError("\(filename)の読み込みに失敗しました")
        }
        let texture = try textureLoader.newTexture(URL: url,
                                                   options: textureLoaderOptions)
        print("\(filename)の読み込みに成功しました")
        return texture
    }
    
    static func loadHDRTexture(filename: String)-> MTLTexture?{
        return nil
    }
    
    static func texture(filename: String)-> MTLTexture? {
        if let texture = textures[filename] {
            return texture
        }
        // テクスチャが意図的に指定されていない場合
        else if(filename == ""){
            return createBlackDummyTexture(width: 32, height: 32)
        }
        let texture = try? loadTexture(filename: filename)
        if texture != nil{
            textures[filename] = texture
        }
        return texture
    }
    
    static func createTextureFromRawData<T>(rawData:[T], pixelFormat:MTLPixelFormat,
                                            type:MTLTextureType, width:Int, height:Int, label:String) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = pixelFormat
        descriptor.textureType = type
        descriptor.width = width
        descriptor.height = height
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        
        guard let texture = Renderer.device.makeTexture(descriptor: descriptor) else {
            fatalError("ランダムテクスチャ生成失敗")
        }
        texture.label = label
        
        // 配列の内容をランダムテクスチャにコピー
        rawData.withUnsafeBufferPointer { bufferPtr in
            texture.replace(region: .init(origin: .init(x: 0, y: 0, z: 0),
                                          size: .init(width: texture.width,
                                                      height: texture.height,
                                                      depth: 1)),
                            mipmapLevel: 0,
                            withBytes: bufferPtr.baseAddress!,
                            bytesPerRow: MemoryLayout<T>.stride * texture.width)
        }
        return texture
    }
    
    static func createTextureFromConstantData<T>(constantData:T,pixelFormat:MTLPixelFormat,
                                                 type:MTLTextureType, width:Int, height:Int, label:String) -> MTLTexture? {
        return createTextureFromRawData(rawData: [T](repeating: constantData, count: width * height),
                                        pixelFormat: pixelFormat,
                                        type: type,
                                        width: width,
                                        height: height,
                                        label: label)
    }
    
    static func createWhiteDummyTexture(width:Int, height:Int) -> MTLTexture? {
        return createTextureFromConstantData(constantData: SIMD3<Float>(1,1,1),
                                             pixelFormat: .rgba32Float,
                                             type: .type2D,
                                             width: width,
                                             height: height,
                                             label: "WhiteDummyTexture")
    }
    
    static func createBlackDummyTexture(width:Int, height:Int) -> MTLTexture? {
        return createTextureFromConstantData(constantData: SIMD3<Float>(0,0,0),
                                             pixelFormat: .rgba32Float,
                                             type: .type2D,
                                             width: width,
                                             height: height,
                                             label: "BlackDummyTexture")
    }
    
    static func createOffscreenTexture(
        width:Int, height:Int,pixelFormat: MTLPixelFormat,usage: MTLTextureUsage = [.shaderRead,.renderTarget]) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2D
            descriptor.width = width
            descriptor.height = height
            descriptor.pixelFormat = pixelFormat
            descriptor.usage = usage
            
            guard let texture = Renderer.device.makeTexture(descriptor: descriptor) else {
                fatalError("オフスクリーンテクスチャ生成失敗")
            }
            
            return texture
        }
    
    static func createDepthStencilTexture(width:Int, height:Int, pixelFormat: MTLPixelFormat) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type2D
        descriptor.width = width
        descriptor.height = height
        descriptor.pixelFormat = .depth32Float
        descriptor.usage = [.shaderRead, .renderTarget]
        descriptor.storageMode = .private
        
        guard let texture = Renderer.device.makeTexture(descriptor: descriptor) else {
            fatalError("深度テクスチャ生成失敗")
        }
        
        return texture
    }
    
    static func createCVMetalTextureFromCVPixelBuffer(pixelBuffer: CVPixelBuffer,
                                                      pixelFormat: MTLPixelFormat,
                                                      planeIndex: Int) -> CVMetalTexture?
    {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        
        var texture: CVMetalTexture? = nil
        let result = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache,
                                                               pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)
        if result == kCVReturnSuccess {
            return texture
        }
        return nil
    }
}
