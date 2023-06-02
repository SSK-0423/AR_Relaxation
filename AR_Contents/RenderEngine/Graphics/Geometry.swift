import Foundation
import MetalKit
import ARKit

struct GeometryInitData {
    var material = Material(baseColor: [1,1,1])
    var transform = Transform()
}

class Geometry : Transformable{
    var transform: Transform = Transform()
    var prevFrameTransform: Transform = Transform()
    var mtkMesh: MTKMesh!
    var material = Material(baseColor: [1,1,1])
    var anchor: ARAnchor!
    var parent: Geometry? = nil
    
    // 3Dファイルからジオメトリ生成
    init(fileName: String, anchor:ARAnchor, parent: Geometry? = nil, data: GeometryInitData) {
        // TODO: 卒論後実装
        self.transform = data.transform
        self.material = data.material
        self.anchor = anchor
        self.parent = parent
    }
    // MDLメッシュからジオメトリ生成
    init(mdlMesh: MDLMesh, anchor:ARAnchor, parent: Geometry? = nil, data: GeometryInitData)
    {
        self.transform = data.transform
        self.material = data.material
        self.anchor = anchor
        self.parent = parent
        do {
            try mtkMesh = MTKMesh(mesh: mdlMesh, device: Renderer.device)
        } catch {
            fatalError("MTKMesh生成失敗")
        }
        print("サブメッシュカウント")
        // MDLMeshに用意されている基本図形はサブメッシュ1つ
        print(mtkMesh.submeshes.count)
        let vertexBuffers = mtkMesh.vertexBuffers
        let normalBuffer = vertexBuffers[RENDER_GEOMETRY_BUFFER_INDEX.NORMAL.rawValue].buffer
        let uvBuffer = vertexBuffers[RENDER_GEOMETRY_BUFFER_INDEX.UV.rawValue].buffer
    }
    
    /// 親子関係も含めた座標変換行列　レンダリング時にはこちらの値を用いる
    var modelMatrix: simd_float4x4 {
        var matrix = matrix_identity_float4x4
        var parentGeometry = parent
        var modelMatrixList: [simd_float4x4] = [transform.modelMatrix]
        while true {
            if parentGeometry == nil { break }
            modelMatrixList.append(parentGeometry!.transform.modelMatrix)
            parentGeometry = parentGeometry?.parent
        }
        
        for index in (0..<modelMatrixList.count).reversed() {
            matrix = simd_mul(matrix, modelMatrixList[index])
        }
        // ARKitは右手座標系 Metalは左手座標系なので右手座標系から左手座標系に変換する
        var coordinateSpaceTransform = matrix_identity_float4x4
        coordinateSpaceTransform.columns.2.z = -1.0
        return simd_mul(matrix, coordinateSpaceTransform)
    }
}
