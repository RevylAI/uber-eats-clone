import Foundation

enum RideAccountField: Hashable {
    case name, email, password, vehicle, plate
}

enum RideAccountValidation {
    static func errors(name: String = "", email: String, password: String, creating: Bool, role: DemoRole = .rider, vehicle: String = "", plate: String = "") -> [RideAccountField: String] {
        var errors: [RideAccountField: String] = [:]
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if email.isEmpty {
            errors[.email] = "Enter your email address."
        } else if email.utf16.count > 254 || email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) == nil {
            errors[.email] = "Enter a valid email, like name@example.com."
        }
        if password.isEmpty {
            errors[.password] = "Enter your password."
        } else if creating && password.utf16.count < 12 {
            errors[.password] = "Use at least 12 characters for your password."
        } else if password.utf16.count > 128 {
            errors[.password] = "Use 128 characters or fewer for your password."
        }
        guard creating else { return errors }
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            errors[.name] = "Enter your full name."
        } else if name.utf16.count > 80 {
            errors[.name] = "Use 80 characters or fewer for your name."
        }
        if role == .driver {
            let vehicle = vehicle.trimmingCharacters(in: .whitespacesAndNewlines)
            let plate = plate.trimmingCharacters(in: .whitespacesAndNewlines)
            if vehicle.isEmpty {
                errors[.vehicle] = "Enter your vehicle's make, model and color."
            } else if vehicle.utf16.count > 100 {
                errors[.vehicle] = "Use 100 characters or fewer for your vehicle."
            }
            if plate.isEmpty {
                errors[.plate] = "Enter your license plate."
            } else if plate.utf16.count > 20 {
                errors[.plate] = "Use 20 characters or fewer for your license plate."
            }
        }
        return errors
    }
}
