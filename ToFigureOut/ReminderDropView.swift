//
//  ReminderDropView.swift
//  ToFigureOut
//
//  Created by Kai Quan Tay on 20/7/23.
//

import SwiftUI
import EventKit

struct ReminderDropView: View {
    @ObservedObject
    var reminderManager = ReminderManager.shared

    @State
    var prototypeReminder: EKReminder? = nil

    @State
    var targetReminder: EKReminder? = nil

    var body: some View {
        VStack {
            VStack {
                Image(systemName: prototypeReminder == nil ? "square.dotted" : "square.dashed")
                    .resizable()
                    .frame(width: 100, height: 100)
                Text(prototypeReminder?.title ?? " ")
                    .padding(10)
            }
            .padding(20)
            Text("Drop your reminders here")
                .font(.title)
        }
        .padding()
        .frame(width: 400, height: 300)
        .onDrop(of: [.plainText], delegate: ReminderDropDelegate(prototypeReminder: $prototypeReminder, targetReminder: $targetReminder))
        .task {
            if await reminderManager.requestAccess() {
                reminderManager.fetchReminders()
            }
        }
        .sheet(item: $targetReminder) { reminder in
            ConfigureReminderView(reminder: reminder)
                .frame(width: 350, height: 250)
        }
    }
}

let store = EKEventStore()
class ReminderDropDelegate: DropDelegate {
    @Binding
    var prototypeReminder: EKReminder?

    @Binding
    var targetReminder: EKReminder?

    init(prototypeReminder: Binding<EKReminder?>, targetReminder: Binding<EKReminder?>) {
        self._prototypeReminder = prototypeReminder
        self._targetReminder = targetReminder
    }

    func dropEntered(info: DropInfo) {
        Task {
            guard let reminder = await reminderForDropInfo(info: info) else { return }
            print("Reminder entered: \(reminder.calendarItemIdentifier)")
            prototypeReminder = reminder
        }
    }

    func dropExited(info: DropInfo) {
        Task {
            guard let reminder = await reminderForDropInfo(info: info) else { return }
            print("Reminder exited: \(reminder.calendarItemIdentifier)")
            prototypeReminder = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        Task {
            guard let reminder = await reminderForDropInfo(info: info) else { return }
            print("Reminder: \(reminder.calendarItemIdentifier)")
            targetReminder = reminder
        }
        return true
    }

    func reminderForDropInfo(info: DropInfo) async -> EKReminder? {
        guard let title = try? await stringValueForDropInfo(info: info) else { return nil }
        return reminderForTitle(title: title)
    }

    func reminderForTitle(title: String) -> EKReminder? {
        ReminderManager.shared.reminders.first(where: { $0.title == title })
    }

    func stringValueForDropInfo(info: DropInfo) async throws -> String? {
        guard let provider = info.itemProviders(for: [.plainText]).first else { return nil }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String?, Error>) in
            _ = provider.loadDataRepresentation(for: .plainText) { data, error in
                if let error {
                    print("ERROR: \(error.localizedDescription)")
                    cont.resume(throwing: error)
                }
                // get the title, aka the first line
                guard let data,
                      let stringValue = String(data: data, encoding: .utf8),
                      let title = stringValue.split(separator: "\n").first else {
                    print("Could not get information")
                    cont.resume(returning: nil)
                    return
                }
                print("Reminder title: \(title)")
                cont.resume(returning: String(title))
            }
        }
    }
}

extension EKReminder: Identifiable {
    public var id: String { self.calendarItemIdentifier }
}

#Preview {
    ReminderDropView()
}
