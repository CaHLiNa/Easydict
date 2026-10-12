//
//  ActionManager.swift
//  Easydict
//
//  Created by tisfeng on 2025/8/29.
//  Copyright © 2025 izual. All rights reserved.
//

import AppKit
import Defaults
import Foundation
import SelectedTextKit

// MARK: - ActionManager

/// Singleton class responsible for handling various application actions
@objc(EZActionManager)
class ActionManager: NSObject {
    // MARK: Internal

    // MARK: - Singleton

    @objc static let shared = ActionManager()

    var translateService = BuiltInAIService()

    // MARK: - Text Field Detection and Access

    // MARK: - Public Methods

    /// Translate selected text and replace it with the translation result
    func translateAndReplace() async {
        logInfo("Translate and Replace")
        await executeTextReplacementAction()
    }

    // MARK: Private

    private let systemUtility = SystemUtility.shared

    // MARK: - Core Action Methods

    /// Common method to execute the text replacement action
    private func executeTextReplacementAction() async {
        let enableSelectAll = Defaults[.autoSelectAllTextFieldText]
        let elementInfo = await systemUtility.focusedElementInfo(enableSelectAll: enableSelectAll)

        // Prepare translation request
        var queryText = elementInfo.focusedText
        if queryText?.isEmpty ?? true {
            queryText = await systemUtility.getSelectedText()
        }

        guard let queryText, !queryText.isEmpty else {
            logInfo("No text selected or focused, skipping action")
            return
        }

        // Prepare translation request
        guard let request = await prepareTranslationRequest(queryText: queryText) else {
            return
        }

        // Execute the streaming service
        await performStreamingService(request: request, elementInfo: elementInfo)
    }

    // MARK: - Helper Methods

    /// Prepare translation request from text field information
    /// - Parameter queryText: Text selected or focused in the target application
    /// - Returns: A configured TranslationRequest or nil if preparation fails
    private func prepareTranslationRequest(queryText: String) async -> TranslationRequest? {
        // Detect language and target
        let queryModel = try? await DetectManager().detectText(queryText)
        guard let detectedLanguage = queryModel?.detectedLanguage,
              let targetLanguage = queryModel?.queryTargetLanguage
        else {
            logError("Failed to detect target language, skipping translate and replace")
            return nil
        }

        // Create base request
        return TranslationRequest(
            text: queryText,
            sourceLanguage: detectedLanguage.code,
            targetLanguage: targetLanguage.code,
            serviceType: translateService.serviceType().rawValue,
            queryType: .translation
        )
    }

    // MARK: - Streaming Service Methods

    /// Perform translation using a streaming service
    private func performStreamingService(
        request: TranslationRequest,
        elementInfo: FocusedElementInfo
    ) async {
        guard let service = QueryServiceFactory.shared.service(withTypeId: request.serviceType)
        else {
            logError("Service type \(request.serviceType) not found")
            return
        }

        guard let streamService = service as? StreamService else {
            logError("\(service.name()) does not support streaming")
            return
        }

        logInfo("Using model: \(streamService.model)")

        do {
            try Task.checkCancellation()
            let contentStream = try await streamService.contentStreamTranslate(request: request)
            try Task.checkCancellation()
            await replaceTextWithStream(contentStream, elementInfo: elementInfo)
        } catch {
            if Task.isCancelled {
                logInfo("Streaming task cancelled")
            } else {
                logError("stream failed: \(error.localizedDescription)")
            }
        }
    }

    /// Replace text with streaming data
    @MainActor
    private func replaceTextWithStream(
        _ contentStream: AsyncThrowingStream<String, Error>,
        elementInfo: FocusedElementInfo
    ) async {
        logInfo("Replacing text with streaming content")

        // For avoding polluting user pasteboard content, we need to save and restore it when AX is not supported.
        let pasteboard = NSPasteboard.general
        var snapshotItems: [NSPasteboardItem]?

        let isSupportedAX = elementInfo.isSupportedAXElement
        if !isSupportedAX {
            snapshotItems = pasteboard.backupItems()
        }

        do {
            let textStrategy = systemUtility.textStrategies(for: elementInfo)

            /**
             - Note:
             For GitHub web text area, if select all and insert empty string,
             it will clear the text area and lose focus.
             So we do not insert empty string.
             */

            var reuslt = ""
            for try await content in contentStream where !content.isEmpty {
                //                logInfo("Received streaming content chunk: \(content.prettyJSONString)")

                reuslt += content
                await systemUtility.insertText(content, using: textStrategy)
            }
            logInfo("Final replacement result: \(reuslt.prettyJSONString)")
        } catch {
            logError("Streaming replacement failed: \(error)")
        }

        if let snapshotItems, !isSupportedAX {
            pasteboard.restoreItems(snapshotItems)
        }
    }
}
