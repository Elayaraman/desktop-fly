import Cocoa
import SceneKit

func runPetTests() -> Bool {
    var failures = 0
    func check(_ name: String, _ passed: Bool) {
        print("\(passed ? "PASS" : "FAIL") \(name)")
        if !passed { failures += 1 }
    }
    let bounds = CGSize(width: 1280, height: 800)
    let dt: CGFloat = 1 / 120
    func pair() -> (PetBehavior, Fly) {
        TestRandom.reset("pet-tests")
        let fly = Fly(at: CGPoint(x: -240, y: 0))
        fly.heading = 0; fly.state = .idle
        return (PetBehavior(), fly)
    }
    func run(_ pet: PetBehavior, _ fly: Fly, ticks: Int, mouse: CGPoint?, s: BrainSignals = BrainSignals()) {
        for _ in 0..<ticks {
            let intent = pet.step(dt: dt, fly: fly, mouse: mouse, cursorSpeed: 0, signals: s)
            fly.update(dt: dt, bounds: bounds, mouse: mouse, signals: s, petIntent: intent)
        }
    }
    do {
        let (pet, fly) = pair()
        let mouse = CGPoint(x: 300, y: 0)
        run(pet, fly, ticks: 1200, mouse: mouse)
        let d = hypot(mouse.x - fly.pos.x, mouse.y - fly.pos.y)
        check("gentle cursor is approached and respected at 150pt", d > 140 && d <= 151)
        pet.followCursor = false
        check("follow off yields control to neural behavior", pet.step(dt: dt, fly: fly, mouse: mouse,
            cursorSpeed: 0, signals: BrainSignals()) == nil)
        pet.followCursor = true
        check("fast cursor is not pursued", pet.step(dt: dt, fly: fly, mouse: mouse,
            cursorSpeed: 800, signals: BrainSignals()) == nil)
        check("stationary cursor is friendly; fast cursor remains a threat",
              pet.gentleCursor(speed: 0, distance: 20) && !pet.gentleCursor(speed: 900, distance: 100))
    }
    do {
        let (pet, fly) = pair()
        pet.dropSugar(at: CGPoint(x: 80, y: 0), bounds: bounds)
        run(pet, fly, ticks: 120, mouse: CGPoint(x: -400, y: 0))
        check("sugar takes priority and is not consumed at a distance", fly.pos.x > -240 && pet.sugar[0].remaining == 1)
        run(pet, fly, ticks: 1200, mouse: nil)
        check("fly reaches sugar and finishes exactly one portion", pet.sugar.isEmpty && pet.meals == 1)
        check("feeding finishes near the sugar, without teleportation", hypot(fly.pos.x - 80, fly.pos.y) < 23)
    }
    do {
        let (pet, fly) = pair()
        pet.dropSugar(at: fly.pos, bounds: bounds)
        run(pet, fly, ticks: 60, mouse: nil)
        let remaining = pet.sugar[0].remaining
        var threat = BrainSignals(); threat.escape = true
        run(pet, fly, ticks: 1, mouse: CGPoint(x: -200, y: 0), s: threat)
        check("escape interrupts feeding immediately", fly.state == .flying && pet.sugar[0].remaining == remaining)
        run(pet, fly, ticks: 10, mouse: nil)
        check("food is not consumed in flight", pet.sugar[0].remaining == remaining)
        fly.state = .idle; fly.scareCooldown = 0
        var sleep = BrainSignals(); sleep.sleep = true
        run(pet, fly, ticks: 10, mouse: nil, s: sleep)
        check("sleep also interrupts feeding", fly.state == .sleeping && pet.sugar[0].remaining == remaining)
    }
    do {
        let (pet, fly) = pair()
        for _ in 0..<9 { pet.dropSugar(at: CGPoint(x: 9000, y: -9000), bounds: bounds) }
        check("food is bounded to five visible drops", pet.sugar.count == 5 && pet.sugar.allSatisfy {
            $0.position.x <= 570 && $0.position.y >= -330
        })
        pet.dropSugar(at: CGPoint(x: CGFloat.nan, y: 0), bounds: bounds)
        check("invalid coordinates cannot corrupt food state", pet.sugar.count == 5)
        _ = pet.step(dt: 180, fly: fly, mouse: nil, cursorSpeed: 0, signals: BrainSignals())
        check("old food expires", pet.sugar.isEmpty)
        pet.dropSugar(at: .zero, bounds: bounds); pet.clearSugar()
        check("clear removes all food", pet.sugar.isEmpty)
    }
    if let data = loadBrainData() {
        let (pet, fly) = pair()
        let sim = LIFSim(circuit: data.circuit, spikeBus: nil, locomotorCircuit: data.locomotor)
        let builder = SignalBuilder()
        var ms: Double = 0
        pet.dropSugar(at: .zero, bounds: bounds)
        for _ in 0..<1440 {
            sim.legFeedback = fly.legFeedback
            ms += Double(dt) * 1000
            let steps = Int(ms + 1e-6); ms -= Double(steps)
            sim.step(steps)
            let s = builder.make(sim, dt: dt)
            let intent = pet.step(dt: dt, fly: fly, mouse: nil, cursorSpeed: 0, signals: s)
            fly.update(dt: dt, bounds: bounds, mouse: nil, signals: s, petIntent: intent)
        }
        check("feeding completes while the real circuits continue running", pet.meals == 1 && sim.ratePop > 0)

        func coordinator() -> Coordinator {
            TestRandom.reset("pet-coordinator")
            let engine = LIFSim(circuit: data.circuit, spikeBus: nil, locomotorCircuit: data.locomotor)
            let c = Coordinator(bounds: bounds, sim: engine)
            c.enqueue { c in c.flies[0].pos = CGPoint(x: -240, y: 0); c.flies[0].heading = 0; c.flies[0].state = .idle }
            c.setMouse(CGPoint(x: 300, y: 0))
            c.advanceFrame(at: 0)
            return c
        }
        let c = coordinator()
        for frame in 1...600 { c.advanceFrame(at: Double(frame) / 60) }
        check("live coordinator follows a stationary cursor", hypot(c.flies[0].pos.x - 300, c.flies[0].pos.y) < 151)
        let p = c.flies[0].pos
        c.setMouse(CGPoint(x: p.x + 8, y: p.y))
        var escaped = false
        for frame in 601...610 {
            c.advanceFrame(at: Double(frame) / 60)
            escaped = escaped || c.flies[0].state == .flying
        }
        check("a sudden cursor jab reaches the neural escape pathway", escaped)
        c.setPaused(true); c.advanceFrame(at: 11)
        let pausedPosition = c.flies[0].pos
        for frame in 661...720 { c.advanceFrame(at: Double(frame) / 60) }
        check("pause freezes pet movement", c.flies[0].pos == pausedPosition)
        c.dropSugar(at: .zero); c.advanceFrame(at: 12.1)
        c.retarget(size: CGSize(width: 800, height: 600)); c.advanceFrame(at: 12.2)
        check("display changes discard old food coordinates", c.pet.sugar.isEmpty)

        let low = coordinator()
        for frame in 1...300 { low.advanceFrame(at: Double(frame) / 30) }
        let lowPosition = low.flies[0].pos
        let high = coordinator()
        for frame in 1...600 { high.advanceFrame(at: Double(frame) / 60) }
        check("pet loop agrees at 30 and 60 render fps", hypot(lowPosition.x - high.flies[0].pos.x,
                                                            lowPosition.y - high.flies[0].pos.y) < 0.001)
    } else { check("bundled neural data loads", false) }
    print(failures == 0 ? "ALL PET TESTS PASS" : "\(failures) PET TESTS FAILED")
    return failures == 0
}
