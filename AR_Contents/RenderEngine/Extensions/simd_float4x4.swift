import Foundation
import GLKit

extension simd_float4x4 {
    static func translation(x:Float, y:Float, z:Float) -> simd_float4x4{
        var matrix = matrix_identity_float4x4
        matrix.columns.3 = simd_float4(x: x, y: y, z: z, w: 1)
        return matrix
    }
    /// ARKitと同様の回転順序の回転行列を生成 回転順序はZ(Roll)⇨X(Pitch)⇨Y(Yow) 引数は全てラジアン
    /// - Parameters:
    ///   - radX: X軸のラジアン
    ///   - radY: Y軸のラジアン
    ///   - radZ: Z軸のラジアン
    /// - Returns: ZXYの順の回転行列
    static func rotation(radX:Float, radY:Float, radZ:Float) -> simd_float4x4 {
        let matrix = matrix_identity_float4x4
        let rotationX = simd_float4x4(simd_quatf(angle: radX, axis: [1,0,0]))
        let rotationY = simd_float4x4(simd_quatf(angle: radY, axis: [0,1,0]))
        let rotationZ = simd_float4x4(simd_quatf(angle: radZ, axis: [0,0,1]))
        
        return matrix * rotationZ * rotationX * rotationY
    }
    /// ARKitと同様の回転順序の回転行列を生成 回転順序はZ(Roll)⇨X(Pitch)⇨Y(Yow) 引数は全て度数
    /// - Parameters:
    ///   - degX: X軸の回転角度
    ///   - degY: Y軸の回転角度
    ///   - degZ: Z軸の回転角度
    /// - Returns: ZXYの順の回転行列
    static func rotation(degX:Float, degY:Float, degZ:Float) -> simd_float4x4 {
        return rotation(radX: GLKMathDegreesToRadians(degX), radY: GLKMathDegreesToRadians(degY), radZ: GLKMathDegreesToRadians(degZ))
    }
    static func scalling(x:Float,y:Float,z:Float) -> simd_float4x4 {
        var matrix = matrix_identity_float4x4
        matrix[0][0] = x
        matrix[1][1] = y
        matrix[2][2] = z
        return matrix
    }
    
    /// 列優先
    /// - Parameters:
    ///   - matrix: <#matrix description#>
    ///   - vector: <#vector description#>
    /// - Returns: <#description#>
    static func mul(matrix: simd_float4x4, vector: simd_float4) -> simd_float4 {
        var ret = simd_float4()
        // vectorを列ベクトルとして解釈
        ret.x = simd_dot(matrix.rows.0, vector)
        ret.y = simd_dot(matrix.rows.1, vector)
        ret.z = simd_dot(matrix.rows.2, vector)
        ret.w = simd_dot(matrix.rows.3, vector)
        
        return ret
    }
    
    public var rows: (simd_float4, simd_float4, simd_float4, simd_float4) {
        return ([columns.0.x,columns.1.x,columns.2.x,columns.3.x,],
                [columns.0.y,columns.1.y,columns.2.y,columns.3.y],
                [columns.0.z,columns.1.x,columns.2.z,columns.3.z,],
                [columns.0.w,columns.1.w,columns.2.w,columns.3.w,])
    }
    
    var position: simd_float3 {
        return [self.columns.3.x,self.columns.3.y,self.columns.3.z]
    }
}
