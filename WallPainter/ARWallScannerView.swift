import ARKit
import SceneKit
import SwiftUI

struct ARWallScannerView: UIViewRepresentable {
    typealias UIViewType = UIView

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
        #endif
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        (uiView as? ARSCNView)?.session.pause()
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
