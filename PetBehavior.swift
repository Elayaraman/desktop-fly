// Explicit pet rules, not recovered neural function or MN9 feeding physiology.
// Mirrored by windows/src/pet.js. The neural simulation keeps running.
import Cocoa
import SceneKit

struct PetIntent {
    let target: CGPoint
    let stopRadius: CGFloat
    let feeding: Bool
}

struct SugarDrop {
    let id: Int
    let position: CGPoint
    var remaining: CGFloat = 1
    var age: CGFloat = 0
}

final class PetBehavior {
    var followCursor = true
    private(set) var sugar: [SugarDrop] = []
    private(set) var meals = 0
    private(set) var status = "Following cursor"
    private var nextID = 0
    static let feedingRadius: CGFloat = 22

    func clearSugar() { sugar.removeAll() }

    func dropSugar(at point: CGPoint, bounds: CGSize) {
        guard point.x.isFinite, point.y.isFinite else { return }
        let hw = max(0, bounds.width / 2 - 70), hh = max(0, bounds.height / 2 - 70)
        let p = CGPoint(x: clampf(point.x, -hw, hw), y: clampf(point.y, -hh, hh))
        if sugar.count >= 5 { sugar.removeFirst() }
        sugar.append(SugarDrop(id: nextID, position: p))
        nextID += 1
    }

    func gentleCursor(speed: CGFloat, distance: CGFloat) -> Bool {
        (followCursor || !sugar.isEmpty) && (speed < 60 || (speed < 350 && distance > 80))
    }

    func step(dt: CGFloat, fly: Fly, mouse: CGPoint?, cursorSpeed: CGFloat,
              signals: BrainSignals?) -> PetIntent? {
        for i in sugar.indices { sugar[i].age += dt }
        sugar.removeAll { $0.age >= 180 || $0.remaining <= 0 }
        guard let s = signals else { status = "Neural data unavailable"; return nil }
        // Escape, sleep and ongoing recovery always take priority over pet rules.
        guard fly.state != .flying, !s.escape, s.nervous < 0.4, !s.sleep,
              fly.scareCooldown <= 0, fly.dartTimer <= 0, fly.backwardTimer <= 0 else {
            status = s.sleep ? "Sleeping" : "Startled / recovering"
            return nil
        }
        if let i = sugar.indices.min(by: {
            distance(sugar[$0].position, fly.pos) < distance(sugar[$1].position, fly.pos)
        }) {
            let p = sugar[i].position
            let eating = distance(p, fly.pos) <= Self.feedingRadius
            if eating {
                sugar[i].remaining = max(0, sugar[i].remaining - dt / 4)
                if sugar[i].remaining <= 0 {
                    sugar.remove(at: i)
                    meals += 1
                }
            }
            status = eating ? "Eating sugar" : "Going to sugar"
            return PetIntent(target: p, stopRadius: Self.feedingRadius, feeding: eating)
        }
        guard followCursor, let mouse, cursorSpeed < 350 else {
            status = followCursor ? "Waiting for a gentle cursor" : "Natural behavior"
            return nil
        }
        status = distance(mouse, fly.pos) <= 150 ? "Waiting by cursor" : "Following cursor"
        return PetIntent(target: mouse, stopRadius: 150, feeding: false)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }
}

// Graphics only: five small sugar cubes, shrinking as their portions are eaten.
final class SugarRenderer {
    private var nodes: [Int: SCNNode] = [:]
    func sync(_ drops: [SugarDrop], in scene: SCNScene) {
        let ids = Set(drops.map(\.id))
        for id in Array(nodes.keys) where !ids.contains(id) {
            nodes.removeValue(forKey: id)?.removeFromParentNode()
        }
        for drop in drops {
            let node: SCNNode
            if let existing = nodes[drop.id] { node = existing }
            else {
                node = SCNNode()
                let halo = SCNSphere(radius: 17)
                halo.firstMaterial?.diffuse.contents = NSColor.systemOrange.withAlphaComponent(0.22)
                halo.firstMaterial?.lightingModel = .constant
                let base = SCNNode(geometry: halo)
                base.scale = SCNVector3(1, 1, 0.025)
                node.addChildNode(base)
                let cube = SCNBox(width: 12, height: 12, length: 5, chamferRadius: 2)
                cube.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 1, green: 0.86, blue: 0.49, alpha: 1)
                cube.firstMaterial?.emission.contents = NSColor(calibratedWhite: 0.12, alpha: 1)
                let sweet = SCNNode(geometry: cube)
                sweet.position.z = 3
                sweet.eulerAngles.z = .pi / 4
                node.addChildNode(sweet)
                nodes[drop.id] = node
                scene.rootNode.addChildNode(node)
            }
            node.position = SCNVector3(drop.position.x, drop.position.y, 0)
            let scale = 0.4 + 0.6 * drop.remaining
            node.scale = SCNVector3(scale, scale, scale)
        }
    }
}

final class FlyOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { !ignoresMouseEvents }
}

final class SugarPlacementView: SCNView {
    var onSugar: ((CGPoint) -> Void)?
    var onCancel: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        onSugar?(CGPoint(x: p.x - bounds.midX, y: p.y - bounds.midY))
    }
    override func rightMouseDown(with event: NSEvent) { onCancel?() }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() }
        else { super.keyDown(with: event) }
    }
}
