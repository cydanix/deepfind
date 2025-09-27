import Foundation

/// A utility class for measuring time intervals in microseconds
public class TimeSpenter {
    private var startTime: UInt64
    
    /// Initialize the timer, recording the current time in microseconds
    public init() {
        startTime = DispatchTime.now().uptimeNanoseconds
    }

    public func reset() {
        startTime = DispatchTime.now().uptimeNanoseconds
    }

    /// Get the time delay in microseconds since initialization
    /// - Returns: Time delay in microseconds
    public func getDelay() -> UInt64 {
        let currentTime = DispatchTime.now().uptimeNanoseconds
        return (currentTime - startTime) / 1000 // Convert nanoseconds to microseconds
    }
}
