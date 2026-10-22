import Contacts
import Foundation

/// Finds the people a spoken name could mean, in the user's Contacts. Nothing leaves the device:
/// the names are matched here, and only the one chosen is used.
///
/// If the Contacts app has a list named "Quasi", only the people in it can be messaged; everyone
/// else is unknown to this app. Without such a list, everyone the app may see is.
enum ContactBook {
    static let listName = "Quasi"

    static var access: CNAuthorizationStatus { CNContactStore.authorizationStatus(for: .contacts) }

    /// The "Quasi" list in Contacts, if there is one.
    static func list() -> CNGroup? {
        (try? CNContactStore().groups(matching: nil))?.first { $0.name.caseInsensitiveCompare(listName) == .orderedSame }
    }

    /// How many people the app may message, and whether that is a chosen list: for the settings.
    static func scope() -> String {
        guard access == .authorized || access == .limited else { return "Not allowed" }
        let request = CNContactFetchRequest(keysToFetch: [CNContactPhoneNumbersKey as CNKeyDescriptor])
        let group = list()
        if let group { request.predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier) }
        var count = 0
        try? CNContactStore().enumerateContacts(with: request) { contact, _ in if !contact.phoneNumbers.isEmpty { count += 1 } }
        return group != nil ? "The “\(listName)” list · \(count)" : access == .limited ? "Chosen ones · \(count)" : "All · \(count)"
    }

    /// Asks for access the first time. Has to be called with the app in front.
    static func requestAccess() async -> Bool {
        (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
    }

    /// The people whose names fit what was said best, and how well (see `NameMatch`).
    static func lookup(_ spoken: String) -> (fit: NameMatch.Fit, people: [Candidate]) {
        let found = NameMatch.best(spoken, among: everyone()) { $0.names }
        return (found.fit, found.people.map(\.candidate))
    }

    /// One person the app may message, with the names they go by.
    struct Person {
        var candidate: Candidate
        /// Given name, family name and nickname.
        var names: [String]
    }

    /// Everyone the app may message who has a phone number.
    static func everyone() -> [Person] {
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactNicknameKey, CNContactOrganizationNameKey, CNContactPhoneNumbersKey]
            .map { $0 as CNKeyDescriptor } + [CNContactFormatter.descriptorForRequiredKeys(for: .fullName)]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.unifyResults = true
        if let group = list() { request.predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier) }
        var people: [Person] = []
        try? CNContactStore().enumerateContacts(with: request) { contact, _ in
            guard !contact.phoneNumbers.isEmpty else { return }
            let number = preferred(contact.phoneNumbers)
            var details: [String] = []
            if !contact.nickname.isEmpty { details.append("“\(contact.nickname)”") }
            if !contact.organizationName.isEmpty { details.append(contact.organizationName) }
            if let label = number.label.map({ CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: $0) }), !label.isEmpty { details.append(label) }
            let candidate = Candidate(name: CNContactFormatter.string(from: contact, style: .fullName) ?? contact.givenName,
                                      number: number.value.stringValue, detail: details.joined(separator: " · "))
            people.append(Person(candidate: candidate, names: [contact.givenName, contact.familyName, contact.nickname].filter { !$0.isEmpty }))
        }
        return people.sorted { $0.candidate.name < $1.candidate.name }
    }

    /// The number to text: the one labelled iPhone or mobile, failing that the main one, failing that the first.
    private static func preferred(_ numbers: [CNLabeledValue<CNPhoneNumber>]) -> CNLabeledValue<CNPhoneNumber> {
        for wanted in [CNLabelPhoneNumberiPhone, CNLabelPhoneNumberMobile, CNLabelPhoneNumberMain] {
            if let found = numbers.first(where: { $0.label == wanted }) { return found }
        }
        return numbers[0]
    }
}
