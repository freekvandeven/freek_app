import WidgetKit
import SwiftUI

// Reads task data saved by Flutter via home_widget (UserDefaults app group).
struct TasksEntry: TimelineEntry {
    let date: Date
    let content: String
    let count: Int
}

struct TasksProvider: TimelineProvider {
    let appGroupId = "group.nl.freekvandeven.personal_app"

    func placeholder(in context: Context) -> TasksEntry {
        TasksEntry(date: Date(), content: "• Buy groceries\n• Call dentist", count: 2)
    }

    func getSnapshot(in context: Context, completion: @escaping (TasksEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TasksEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry()], policy: .after(next)))
    }

    private func entry() -> TasksEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let content = defaults?.string(forKey: "tasks_content") ?? "No tasks due today"
        let count = defaults?.integer(forKey: "tasks_count") ?? 0
        return TasksEntry(date: Date(), content: content, count: count)
    }
}

struct TasksWidgetEntryView: View {
    var entry: TasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Tasks")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(entry.count) \(entry.count == 1 ? "task" : "tasks") due")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
            }
            Divider().background(Color.white.opacity(0.4))
            Text(entry.content)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(3)
                .lineLimit(5)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(red: 0.40, green: 0.31, blue: 0.64))
        .cornerRadius(16)
    }
}

@main
struct TasksWidget: Widget {
    let kind = "TasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasksProvider()) { entry in
            TasksWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Tasks")
        .description("Shows your tasks due today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
