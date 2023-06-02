import Foundation

/// ARオブジェクトのトランスフォーム情報を格納するクラス
/// パラメータはARKitと同様の右手座標系準拠
struct Transform {
    var position: SIMD3<Float> = [0,0,0]
    var rotation: SIMD3<Float> = [0,0,0]
    var scale: SIMD3<Float>    = [1,1,1]
    
    var modelMatrix: simd_float4x4 {
        let translation = simd_float4x4.translation(x: position.x, y: position.y, z: position.z)
        let rotation = simd_float4x4.rotation(degX: rotation.x, degY: rotation.y, degZ: rotation.z)
        let scale = simd_float4x4.scalling(x: scale.x, y: scale.y, z: scale.z)
        
        let transform = translation * rotation * scale
        
        return transform
    }
}

protocol Transformable {
    var transform: Transform { get set }
}

extension Transformable {
    var position: SIMD3<Float> {
        get { transform.position }
        set { transform.position = newValue }
    }
    var rotation: SIMD3<Float> {
        get { transform.rotation }
        set { transform.rotation = newValue }
    }
    var scale: SIMD3<Float> {
        get { transform.scale }
        set { transform.scale = newValue }
    }
}
