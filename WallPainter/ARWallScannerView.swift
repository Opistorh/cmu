import ARKit
import CoreImage
import SceneKit
import SwiftUI

struct ARWallScannerView: UIViewRepresentable {
    typealias UIViewType = UIView

    @Binding var showDepthOverlay: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        #if targetEnvironment(simulator)
        return makePlaceholderView(text: "Simulator does not provide LiDAR or AR camera tracking. Run this app on your iPhone 16 Pro.")
        #else
        guard ARWorldTrackingConfiguration.isSupported else {
            return makePlaceholderView(text: "ARWorldTracking is not supported on this device.")
        }

        let containerView = UIView(frame: .zero)
        containerView.backgroundColor = .black

        let sceneView = ARSCNView(frame: .zero)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.delegate = context.coordinator
        sceneView.session.delegate = context.coordinator
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = SCNScene()
        containerView.addSubview(sceneView)

        let depthOverlayView = UIImageView(frame: .zero)
        depthOverlayView.translatesAutoresizingMaskIntoConstraints = false
        depthOverlayView.contentMode = .scaleToFill
        depthOverlayView.backgroundColor = .clear
        depthOverlayView.alpha = showDepthOverlay ? 0.55 : 0.0
        containerView.addSubview(depthOverlayView)

        NSLayoutConstraint.activate([
            sceneView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            sceneView.topAnchor.constraint(equalTo: containerView.topAnchor),
            sceneView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            depthOverlayView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            depthOverlayView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            depthOverlayView.topAnchor.constraint(equalTo: containerView.topAnchor),
            depthOverlayView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        context.coordinator.attach(sceneView: sceneView, depthOverlayView: depthOverlayView)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return containerView
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.setDepthOverlayVisible(showDepthOverlay)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.sceneView?.session.pause()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
        weak var sceneView: ARSCNView?
        weak var depthOverlayView: UIImageView?

        private let overlayColor = UIColor(red: 0.35, green: 1.0, blue: 0.08, alpha: 0.9)
        private let ciContext = CIContext(options: nil)
        private let minimumRenderableDepth: Float = 0.45

        func attach(sceneView: ARSCNView, depthOverlayView: UIImageView) {
            self.sceneView = sceneView
            self.depthOverlayView = depthOverlayView
        }

        func setDepthOverlayVisible(_ isVisible: Bool) {
            UIView.animate(withDuration: 0.2) {
                self.depthOverlayView?.alpha = isVisible ? 0.55 : 0.0
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            if let meshAnchor = anchor as? ARMeshAnchor {
                return makeWallMeshNode(for: meshAnchor)
            }

            guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
                return nil
            }

            return makeWallPlaneNode(for: planeAnchor)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            if let meshAnchor = anchor as? ARMeshAnchor {
                updateWallMeshNode(node, for: meshAnchor)
                return
            }

            guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
                return
            }

            updateWallPlaneNode(node, for: planeAnchor)
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard let image = makeDepthImage(from: frame) else {
                return
            }

            DispatchQueue.main.async {
                self.depthOverlayView?.image = image
            }
        }

        private func makeWallPlaneNode(for anchor: ARPlaneAnchor) -> SCNNode {
            let plane = SCNPlane(width: max(CGFloat(anchor.extent.x), 0.05),
                                 height: max(CGFloat(anchor.extent.y), 0.05))
            plane.cornerRadius = 0.02
            plane.materials = [wallMaterial()]

            let planeNode = SCNNode(geometry: plane)
            planeNode.simdPosition = SIMD3(anchor.center.x, anchor.center.y, anchor.center.z)
            planeNode.renderingOrder = 100

            let container = SCNNode()
            container.addChildNode(planeNode)
            return container
        }

        private func updateWallPlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
            guard let planeNode = node.childNodes.first,
                  let plane = planeNode.geometry as? SCNPlane else {
                return
            }

            plane.width = max(CGFloat(anchor.extent.x), 0.05)
            plane.height = max(CGFloat(anchor.extent.y), 0.05)
            planeNode.simdPosition = SIMD3(anchor.center.x, anchor.center.y, anchor.center.z)
        }

