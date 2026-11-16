import FanBarShared

/// Whether the panel can start a switch that takes the fans from macOS.
///
/// When macOS stops a fan, the SMC reports `F%dSt` = 2 until the fan has run down,
/// and only then 3 (stopped). A fan in state 2 does not start again before that,
/// even with a new target, and the SMC accepts manual mode only from a running fan.
/// The helper gives that takeover 10 s, so a switch started while a fan runs down
/// fails and hands the fans back. Measured on a Mac16,7 (M4 Pro, macOS 27.2.1):
/// state 2 lasts about 11 s after macOS stops the fans from 1,350 RPM, and a
/// takeover from state 3 takes 7–8 s. Quitting FanBar hands the fans back, so this
/// state follows every restart while the Mac is cool.
enum ModeSwitchReadiness {
    /// `F%dSt` while a stopped fan runs down.
    static let spinningDownState: UInt8 = 2

    /// True while macOS drives the fans and at least one of them runs down.
    /// Macs without `F%dSt` never wait.
    static func mustWait(macOSInControl: Bool, fans: [FanReading]) -> Bool {
        macOSInControl && fans.contains { $0.spinState == spinningDownState }
    }

    /// Only a retry that takes the fans waits; handing them back to macOS
    /// and the helper or sensor fixes stay available.
    static func locks(_ recovery: FanController.ModeActionFeedback.Recovery, whileWaiting waiting: Bool) -> Bool {
        guard waiting, case .retry(let target) = recovery else { return false }
        return target != .restore
    }

    /// The line beside the spinner: a request in flight first, then the wait.
    static func progressMessage(inProgress: String?, waiting: Bool) -> String? {
        inProgress ?? (waiting ? waitingMessage : nil)
    }

    static var waitingMessage: String {
        fanBarText("风扇正在停转，稍后可切换模式…", "Fans are spinning down. Modes unlock shortly…")
    }
}

extension FanController {
    /// The mode strip waits while a fan runs down; see `ModeSwitchReadiness`.
    var mustWaitForFansToSpinDown: Bool {
        ModeSwitchReadiness.mustWait(macOSInControl: mode == .automatic, fans: fans)
    }
}
