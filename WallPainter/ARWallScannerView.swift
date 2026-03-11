import ARKit
import SceneKit
import SwiftUI

struct ARWallScannerView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARSCNView {
        let sceneView = ARSCNView(frame: .zero)
        sceneView.delegate = context.coordinator
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.scene = SCNScene()
        sceneView.debugOptions = []

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }

        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return sceneView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSCNViewDelegate {
        private let overlayColor = UIColor.systemTeal.withAlphaComponent(0.45)

        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
                return nil
            }

            return makeWallNode(for: planeAnchor)
        }

        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
                return
            }

            updateWallNode(node, for: planeAnchor)
        }

        private func makeWallNode(for anchor: ARPlaneAnchor) -> SCNNode {
            let plane = SCNPlane(width: max(CGFloat(anchor.extent.x), 0.05),
                                 height: max(CGFloat(anchor.extent.z), 0.05))
            plane.cornerRadius = 0.02
            plane.firstMaterial?.diffuse.contents = overlayColor
            plane.firstMaterial?.isDoubleSided = true
            plane.firstMaterial?.lightingModel = .physicallyBased

            let planeNode = SCNNode(geometry: plane)
            planeNode.simdPosition = SIMD3(anchor.center.x, anchor.center.y, anchor.center.z)
            planeNode.renderingOrder = 100

            let container = SCNNode()
            container.addChildNode(planeNode)
            return container
        }

        private func updateWallNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
            guard let planeNode = node.childNodes.first,
                  let plane = planeNode.geometry as? SCNPlane else {
                return
            }

            plane.width = max(CGFloat(anchor.extent.x), 0.05)
            plane.height = max(CGFloat(anchor.extent.z), 0.05)
            planeNode.simdPosition = SIMD3(anchor.center.x, anchor.center.y, anchor.center.z)
        }
    }
}
