import ComposableArchitecture
import Foundation

/// Root reducer composing all child features.
@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var shortcuts = ShortcutsFeature.State()
        public var permissionStatus = PermissionStatus()
        @Shared(.appSettings) public var settings: AppSettings

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case task
        case shortcuts(ShortcutsFeature.Action)
        case permissionsUpdated(PermissionStatus)
    }

    @Dependency(\.permissions) var permissions
    @Dependency(\.continuousClock) var clock

    private enum CancelID { case permissionPolling }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Scope(state: \.shortcuts, action: \.shortcuts) {
            ShortcutsFeature()
        }
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .task:
                return .merge(
                    .send(.shortcuts(.loadData)),
                    .run { [permissions, clock] send in
                        while !Task.isCancelled {
                            let status = await permissions.check()
                            await send(.permissionsUpdated(status))
                            try await clock.sleep(for: .seconds(3))
                        }
                    }
                    .cancellable(id: CancelID.permissionPolling)
                )

            case let .permissionsUpdated(status):
                state.permissionStatus = status
                return .none

            case .shortcuts:
                return .none
            }
        }
    }
}
