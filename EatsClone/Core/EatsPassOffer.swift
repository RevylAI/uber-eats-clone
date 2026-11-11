import Foundation

enum EatsPassOffer: Equatable {
    case hidden
    case visible(freeDelivery: Bool)

    static func resolve(environment: [String: String], arguments: [String]) -> EatsPassOffer {
        guard RevylAuthBypass.launchValue("EATSCLONE_FLAG_PASS_BADGE", environment: environment, arguments: arguments) == "on",
              RevylAuthBypass.launchValue("EATSCLONE_ACCOUNT_TIER", environment: environment, arguments: arguments) == "eats_pass"
        else { return .hidden }
        let freeDelivery = RevylAuthBypass.launchValue("EATSCLONE_SERVER_FREE_DELIVERY", environment: environment, arguments: arguments) == "on"
        return .visible(freeDelivery: freeDelivery)
    }
}