        private func makeWallMeshNode(for anchor: ARMeshAnchor) -> SCNNode? {
            guard let geometry = makeWallMeshGeometry(from: anchor.geometry) else {
                return nil
            }

            let node = SCNNode(geometry: geometry)
            node.renderingOrder = 200
            return node
        }

        private func updateWallMeshNode(_ node: SCNNode, for anchor: ARMeshAnchor) {
            node.geometry = makeWallMeshGeometry(from: anchor.geometry)
        }

        private func makeWallMeshGeometry(from meshGeometry: ARMeshGeometry) -> SCNGeometry? {
            guard meshGeometry.faces.count > 0,
                  let classification = meshGeometry.classification else {
                return nil
            }

            var vertices: [SCNVector3] = []
            var indices: [UInt32] = []
            var remappedIndices: [UInt32: UInt32] = [:]

            for faceIndex in 0 ..< meshGeometry.faces.count {
                guard classificationOf(faceWithIndex: faceIndex, source: classification) == .wall else {
                    continue
                }

                let vertexIndices = faceVertexIndices(for: faceIndex, in: meshGeometry.faces)
                for vertexIndex in vertexIndices {
                    let mappedIndex: UInt32
                    if let existing = remappedIndices[vertexIndex] {
                        mappedIndex = existing
                    } else {
                        let vertex = meshGeometry.vertex(at: vertexIndex)
                        let newIndex = UInt32(vertices.count)
                        vertices.append(SCNVector3(vertex.x, vertex.y, vertex.z))
                        remappedIndices[vertexIndex] = newIndex
                        mappedIndex = newIndex
                    }
                    indices.append(mappedIndex)
                }
            }

            guard !vertices.isEmpty, !indices.isEmpty else {
                return nil
            }

            let vertexSource = SCNGeometrySource(vertices: vertices)
            let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
            let element = SCNGeometryElement(data: indexData,
                                             primitiveType: .triangles,
                                             primitiveCount: indices.count / 3,
                                             bytesPerIndex: MemoryLayout<UInt32>.stride)

            let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
            geometry.materials = [wallMaterial()]
            return geometry
        }

        private func faceVertexIndices(for faceIndex: Int, in faces: ARGeometryElement) -> [UInt32] {
            let indexCountPerFace = faces.indexCountPerPrimitive
            let bytesPerFace = indexCountPerFace * faces.bytesPerIndex
            let faceStart = faces.buffer.contents().advanced(by: faceIndex * bytesPerFace)

            return (0 ..< indexCountPerFace).map { indexOffset in
                let pointer = faceStart.advanced(by: indexOffset * faces.bytesPerIndex)
                switch faces.bytesPerIndex {
                case 2:
                    return UInt32(pointer.assumingMemoryBound(to: UInt16.self).pointee)
                case 4:
                    return pointer.assumingMemoryBound(to: UInt32.self).pointee
                default:
                    return UInt32(pointer.assumingMemoryBound(to: UInt8.self).pointee)
                }
            }
        }

        private func classificationOf(faceWithIndex faceIndex: Int, source: ARGeometrySource) -> ARMeshClassification {
            let offset = source.offset + faceIndex * source.stride
            let pointer = source.buffer.contents().advanced(by: offset)

            switch source.format {
            case .uchar:
                return ARMeshClassification(rawValue: Int(pointer.assumingMemoryBound(to: UInt8.self).pointee)) ?? .none
            case .ushort:
                return ARMeshClassification(rawValue: Int(pointer.assumingMemoryBound(to: UInt16.self).pointee)) ?? .none
            case .uint:
                return ARMeshClassification(rawValue: Int(pointer.assumingMemoryBound(to: UInt32.self).pointee)) ?? .none
            default:
                return .none
            }
        }

        private func wallMaterial() -> SCNMaterial {
            let material = SCNMaterial()
            material.diffuse.contents = overlayColor
            material.emission.contents = overlayColor
            material.isDoubleSided = true
            material.lightingModel = .constant
            material.transparency = 0.9
            material.fillMode = .fill
            material.blendMode = .add
            return material
        }

