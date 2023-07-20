//
//  ConfigureReminderView.swift
//  ToFigureOut
//
//  Created by Kai Quan Tay on 20/7/23.
//

import SwiftUI
import EventKit
import ChatGPTSwift

struct ConfigureReminderView: View {
    var reminder: EKReminder

    @AppStorage("detailLevel") var detailLevel: Int = 3
    @AppStorage("gptAPIKey") var apiKey: String = ""

    @State var results: [String] = []
    @State var isLoading: Bool = false

    @State var showConfigureAPIKey: Bool = false

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        List {
            Section("Source Reminder") {
                HStack(alignment: .top) {
                    Text("Title")
                    Spacer()
                    Text(reminder.title)
                }
                .listRowSeparator(.hidden)
                if let notes = reminder.notes {
                    HStack(alignment: .top) {
                        Text("Notes")
                        Spacer()
                        Text(notes)
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                }
            }

            Section("Configuration") {
                Picker("Detail level", selection: $detailLevel) {
                    ForEach(1..<6) { level in
                        Text("\(level)")
                            .tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                HStack {
                    Spacer()
                    Button("Cancel", role: .cancel) { presentationMode.wrappedValue.dismiss() }
                    if apiKey.isEmpty {
                        Button("Add OpenAI Key") { showConfigureAPIKey = true }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Change OpenAI Key") { showConfigureAPIKey = true }
                            .buttonStyle(.bordered)
                    }
                    Button("Figure Out") { figureOutResults() }
                        .disabled(apiKey.isEmpty)
                    Spacer()
                }
                .sheet(isPresented: $showConfigureAPIKey) {
                    TextField("API key:", text: $apiKey)
                }
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }

            if !results.isEmpty {
                Section("Results") {
                    ForEach(Array(results.enumerated()), id: \.offset) { (_, result) in
                        Text(result)
                    }
                    HStack {
                        Spacer()
                        Button("Add to Reminders") {
                            commitNewReminders()
                            presentationMode.wrappedValue.dismiss()
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    func figureOutResults() {
        guard !apiKey.isEmpty, let title = reminder.title else { return }
        let api = ChatGPTAPI(apiKey: apiKey)
        api.deleteHistoryList()
        Task {
            let query =
"""
You will be given some text representing a single task that the user has to complete, an optional \
further description of the task, and the number of subtasks you should respond with. Your job is to \
respond with subtasks that the user can use to complete the specified task. Your response should \
contain the given number of subtasks. Your response should only contain the subtasks and nothing \
else. Each of the subtasks should be no longer than 6 words, as if the user was 5 years old, and \
on a new numbered line.

The single task is: \(title)
\(reminder.notes == nil ? "" : "The additional description is: \(reminder.notes!)")
The number of subtasks are: \(detailLevel * 4)
"""
            print("Prompt: \n\(query)")
            isLoading = true
            do {
                let resultString = try await api.sendMessage(text: query)
                processResultString(string: resultString)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
            isLoading = false
        }
    }

    func processResultString(string: String) {
        let lines = string.split(separator: "\n")
        // remove the leading number and space
        self.results = lines.compactMap { line -> String? in
            guard let startIndex = line.firstIndex(of: " ") else { return nil }
            return "\(line[line.index(after: startIndex)...])"
        }
    }

    func commitNewReminders() {
        let calendar = reminder.calendar

        do {
            for result in results {
                let newItem = EKReminder(eventStore: store)
                newItem.calendar = calendar
                newItem.title = result
                try store.save(newItem, commit: false)
            }
            try store.commit()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
}
