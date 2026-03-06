# UDP Server Architecture

## Continuation-Based Lifecycle Management

The `UDPServer` uses Swift Concurrency's `withCheckedThrowingContinuation` to manage the server lifecycle without polling.

### Design

1. **Property**: Store `stopContinuation: CheckedContinuation<Void, Error>?` on the actor
2. **start()**:
   - Set up the NWListener and register state/connection handlers
   - Call `listener.start(queue:)` to begin listening
   - Suspend via `withCheckedThrowingContinuation { continuation in self.stopContinuation = continuation }`
   - Function remains suspended until `stop()` resumes the continuation
3. **stop()**:
   - Set `shouldStop = true`
   - Cancel the listener
   - Resume `stopContinuation` to unblock `start()`

### Advantages Over Polling

- **No busy-wait**: Replaces the `while !shouldStop { try await Task.sleep(...) }` loop
- **Idiomatic**: Uses structured Swift Concurrency patterns
- **Efficient**: Server suspends until explicitly stopped, not polling every 100ms

### Implementation Notes

- The listener callbacks (`stateUpdateHandler`, `newConnectionHandler`) run on a background DispatchQueue
- The suspension point is purely for lifecycle management; packet processing happens in callbacks
- The continuation may be resumed with an error if `startupError` is set before stop

## Error Handling

The `.cancelled` case in `handleStateChange()` only calls `onError()` if the cancellation was unexpected:
- If `shouldStop == true`: normal stop, no error callback
- If `shouldStop == false`: unexpected cancellation, error callback fired
