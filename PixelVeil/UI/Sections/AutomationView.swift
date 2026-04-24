//
//  AutomationView.swift
//  Pixel Veil
//
//  Hosts App Rules (activate/deactivate based on frontmost app) and the
//  time-of-day Schedule. Rules editor uses NSOpenPanel to let the user pick
//  any .app bundle from /Applications or ~/Applications.
//

import AppKit
import SwiftUI

struct AutomationView: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        VStack(spacing: 16) {
            appRulesCard
            scheduleCard
        }
        .padding(.top, 16)
    }

    // MARK: Rules

    private var appRulesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App Rules")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Activate or deactivate Privacy Mode when specific apps are frontmost.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        addAppRule()
                    } label: {
                        Label("Add App…", systemImage: "plus")
                    }
                    .controlSize(.small)
                }

                Toggle("Only keep Privacy Mode on when an activating app is frontmost",
                       isOn: $settings.appRulesRestrictive)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))

                Divider()

                if settings.appRules.isEmpty {
                    Text("No rules yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 8) {
                        ForEach(settings.appRules) { rule in
                            ruleRow(rule)
                        }
                    }
                }
            }
        }
    }

    private func ruleRow(_ rule: AppRule) -> some View {
        let ruleBinding = Binding<AppRule>(
            get: { rule },
            set: { settings.addOrUpdateRule($0) }
        )
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "app.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.displayName)
                        .font(.system(size: 13, weight: .medium))
                    Text(rule.bundleIdentifier)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: ruleBinding.action) {
                    Text("Activate").tag(AppRuleAction.activate)
                    Text("Deactivate").tag(AppRuleAction.deactivate)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)

                Button {
                    settings.removeRule(id: rule.id)
                } label: {
                    Image(systemName: "minus.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Per-app overrides only apply to activate rules — deactivate turns
            // the overlay off, so strength / pattern are meaningless.
            if rule.action == .activate {
                perRuleOverrides(ruleBinding)
                    .padding(.leading, 34)
            }
        }
        .padding(.vertical, 4)
    }

    private func perRuleOverrides(_ rule: Binding<AppRule>) -> some View {
        let useStrength = Binding<Bool>(
            get: { rule.wrappedValue.strengthOverride != nil },
            set: { on in
                var r = rule.wrappedValue
                r.strengthOverride = on ? (r.strengthOverride ?? settings.strength) : nil
                rule.wrappedValue = r
            }
        )
        let usePattern = Binding<Bool>(
            get: { rule.wrappedValue.patternOverride != nil },
            set: { on in
                var r = rule.wrappedValue
                r.patternOverride = on ? (r.patternOverride ?? settings.pattern) : nil
                rule.wrappedValue = r
            }
        )
        return VStack(alignment: .leading, spacing: 6) {
            Toggle("Only cover this app's windows", isOn: Binding(
                get: { rule.wrappedValue.limitToAppWindows },
                set: { on in
                    var r = rule.wrappedValue
                    r.limitToAppWindows = on
                    rule.wrappedValue = r
                }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 12))

            HStack(spacing: 10) {
                Toggle("Custom strength", isOn: useStrength)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                if useStrength.wrappedValue {
                    Slider(value: Binding(
                        get: { rule.wrappedValue.strengthOverride ?? settings.strength },
                        set: { new in
                            var r = rule.wrappedValue
                            r.strengthOverride = new
                            rule.wrappedValue = r
                        }), in: 0.0...1.0)
                    Text("\(Int((rule.wrappedValue.strengthOverride ?? 0) * 100))%")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
            HStack(spacing: 10) {
                Toggle("Custom pattern", isOn: usePattern)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                if usePattern.wrappedValue {
                    Picker("", selection: Binding(
                        get: { rule.wrappedValue.patternOverride ?? settings.pattern },
                        set: { new in
                            var r = rule.wrappedValue
                            r.patternOverride = new
                            rule.wrappedValue = r
                        })) {
                        ForEach(PatternMode.allCases) { p in Text(p.displayName).tag(p) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 170)
                }
                Spacer()
            }
        }
    }

    private func addAppRule() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let bundle = Bundle(url: url),
              let bid = bundle.bundleIdentifier else { return }
        let name = (bundle.infoDictionary?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        settings.addOrUpdateRule(AppRule(bundleIdentifier: bid,
                                         displayName: name,
                                         action: .activate))
    }

    // MARK: Schedule

    private var scheduleCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Schedule")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Automatically turn Privacy Mode on during these hours.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settings.schedule.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                if settings.schedule.isEnabled {
                    Divider()

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Start").font(.system(size: 12, weight: .semibold))
                            timePicker(hour: $settings.schedule.startHour,
                                       minute: $settings.schedule.startMinute)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("End").font(.system(size: 12, weight: .semibold))
                            timePicker(hour: $settings.schedule.endHour,
                                       minute: $settings.schedule.endMinute)
                        }
                        Spacer()
                    }

                    Text("Days")
                        .font(.system(size: 12, weight: .semibold))
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { wd in
                            dayChip(wd)
                        }
                    }
                }
            }
        }
    }

    private func timePicker(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        let binding = Binding<Date>(
            get: {
                var c = DateComponents()
                c.hour = hour.wrappedValue
                c.minute = minute.wrappedValue
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { new in
                let c = Calendar.current.dateComponents([.hour, .minute], from: new)
                hour.wrappedValue = c.hour ?? 0
                minute.wrappedValue = c.minute ?? 0
            }
        )
        return DatePicker("", selection: binding, displayedComponents: [.hourAndMinute])
            .labelsHidden()
    }

    private func dayChip(_ wd: Int) -> some View {
        let labels = ["", "S", "M", "T", "W", "T", "F", "S"]
        let selected = settings.schedule.weekdays.contains(wd)
        return Button {
            if selected { settings.schedule.weekdays.remove(wd) }
            else        { settings.schedule.weekdays.insert(wd) }
        } label: {
            Text(labels[wd])
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(selected ? Color.accentColor.opacity(0.18)
                                           : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    Circle().strokeBorder(selected ? Color.accentColor.opacity(0.5)
                                                   : Color.black.opacity(0.08),
                                          lineWidth: 1)
                )
                .foregroundStyle(selected ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}
