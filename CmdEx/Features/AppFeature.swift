import ComposableArchitecture
import Foundation
import CmdExCore

/// Root reducer composing all child features.
@Reducer
struct AppFeature {
    @ObservableState
    struct State: Equatable {
        var shortcuts = ShortcutsFeature.State()
        var activeTab: ActiveTab = .shortcuts
        @Shared(.appSettings) var settings: AppSettings
    }

    enum ActiveTab: Equatable {
        case shortcuts, preferences
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case shortcuts(ShortcutsFeature.Action)
        case setActiveTab(ActiveTab)
    }

    var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.shortcuts, action: \.shortcuts) {
            ShortcutsFeature()
        }
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .task:
                return .send(.shortcuts(.loadData))
            case .shortcuts:
                return .none
            case let .setActiveTab(tab):
                state.activeTab = tab
                return .none
            }
        }
    }
}