        private func makeDepthImage(from frame: ARFrame) -> UIImage? {
            guard let sceneView,
                  let sceneDepth = frame.sceneDepth else {
                return nil
            }

            let depthMap = sceneDepth.depthMap
            let colorImage = depthColorImage(from: depthMap)
            let alignedImage = alignedDepthImage(colorImage, for: frame, viewportSize: sceneView.bounds.size)
            guard let cgImage = ciContext.createCGImage(alignedImage, from: alignedImage.extent) else {
                return nil
            }

            return UIImage(cgImage: cgImage)
        }

        private func alignedDepthImage(_ image: CIImage, for frame: ARFrame, viewportSize: CGSize) -> CIImage {
            guard viewportSize.width > 0, viewportSize.height > 0 else {
                return image
            }

            let orientation = sceneView?.window?.windowScene?.interfaceOrientation ?? .portrait
            let displayTransform = frame.displayTransform(for: orientation, viewportSize: viewportSize)
            let normalize = CGAffineTransform(scaleX: 1.0 / image.extent.width, y: 1.0 / image.extent.height)
            let denormalize = CGAffineTransform(scaleX: viewportSize.width, y: viewportSize.height)
            let verticalFlip = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -viewportSize.height)
            let horizontalFlip = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -viewportSize.width, y: 0)

            return image
                .transformed(by: normalize)
                .transformed(by: displayTransform)
                .transformed(by: denormalize)
                .transformed(by: verticalFlip)
                .transformed(by: horizontalFlip)
                .cropped(to: CGRect(origin: .zero, size: viewportSize))
        }

        private func depthColorImage(from depthMap: CVPixelBuffer) -> CIImage {
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            let rowStride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.stride
            let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!.assumingMemoryBound(to: Float32.self)

            var minDepth = Float.greatestFiniteMagnitude
            var maxDepth: Float = 0.0

            for y in 0 ..< height {
                let row = baseAddress.advanced(by: y * rowStride)
                for x in 0 ..< width {
                    let depth = row[x]
                    guard depth.isFinite, depth > 0 else { continue }
                    minDepth = min(minDepth, depth)
                    maxDepth = max(maxDepth, depth)
                }
            }

            if !minDepth.isFinite || maxDepth <= minDepth {
                return CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
            }

            let pixelCount = width * height
            var rgba = [UInt8](repeating: 0, count: pixelCount * 4)

            for y in 0 ..< height {
                let row = baseAddress.advanced(by: y * rowStride)
                for x in 0 ..< width {
                    let depth = row[x]
                    let outputIndex = (y * width + x) * 4
                    guard depth.isFinite, depth > minimumRenderableDepth else {
                        rgba[outputIndex + 3] = 0
                        continue
                    }

                    let normalized = max(0, min(1, (depth - minDepth) / (maxDepth - minDepth)))
                    let hue = CGFloat(0.72 - 0.72 * normalized)
                    let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)

                    var red: CGFloat = 0
                    var green: CGFloat = 0
                    var blue: CGFloat = 0
                    var alpha: CGFloat = 0
                    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

                    rgba[outputIndex] = UInt8(red * 255)
                    rgba[outputIndex + 1] = UInt8(green * 255)
                    rgba[outputIndex + 2] = UInt8(blue * 255)
                    rgba[outputIndex + 3] = 220
                }
            }

            let data = Data(rgba)
            return CIImage(bitmapData: data,
                           bytesPerRow: width * 4,
                           size: CGSize(width: width, height: height),
                           format: .RGBA8,
                           colorSpace: CGColorSpaceCreateDeviceRGB())
        }
    }

    private func makePlaceholderView(text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .title3)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        let view = UIView(frame: .zero)
        view.backgroundColor = .systemBackground
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        return view
    }
}

private extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        let stride = vertices.stride
        let offset = vertices.offset + stride * Int(index)
        let pointer = vertices.buffer.contents().advanced(by: offset)
        return pointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
    }
}
