//
//  BuiltInAIService.swift
//  Easydict
//
//  Created by tisfeng on 2024/4/13.
//  Copyright © 2024 izual. All rights reserved.
//

import Defaults
import Foundation

// MARK: - BuiltInAIService

@objc(EZBuiltInAIService)
class BuiltInAIService: BaseOpenAIService {
    // MARK: Lifecycle

    required init() {
        super.init()

        // Set default supported models, disable user to change it.
        // Generally, it should be updated only when the app is updated.
        supportedModels = defaultModels.joined(separator: ", ")
    }

    // MARK: Public

    public override func name() -> String {
        NSLocalizedString("built_in_ai", comment: "")
    }

    public override func serviceType() -> ServiceType {
        .builtInAI
    }

    public override func apiKeyRequirement() -> ServiceAPIKeyRequirement {
        .builtIn
    }

    public override func configurationListItems() -> Any {
        StreamConfigurationView(
            service: self,
            showAPIKeySection: false,
            showEndpointSection: false
        )
    }

    // MARK: Internal

    override var defaultModels: [String] {
        [
            BuiltInAIModel.glm45Flash.rawValue,
            BuiltInAIModel.glm4Flash250414.rawValue,
            BuiltInAIModel.llama318bInstant.rawValue,
        ]
    }

    override var defaultModel: String {
        BuiltInAIModel.glm4Flash250414.rawValue
    }

    override var canFetchRemoteModels: Bool {
        false
    }

    override var apiKey: String {
        builtInAIAPIKey
    }

    override var endpoint: String {
        builtInAIEndpoint
    }

    override var observeKeys: [Defaults.Key<String>] {
        [supportedModelsKey]
    }
}

// MARK: - BuiltInAIModel

/// Model identifiers served by the built-in AI gateway.
private enum BuiltInAIModel: String {
    case glm45Flash = "glm-4.5-flash"
    case glm4Flash250414 = "glm-4-flash-250414"
    case llama318bInstant = "llama-3.1-8b-instant"
}
