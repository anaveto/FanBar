import XCTest
@testable import FanBar

@MainActor
final class ModeSwitchReadinessTests: XCTestCase {
    private func fan(_ index: Int, spinState: UInt8?) -> FanReading {
        FanReading(
            index: index,
            minimumRPM: 1_350,
            currentRPM: 0,
            maximumRPM: 5_777,
            isManual: false,
            spinState: spinState
        )
    }

    func testSwitchWaitsWhileMacOSRunsAFanDown() {
        XCTAssertTrue(ModeSwitchReadiness.mustWait(macOSInControl: true, fans: [fan(0, spinState: 2)]))
        XCTAssertTrue(ModeSwitchReadiness.mustWait(
            macOSInControl: true,
            fans: [fan(0, spinState: 3), fan(1, spinState: 2)]
        ))
    }

    func testSwitchDoesNotWaitForRunningStartingOrStoppedFans() {
        for state: UInt8 in [1, 3, 5] {
            XCTAssertFalse(
                ModeSwitchReadiness.mustWait(macOSInControl: true, fans: [fan(0, spinState: state), fan(1, spinState: state)]),
                "F0St = \(state)"
            )
        }
    }

    func testMacsWithoutTheFanStateKeyNeverWait() {
        XCTAssertFalse(ModeSwitchReadiness.mustWait(macOSInControl: true, fans: [fan(0, spinState: nil)]))
        XCTAssertFalse(ModeSwitchReadiness.mustWait(macOSInControl: true, fans: []))
    }

    func testFanBarControlNeverWaits() {
        // The wait covers taking the fans from macOS only.
        XCTAssertFalse(ModeSwitchReadiness.mustWait(macOSInControl: false, fans: [fan(0, spinState: 2)]))
    }

    func testOnlyRetriesThatTakeTheFansWait() {
        typealias Recovery = FanController.ModeActionFeedback.Recovery
        let performance = CoolingPresetID.builtIn(.performance)
        XCTAssertTrue(ModeSwitchReadiness.locks(Recovery.retry(.preset(performance)), whileWaiting: true))
        XCTAssertTrue(ModeSwitchReadiness.locks(Recovery.retry(.fixed(3_000)), whileWaiting: true))
        XCTAssertFalse(ModeSwitchReadiness.locks(Recovery.retry(.restore), whileWaiting: true))
        XCTAssertFalse(ModeSwitchReadiness.locks(Recovery.openHelperSettings, whileWaiting: true))
        XCTAssertFalse(ModeSwitchReadiness.locks(Recovery.retry(.preset(performance)), whileWaiting: false))
    }

    func testProgressLineShowsARequestInFlightBeforeTheWait() {
        XCTAssertEqual(ModeSwitchReadiness.progressMessage(inProgress: "Switching…", waiting: true), "Switching…")
        XCTAssertEqual(
            ModeSwitchReadiness.progressMessage(inProgress: nil, waiting: true),
            ModeSwitchReadiness.waitingMessage
        )
        XCTAssertNil(ModeSwitchReadiness.progressMessage(inProgress: nil, waiting: false))
    }

    func testControllerWaitsWhileItsLatestReadingShowsAFanRunningDown() {
        let source = FakeFanReadingSource(readings: [fan(0, spinState: 5), fan(1, spinState: 5)])
        let controller = FanController(
            notificationCenter: nil,
            widgetSnapshotDestination: .disabled,
            makeReadingSource: { source }
        )
        controller.refresh()
        XCTAssertEqual(controller.mode, .automatic)
        XCTAssertFalse(controller.mustWaitForFansToSpinDown)

        source.readings = [fan(0, spinState: 2), fan(1, spinState: 2)]
        controller.refresh()
        XCTAssertTrue(controller.mustWaitForFansToSpinDown)

        source.readings = [fan(0, spinState: 3), fan(1, spinState: 3)]
        controller.refresh()
        XCTAssertFalse(controller.mustWaitForFansToSpinDown)
    }
}
