import SwiftUI

struct MGRouteSettingView: View {
    
    @EnvironmentObject  private var packetTunnelManager:    MGPacketTunnelManager
    @ObservedObject     private var routeViewModel:         MGRouteViewModel
    
    init(routeViewModel: MGRouteViewModel) {
        self._routeViewModel = ObservedObject(initialValue: routeViewModel)
    }
    
    var body: some View {
        Form {
            Section {
                Picker("解析策略", selection: $routeViewModel.domainStrategy) {
                    ForEach(MGRouteModel.DomainStrategy.allCases) { strategy in
                        Text(strategy.description)
                    }
                }
                Picker("匹配算法", selection: $routeViewModel.domainMatcher) {
                    ForEach(MGRouteModel.DomainMatcher.allCases) { strategy in
                        Text(strategy.description)
                    }
                }
            } header: {
                Text("域名")
            }
            Section {
                ForEach($routeViewModel.rules) { rule in
                    NavigationLink {
                        MGRouteRuleSettingView(rule: rule)
                    } label: {
                        HStack {
                            LabeledContent {
                                Text(rule.outboundTag.wrappedValue.description)
                            } label: {
                                Label {
                                    Text(rule.__name__.wrappedValue)
                                } icon: {
                                    Image(systemName: "circle.fill")
                                        .resizable()
                                        .frame(width: 8, height: 8)
                                        .foregroundColor(rule.__enabled__.wrappedValue ? .green : .gray)
                                }
                            }
                        }
                    }
                }
                .onMove { from, to in
                    routeViewModel.rules.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offsets in
                    routeViewModel.rules.remove(atOffsets: offsets)
                }
                Button("添加规则") {
                    withAnimation {
                        routeViewModel.rules.append(MGRouteModel.Rule())
                    }
                }
            } header: {
                HStack {
                    Text("规则")
                    Spacer()
                    EditButton()
                        .font(.callout)
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                        .disabled(routeViewModel.rules.isEmpty)
                }
            }
        }
        .onDisappear {
            self.routeViewModel.save {
                guard let status = packetTunnelManager.status, status == .connected else {
                    return
                }
                packetTunnelManager.stop()
                Task(priority: .userInitiated) {
                    do {
                        try await Task.sleep(for: .milliseconds(500))
                        try await packetTunnelManager.start()
                    } catch {
                        debugPrint(error.localizedDescription)
                    }
                }
            }
        }
        .navigationTitle(Text("路由设置"))
    }
}

struct MGRouteRuleSettingView: View {
    
    @Binding var rule: MGRouteModel.Rule
    
    var body: some View {
        Form {
            Section {
                Picker("Matcher", selection: $rule.domainMatcher) {
                    ForEach(MGRouteModel.DomainMatcher.allCases) { strategy in
                        Text(strategy.description)
                    }
                }
                NavigationLink {
                    MGRouteRuleStringListEditView(title: "Domain", elements: $rule.domain)
                } label: {
                    LabeledContent("Domain", value: "\(rule.domain.count)")
                }
                NavigationLink {
                    MGRouteRuleStringListEditView(title: "IP", elements: $rule.ip)
                } label: {
                    LabeledContent("IP", value: "\(rule.ip.count)")
                }
                NavigationLink {
                    MGRouteRuleStringListEditView(title: "Port", elements:  Binding {
                        rule.port.components(separatedBy: ",").filter { !$0.isEmpty }
                    } set: { newValue in
                        rule.port = newValue.joined(separator: ",")
                    })
                } label: {
                    LabeledContent("Port", value: rule.port)
                }
                NavigationLink {
                    MGRouteRuleStringListEditView(title: "Source Port", elements:  Binding {
                        rule.sourcePort.components(separatedBy: ",").filter { !$0.isEmpty }
                    } set: { newValue in
                        rule.sourcePort = newValue.joined(separator: ",")
                    })
                } label: {
                    LabeledContent("Source Port", value: rule.sourcePort)
                }
                LabeledContent("Network") {
                    HStack {
                        MGToggleButton(title: "TCP", isOn: Binding(get: {
                            rule.network.components(separatedBy: ",").contains("tcp")
                        }, set: { newValue in
                            var components = rule.network.components(separatedBy: ",")
                            components.removeAll(where: { $0 == "tcp" })
                            if newValue {
                                components.insert("tcp", at: 0)
                            }
                            rule.network = String(components.joined(separator: ","))
                        }))
                        MGToggleButton(title: "UDP", isOn: Binding(get: {
                            rule.network.components(separatedBy: ",").contains("udp")
                        }, set: { newValue in
                            var components = rule.network.components(separatedBy: ",")
                            components.removeAll(where: { $0 == "udp" })
                            if newValue {
                                components.append("udp")
                            }
                            rule.network = String(components.joined(separator: ","))
                        }))
                    }
                }
                LabeledContent("Protocol") {
                    HStack {
                        MGToggleButton(title: "HTTP", isOn: Binding(get: {
                            rule.protocol.contains("http")
                        }, set: { newValue in
                            rule.protocol.removeAll(where: { $0 == "http" })
                            if newValue {
                                rule.protocol.append("http")
                            }
                        }))
                        MGToggleButton(title: "TLS", isOn: Binding(get: {
                            rule.protocol.contains("tls")
                        }, set: { newValue in
                            rule.protocol.removeAll(where: { $0 == "tls" })
                            if newValue {
                                rule.protocol.append("tls")
                            }
                        }))
                        MGToggleButton(title: "Bittorrent", isOn: Binding(get: {
                            rule.protocol.contains("bittorrent")
                        }, set: { newValue in
                            rule.protocol.removeAll(where: { $0 == "bittorrent" })
                            if newValue {
                                rule.protocol.append("bittorrent")
                            }
                        }))
                    }
                }
                LabeledContent("Outbound") {
                    Picker("Outbound", selection: $rule.outboundTag) {
                        ForEach(MGRouteModel.Outbound.allCases) { outbound in
                            Text(outbound.description)
                        }
                    }
                }
            } header: {
                Text("Settings")
            }
            Section {
                LabeledContent("Name") {
                    TextField("", text: $rule.__name__)
                }
                Toggle("Enable", isOn: $rule.__enabled__)
            } header: {
                Text("Other")
            }
        }
        .lineLimit(1)
        .multilineTextAlignment(.trailing)
        .navigationTitle(Text(rule.__name__))
        .navigationBarTitleDisplayMode(.large)
    }
}

struct MGRouteRuleStringListEditView: View {
    
    let title: String
    @Binding var elements: [String]
    
    @State private var isPresented: Bool = false
    @State private var value: String = ""
    
    var body: some View {
        Form {
            Section {
                ForEach(elements, id: \.self) { element in
                    Text(element)
                }
                .onMove { from, to in
                    elements.move(fromOffsets: from, toOffset: to)
                }
                .onDelete { offseets in
                    elements.remove(atOffsets: offseets)
                }
                
            } header: {
                Text("List")
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.large)
        .alert("Add", isPresented: $isPresented) {
            TextField("", text: $value)
            Button("Done") {
                let reavl = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !reavl.isEmpty && !elements.contains(reavl) {
                    elements.append(reavl)
                }
                value = ""
            }
            Button("Cancel", role: .cancel) {}
        }
        .toolbar {
            Button {
                isPresented.toggle()
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}
