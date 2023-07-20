//
//  ReminderManager.swift
//  ToFigureOut
//
//  Created by Kai Quan Tay on 20/7/23.
//

import Foundation
import EventKit

class ReminderManager: ObservableObject {
    static var shared: ReminderManager = .init()

    @Published
    var reminders: [EKReminder] = []

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(fetchReminders), name: .EKEventStoreChanged, object: store)
    }

    func requestAccess() async -> Bool {
        do {
            let success = try await store.requestFullAccessToReminders()
            return success
        } catch {
            print("ERROR :(")
            return false
        }
    }

    @objc
    func fetchReminders() {
        store.fetchReminders(matching: store.predicateForReminders(in: nil)) { allReminders in
            guard let allReminders else {
                print("No reminders :(")
                return
            }

            let reminders = allReminders.filter({ !$0.isCompleted })
            DispatchQueue.main.async {
                self.reminders = reminders
            }
        }
    }
}
