import Foundation
import KeyboardCore

@MainActor
final class ConversionCoordinator {
    struct Output {
        let requestID: UInt64
        let snapshot: String
        let conversion: InputController.LiveConversion
        let elapsedMs: Double
        let cacheHit: Bool
    }

    private struct CacheKey: Equatable {
        var raw: String
        var leftSideContext: String
        var documentPrior: LanguagePrior
    }

    private var nextRequestID: UInt64 = 0
    private let queue = DispatchQueue(label: "com.bilingual.keyboard.conversion", qos: .userInitiated)
    private var workItem: DispatchWorkItem?
    private var cachedKey: CacheKey?
    private var cachedConversion: InputController.LiveConversion?

    var latestRequestID: UInt64 { nextRequestID }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }

    func cachedConversion(raw: String, leftSideContext: String, documentPrior: LanguagePrior) -> InputController.LiveConversion? {
        let key = CacheKey(raw: raw, leftSideContext: leftSideContext, documentPrior: documentPrior)
        guard key == cachedKey else { return nil }
        return cachedConversion
    }

    func store(_ conversion: InputController.LiveConversion, leftSideContext: String, documentPrior: LanguagePrior) {
        cachedKey = CacheKey(raw: conversion.raw, leftSideContext: leftSideContext, documentPrior: documentPrior)
        cachedConversion = conversion
    }

    func schedule(
        snapshot: String,
        leftSideContext: String,
        documentPrior: LanguagePrior,
        debounceNanoseconds: UInt64 = 30_000_000,
        convert: @escaping () -> InputController.LiveConversion,
        apply: @escaping (Output) -> Void
    ) -> UInt64 {
        cancel()
        nextRequestID += 1
        let requestID = nextRequestID
        let key = CacheKey(raw: snapshot, leftSideContext: leftSideContext, documentPrior: documentPrior)

        if key == cachedKey, let cachedConversion {
            workItem = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
                apply(Output(
                    requestID: requestID,
                    snapshot: snapshot,
                    conversion: cachedConversion,
                    elapsedMs: 0,
                    cacheHit: true
                ))
            }
            return requestID
        }

        var item: DispatchWorkItem!
        item = DispatchWorkItem { [weak self] in
            guard item.isCancelled == false else { return }
            let start = DispatchTime.now().uptimeNanoseconds
            let conversion = convert()
            let end = DispatchTime.now().uptimeNanoseconds
            guard item.isCancelled == false else { return }
            let output = Output(
                requestID: requestID,
                snapshot: snapshot,
                conversion: conversion,
                elapsedMs: Double(end - start) / 1_000_000,
                cacheHit: false
            )
            Task { @MainActor [weak self] in
                guard let self, item.isCancelled == false else { return }
                self.cachedKey = key
                self.cachedConversion = conversion
                apply(output)
            }
        }
        workItem = item
        queue.asyncAfter(deadline: .now() + .nanoseconds(Int(debounceNanoseconds)), execute: item)
        return requestID
    }
}
