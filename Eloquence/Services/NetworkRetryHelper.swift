//
//  NetworkRetryHelper.swift
//  Eloquence
//
//  Service for handling network retries with exponential backoff
//

import Foundation

/// Actor-based helper for retrying network operations with exponential backoff
actor NetworkRetryHelper {

    /// Executes an async operation with automatic retry logic for transient failures
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: The last error if all retry attempts fail, or the original error if not retryable
    func withRetry<T>(
        maxAttempts: Int = 3,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as AzureAPIError where error.isRetryable {
                lastError = error
                print("⚠️ Network error (attempt \(attempt)/\(maxAttempts)): \(error)")

                // Don't sleep after the last attempt
                if attempt < maxAttempts {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = pow(2.0, Double(attempt - 1))
                    print("⏳ Retrying in \(Int(delay))s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                // Non-retryable errors fail immediately
                throw error
            }
        }

        // All retry attempts exhausted
        throw lastError!
    }

    /// Executes multiple async operations in parallel with retry logic
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts per operation
    ///   - operations: Array of async operations to execute
    /// - Returns: Array of results in the same order as operations
    /// - Throws: The first error encountered if all retry attempts fail
    func withRetryParallel<T>(
        maxAttempts: Int = 3,
        operations: [@Sendable () async throws -> T]
    ) async throws -> [T] {
        try await withThrowingTaskGroup(of: (Int, T).self) { group in
            for (index, operation) in operations.enumerated() {
                group.addTask {
                    let result = try await self.withRetry(maxAttempts: maxAttempts, operation: operation)
                    return (index, result)
                }
            }

            // Collect results and sort by original index
            var results: [(Int, T)] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }
}
