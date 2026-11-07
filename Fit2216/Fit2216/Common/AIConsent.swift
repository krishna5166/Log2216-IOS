import Foundation

/// The wording shown wherever the person is asked to allow AI meal calculation. It names every service the server may use
/// (Google Gemini first; Groq or NVIDIA when Gemini is busy or fails), because the App Store requires saying who receives the data.
enum AIConsentText {
    static let summary = "Calculating a meal uses AI. When you tap Add meal, the text you wrote is sent through the Fit2216 server to an AI service (Google Gemini; if it is busy, Groq or NVIDIA) to estimate calories and macros. Nothing else is sent."
}
