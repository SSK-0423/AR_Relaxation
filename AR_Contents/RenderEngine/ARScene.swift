//
//  ARScene.swift
//  AR_Contents
//
//  Created by 山本知仁 on 2022/12/18.
//

import Foundation
import MetalKit
import ARKit

class ARScene {
    var geometries: [Geometry] = []
    var skyBoxGeometries: [Geometry] = []
    init() {
        // 検出した平面のオブジェクトを表すジオメトリ生成
        let metalAllocator = MTKMeshBufferAllocator(device: Renderer.device)
        let vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(MTLVertexDescriptor.defaultLayout)
        (vertexDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (vertexDescriptor.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        (vertexDescriptor.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        
        // スカイボックス生成
        let planeMesh = MDLMesh.newPlane(withDimensions: [1,1], segments: [1,1], geometryType: .triangles, allocator: metalAllocator)
        planeMesh.vertexDescriptor = vertexDescriptor
        
        var value:Float = 10
        var scale:Float = value * 2
        // X軸正
        var data = GeometryInitData()
        data.transform = Transform(position: [value,0,0],rotation: [0,90,-90],scale: [scale,scale,scale])
        data.material = Material(baseColorTexName: "px")
        skyBoxGeometries.append(Geometry(mdlMesh: planeMesh, anchor: ARAnchor(transform: data.transform.modelMatrix), data: data))
        // X軸負 zxy
        data.transform = Transform(position: [-value,0,0],rotation: [0,-90,90],scale: [scale,scale,scale])
        data.material = Material(baseColorTexName: "nx")
        skyBoxGeometries.append(Geometry(mdlMesh: planeMesh, anchor: ARAnchor(transform: data.transform.modelMatrix), data: data))
        // Y軸正
        data.transform = Transform(position: [0,value,0],rotation: [0,0,0],scale: [scale,scale,scale])
        data.material = Material(baseColorTexName: "py")
        skyBoxGeometries.append(Geometry(mdlMesh: planeMesh, anchor: ARAnchor(transform: data.transform.modelMatrix), data: data))
        // Y軸負
        data.transform = Transform(position: [0,-value,0],rotation: [180,0,0],scale: [scale,scale,scale])
        data.material = Material(baseColorTexName: "ny")
        skyBoxGeometries.append(Geometry(mdlMesh: planeMesh, anchor: ARAnchor(transform: data.transform.modelMatrix), data: data))
        // Z軸正
        data.transform = Transform(position: [0,0,value],rotation: [90,0,0],scale: [scale,scale,scale])
        data.material = Material(baseColorTexName: "pz")
        skyBoxGeometries.append(Geometry(mdlMesh: planeMesh, anchor: ARAnchor(transform: data.transform.modelMatrix), data: data))
        // Z軸負
        data.transform = Transform(position: [0,0,-value],rotation: [-90,0,180],scale: [scale,scale,scale])
        data.material = Material(baseColorTexName: "nz")
        skyBoxGeometries.append(Geometry(mdlMesh: planeMesh, anchor: ARAnchor(transform: data.transform.modelMatrix), data: data))
    }
    
    func createSceneWithHorizontalPlane(session: ARSession, planeAnchor: ARPlaneAnchor) {
        // 検出した水平面を表すジオメトリ生成
        let metalAllocator = MTKMeshBufferAllocator(device: Renderer.device)
        let vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(MTLVertexDescriptor.defaultLayout)
        (vertexDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (vertexDescriptor.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        (vertexDescriptor.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        
        var planeWidth: Float = 0.0
        var planeHeight: Float = 0.0
        var transform = Transform()
        if #available(iOS 16.0, *) {
            planeWidth = planeAnchor.planeExtent.width
            planeHeight = planeAnchor.planeExtent.height
            // iOS16ではY軸の回転を自分で行う必要がある
            let yRot = planeAnchor.planeExtent.rotationOnYAxis
            let planePosition = planeAnchor.transform.columns.3
            transform.position = [planePosition.x,planePosition.y + 0.01,planePosition.z]
            transform.rotation = [0,GLKMathRadiansToDegrees(yRot),0]
            print("平面の位置")
            print(planePosition)
        }
        let mesh = MDLMesh.newPlane(withDimensions: [planeWidth,planeHeight],
                                    segments: [1,1],
                                    geometryType: .triangles,
                                    allocator: metalAllocator)
        mesh.vertexDescriptor = vertexDescriptor
        
        var data = GeometryInitData()
        data.transform = transform
        data.material = Material(baseColor: [1,1,1])
        let planeGeometry = Geometry(mdlMesh: mesh, anchor: planeAnchor, data: data)
        //geometries.append(planeGeometry)
        
        // コーネルボックス生成
        let planeMesh = MDLMesh.newPlane(withDimensions: [1,1], segments: [1,1],
                                         geometryType: .triangles, allocator: metalAllocator)
        planeMesh.vertexDescriptor = vertexDescriptor
        // 天井
        data.material = Material(baseColor: [0.725, 0.71, 0.68])
        data.transform = Transform(position: [0,0.2,0],rotation: [0,0,0],scale: [0.2,0.2,0.2])
        geometries.append(Geometry(mdlMesh: planeMesh, anchor: planeAnchor, parent: planeGeometry, data: data))
        // 床
        data.material = Material(baseColor: [0.725, 0.71, 0.68])
        data.transform = Transform(position: [0,0.001,0],scale: [0.2,0.2,0.2])
        geometries.append(Geometry(mdlMesh: planeMesh, anchor: planeAnchor, parent: planeGeometry, data: data))
        // 右壁
        data.material = Material(baseColor: [0.14, 0.45, 0.091])
        data.transform = Transform(position: [0.1,0.1,0],rotation: [0,0,90],scale: [0.2,0.2,0.2])
        geometries.append(Geometry(mdlMesh: planeMesh, anchor: planeAnchor, parent: planeGeometry, data: data))
        // 左壁
        data.material = Material(baseColor: [0.63, 0.065, 0.05])
        data.transform = Transform(position: [-0.1,0.1,0],rotation: [0,0,90],scale: [0.2,0.2,0.2])
        geometries.append(Geometry(mdlMesh: planeMesh, anchor: planeAnchor, parent: planeGeometry, data: data))
        // 奥壁
        data.material = Material(baseColor: [0.725, 0.71, 0.68])
        data.transform = Transform(position: [0,0.1,-0.1],rotation: [90,0,0],scale: [0.2,0.2,0.2])
        geometries.append(Geometry(mdlMesh: planeMesh, anchor: planeAnchor, parent: planeGeometry, data: data))
        // 光源
        data.material = Material(baseColor: [1, 1, 1])
        data.transform = Transform(position: [0,0.199,0],rotation: [0,0,0],scale: [0.05,0.1,0.05])
        geometries.append(Geometry(mdlMesh: planeMesh, anchor: planeAnchor, parent: planeGeometry, data: data))
        
        // ボックス
        let boxMesh = MDLMesh.newBox(withDimensions: [1,1,1], segments: [1,1,1],
                                     geometryType: .triangles, inwardNormals: false, allocator: metalAllocator)
        boxMesh.vertexDescriptor = vertexDescriptor
        // ショートボックス
        data.material = Material(baseColor: [0.725, 0.71, 0.68])
        data.transform = Transform(position: [0.03275,0.025,0.025],rotation: [0,GLKMathRadiansToDegrees(-0.3),0],scale: [0.05,0.05,0.05])
        geometries.append(Geometry(mdlMesh: boxMesh, anchor: planeAnchor, parent: planeGeometry, data: data))
        // ロングボックス
        data.material = Material(baseColor: [0.725, 0.71, 0.68],metallic: [1,1,1],isReflection: true)
        data.transform = Transform(position: [-0.0335,0.05,0.0],rotation: [0,GLKMathRadiansToDegrees(0.3),0],scale: [0.05,0.1,0.05])
        geometries.append(Geometry(mdlMesh: boxMesh, anchor: planeAnchor, parent: planeGeometry, data: data))
    }
}
