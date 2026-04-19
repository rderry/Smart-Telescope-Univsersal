import SwiftUI

struct FlexibleClockTimeField: View {
    let title: String
    @Binding var selection: Date
    var timeZone: TimeZone = .current
    var width: CGFloat = 180
    var labelColor: Color = .secondary
    var textColor: Color = .primary
    var helperColor: Color = .secondary
    var titleFont: Font = AppTypography.body
    var showsTitle = true
    var showsHelper = false

    @State private var timeText = ""
    @State private var meridiem = FlexibleClockMeridiem.am
    @State private var suppressNextSelectionSync = false
    @FocusState private var timeFieldFocused: Bool

    private var parsedTime: FlexibleClockTime? {
        Self.parseTime(timeText, meridiem: meridiem)
    }

    private var usesTwentyFourHourClock: Bool {
        Self.usesTwentyFourHourClock(timeText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if showsTitle {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(labelColor)
            }

            HStack(spacing: 8) {
                TextField("HH:MM", text: $timeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: min(94, width * 0.56))
                    .foregroundStyle(textColor)
                    .tint(textColor)
                    .focused($timeFieldFocused)
                    .onChange(of: timeText) { _, newValue in
                        let filtered = Self.sanitizedTimeInput(newValue)
                        if filtered != newValue {
                            timeText = filtered
                            return
                        }

                        applyTimeText()
                    }
                    .onChange(of: timeFieldFocused) { _, isFocused in
                        if !isFocused {
                            normalizeTimeText()
                        }
                    }

                Menu {
                    ForEach(FlexibleClockMeridiem.allCases) { option in
                        Button(option.rawValue) {
                            meridiem = option
                            applyTimeText()
                        }
                    }
                } label: {
                    Text(meridiem.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(usesTwentyFourHourClock ? Color.gray : textColor)
                        .frame(width: 48, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(usesTwentyFourHourClock)
                .opacity(usesTwentyFourHourClock ? 0.45 : 1)
            }
            .frame(width: width, alignment: .leading)

            if showsHelper {
                Text("24-hour entries ignore AM/PM.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(helperColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            syncFromSelection()
        }
        .onChange(of: selection) { _, _ in
            if suppressNextSelectionSync {
                suppressNextSelectionSync = false
                return
            }

            syncFromSelection()
        }
        .onChange(of: meridiem) { _, _ in
            guard !usesTwentyFourHourClock else { return }
            applyTimeText()
        }
    }

    private func applyTimeText() {
        guard let parsedTime else { return }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: selection)
        components.hour = parsedTime.hour24
        components.minute = parsedTime.minute
        components.second = 0
        components.nanosecond = 0

        guard let updatedDate = calendar.date(from: components) else { return }
        suppressNextSelectionSync = true
        selection = updatedDate
    }

    private func normalizeTimeText() {
        guard let parsedTime else {
            syncFromSelection()
            return
        }

        if parsedTime.usesTwentyFourHourClock {
            timeText = String(format: "%02d:%02d", parsedTime.hour24, parsedTime.minute)
        } else {
            timeText = String(format: "%02d:%02d", parsedTime.civilianHour, parsedTime.minute)
        }
    }

    private func syncFromSelection() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: selection)
        let hour24 = components.hour ?? 0
        let minute = components.minute ?? 0
        let civilianHour = hour24 % 12 == 0 ? 12 : hour24 % 12

        timeText = String(format: "%02d:%02d", civilianHour, minute)
        meridiem = hour24 < 12 ? .am : .pm
    }

    private static func sanitizedTimeInput(_ value: String) -> String {
        let filtered = value.filter { $0.isNumber || $0 == ":" }

        if filtered.contains(":") {
            let parts = filtered.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let hour = String(parts.first ?? "").prefix(2)
            let minute = parts.count > 1 ? String(parts[1].prefix(2)) : ""
            return "\(hour):\(minute)"
        }

        let digits = String(filtered.prefix(4))
        guard digits.count >= 2 else { return digits }

        let splitIndex = digits.index(digits.startIndex, offsetBy: hourDigitCount(for: digits))
        return "\(digits[..<splitIndex]):\(digits[splitIndex...])"
    }

    private static func parseTime(_ text: String, meridiem: FlexibleClockMeridiem) -> FlexibleClockTime? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parsed: (hour: Int, minute: Int)?
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else {
                return nil
            }
            parsed = (hour, minute)
        } else if let digits = Int(trimmed) {
            switch trimmed.count {
            case 1, 2:
                parsed = (digits, 0)
            case 3, 4:
                let hourDigits = hourDigitCount(for: trimmed)
                let hourText = String(trimmed.prefix(hourDigits))
                let minuteText = String(trimmed.dropFirst(hourDigits))
                guard let hour = Int(hourText), let minute = Int(minuteText) else { return nil }
                parsed = (hour, minute)
            default:
                parsed = nil
            }
        } else {
            parsed = nil
        }

        guard let parsed,
              (0 ... 23).contains(parsed.hour),
              (0 ... 59).contains(parsed.minute) else {
            return nil
        }

        if parsed.hour == 0 || parsed.hour > 12 {
            return FlexibleClockTime(
                hour24: parsed.hour,
                minute: parsed.minute,
                civilianHour: parsed.hour,
                usesTwentyFourHourClock: true
            )
        }

        let hour24: Int
        switch meridiem {
        case .am:
            hour24 = parsed.hour == 12 ? 0 : parsed.hour
        case .pm:
            hour24 = parsed.hour == 12 ? 12 : parsed.hour + 12
        }

        return FlexibleClockTime(
            hour24: hour24,
            minute: parsed.minute,
            civilianHour: parsed.hour,
            usesTwentyFourHourClock: false
        )
    }

    private static func usesTwentyFourHourClock(_ text: String) -> Bool {
        let parts = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let hourText = parts.first,
              let hour = Int(hourText),
              (0 ... 23).contains(hour) else {
            return false
        }

        return hour == 0 || hour > 12
    }

    private static func hourDigitCount(for digits: String) -> Int {
        guard digits.count >= 2 else { return digits.count }
        let firstTwoDigits = String(digits.prefix(2))
        if let firstTwoHour = Int(firstTwoDigits), firstTwoHour <= 23 {
            return 2
        }
        return 1
    }
}

struct FlexibleDateTimeField: View {
    let title: String
    @Binding var selection: Date
    var width: CGFloat = 270

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                DatePicker("", selection: $selection, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.field)
                    .frame(width: max(width - 118, 140), alignment: .leading)

                FlexibleClockTimeField(
                    title: "Time",
                    selection: $selection,
                    width: 110,
                    showsTitle: false
                )
            }
        }
    }
}

private enum FlexibleClockMeridiem: String, CaseIterable, Identifiable {
    case am = "AM"
    case pm = "PM"

    var id: String { rawValue }
}

private struct FlexibleClockTime {
    let hour24: Int
    let minute: Int
    let civilianHour: Int
    let usesTwentyFourHourClock: Bool
}
