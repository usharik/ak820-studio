import Darwin
import Foundation

/// Live lighting needs 2–5 ms pauses between reports. With timer coalescing (App Nap, background
/// processes) `Thread.sleep(0.002)` can take 10–15 ms, which drops the frame rate to ~5 fps.
/// A time-constraint ("real-time") policy on the sending thread keeps the pauses precise.
public enum PreciseTiming {
    /// Runs `body` with a real-time scheduling policy on the current thread, then restores it.
    public static func run<T>(_ body: () throws -> T) rethrows -> T {
        let thread = pthread_mach_thread_np(pthread_self())
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        let abs = { (ms: Double) in UInt32(ms * 1_000_000 * Double(tb.denom) / Double(tb.numer)) }
        var policy = thread_time_constraint_policy_data_t(period: 0, computation: abs(2), constraint: abs(5), preemptible: 1)
        let count = mach_msg_type_number_t(MemoryLayout<thread_time_constraint_policy_data_t>.size / MemoryLayout<integer_t>.size)
        _ = withUnsafeMutablePointer(to: &policy) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                thread_policy_set(thread, thread_policy_flavor_t(THREAD_TIME_CONSTRAINT_POLICY), $0, count)
            }
        }
        defer {
            // Back to the default policy: the thread may belong to a GCD pool.
            var standard = thread_standard_policy_data_t()
            _ = withUnsafeMutablePointer(to: &standard) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_policy_set(thread, thread_policy_flavor_t(THREAD_STANDARD_POLICY), $0, 0)
                }
            }
        }
        return try body()
    }
}
