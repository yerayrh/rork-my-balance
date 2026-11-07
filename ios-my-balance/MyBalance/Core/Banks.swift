import Foundation

struct Bank: Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
    let domain: String
    let colorHex: String

    var logoURL: URL? {
        URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=128")
    }

    var monogram: String {
        if name.count <= 4 { return name.uppercased() }
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        let letters = words.prefix(2).compactMap { $0.first }.map { String($0).uppercased() }
        return letters.joined()
    }
}

enum BankCatalog {
    static let countries: [String] = [
        "España", "Digitales", "Alemania", "Francia", "Italia", "Portugal", "Países Bajos",
        "Bélgica", "Irlanda", "Reino Unido", "Suiza", "Austria", "Países nórdicos", "Polonia",
    ]

    // Brand colours are approximations of each entity's corporate identity.
    static let all: [Bank] = [
        // España
        Bank(id: "bbva", name: "BBVA", country: "España", domain: "bbva.es", colorHex: "#004481"),
        Bank(id: "santander", name: "Santander", country: "España", domain: "bancosantander.es", colorHex: "#EC0000"),
        Bank(id: "caixabank", name: "CaixaBank", country: "España", domain: "caixabank.es", colorHex: "#007EAE"),
        Bank(id: "sabadell", name: "Sabadell", country: "España", domain: "bancsabadell.com", colorHex: "#006DFF"),
        Bank(id: "bankinter", name: "Bankinter", country: "España", domain: "bankinter.com", colorHex: "#FF6600"),
        Bank(id: "ing-es", name: "ING", country: "España", domain: "ing.es", colorHex: "#FF6200"),
        Bank(id: "openbank", name: "Openbank", country: "España", domain: "openbank.es", colorHex: "#FF0049"),
        Bank(id: "unicaja", name: "Unicaja", country: "España", domain: "unicajabanco.es", colorHex: "#00965E"),
        Bank(id: "kutxabank", name: "Kutxabank", country: "España", domain: "kutxabank.es", colorHex: "#E30613"),
        Bank(id: "abanca", name: "Abanca", country: "España", domain: "abanca.com", colorHex: "#009FE3"),
        Bank(id: "ibercaja", name: "Ibercaja", country: "España", domain: "ibercaja.es", colorHex: "#00427A"),
        Bank(id: "cajamar", name: "Cajamar", country: "España", domain: "cajamar.es", colorHex: "#00865A"),
        Bank(id: "cajarural", name: "Caja Rural", country: "España", domain: "ruralvia.com", colorHex: "#00843D"),
        Bank(id: "laboral", name: "Laboral Kutxa", country: "España", domain: "laboralkutxa.com", colorHex: "#D2001E"),
        Bank(id: "evo", name: "EVO Banco", country: "España", domain: "evobanco.com", colorHex: "#1E1E1E"),
        Bank(id: "myinvestor", name: "MyInvestor", country: "España", domain: "myinvestor.es", colorHex: "#16B48A"),
        Bank(id: "pibank", name: "Pibank", country: "España", domain: "pibank.es", colorHex: "#E5007E"),
        Bank(id: "mediolanum-es", name: "Banco Mediolanum", country: "España", domain: "bancomediolanum.es", colorHex: "#0057A0"),
        Bank(id: "march", name: "Banca March", country: "España", domain: "bancamarch.es", colorHex: "#003B71"),
        Bank(id: "selfbank", name: "Self Bank", country: "España", domain: "selfbank.es", colorHex: "#DC0032"),
        Bank(id: "cecabank", name: "Caixa Ontinyent", country: "España", domain: "caixaontinyent.es", colorHex: "#0077C8"),

        // Digitales
        Bank(id: "revolut", name: "Revolut", country: "Digitales", domain: "revolut.com", colorHex: "#191C1F"),
        Bank(id: "n26", name: "N26", country: "Digitales", domain: "n26.com", colorHex: "#36A18B"),
        Bank(id: "wise", name: "Wise", country: "Digitales", domain: "wise.com", colorHex: "#9FE870"),
        Bank(id: "bunq", name: "bunq", country: "Digitales", domain: "bunq.com", colorHex: "#3394D7"),
        Bank(id: "traderepublic", name: "Trade Republic", country: "Digitales", domain: "traderepublic.com", colorHex: "#111111"),
        Bank(id: "monzo", name: "Monzo", country: "Digitales", domain: "monzo.com", colorHex: "#FF4F40"),
        Bank(id: "starling", name: "Starling", country: "Digitales", domain: "starlingbank.com", colorHex: "#7433FF"),
        Bank(id: "vivid", name: "Vivid", country: "Digitales", domain: "vivid.money", colorHex: "#6E3FF3"),
        Bank(id: "qonto", name: "Qonto", country: "Digitales", domain: "qonto.com", colorHex: "#1D1D1B"),
        Bank(id: "lunar", name: "Lunar", country: "Digitales", domain: "lunar.app", colorHex: "#2B2B2B"),

        // Alemania
        Bank(id: "deutsche", name: "Deutsche Bank", country: "Alemania", domain: "deutsche-bank.de", colorHex: "#0018A8"),
        Bank(id: "commerzbank", name: "Commerzbank", country: "Alemania", domain: "commerzbank.de", colorHex: "#FFCC00"),
        Bank(id: "sparkasse", name: "Sparkasse", country: "Alemania", domain: "sparkasse.de", colorHex: "#FF0000"),
        Bank(id: "dkb", name: "DKB", country: "Alemania", domain: "dkb.de", colorHex: "#148DEA"),
        Bank(id: "volksbank", name: "Volksbank", country: "Alemania", domain: "vr.de", colorHex: "#0066B3"),
        Bank(id: "postbank", name: "Postbank", country: "Alemania", domain: "postbank.de", colorHex: "#FFCC00"),
        Bank(id: "comdirect", name: "comdirect", country: "Alemania", domain: "comdirect.de", colorHex: "#FFF500"),
        Bank(id: "hvb", name: "HypoVereinsbank", country: "Alemania", domain: "hypovereinsbank.de", colorHex: "#E2001A"),
        Bank(id: "consorsbank", name: "Consorsbank", country: "Alemania", domain: "consorsbank.de", colorHex: "#00A2DE"),

        // Francia
        Bank(id: "bnp", name: "BNP Paribas", country: "Francia", domain: "mabanque.bnpparibas", colorHex: "#00965E"),
        Bank(id: "socgen", name: "Société Générale", country: "Francia", domain: "societegenerale.fr", colorHex: "#E9041E"),
        Bank(id: "ca", name: "Crédit Agricole", country: "Francia", domain: "credit-agricole.fr", colorHex: "#009597"),
        Bank(id: "cm", name: "Crédit Mutuel", country: "Francia", domain: "creditmutuel.fr", colorHex: "#0060AE"),
        Bank(id: "lcl", name: "LCL", country: "Francia", domain: "lcl.fr", colorHex: "#003D8F"),
        Bank(id: "lbp", name: "La Banque Postale", country: "Francia", domain: "labanquepostale.fr", colorHex: "#003B6F"),
        Bank(id: "bourso", name: "BoursoBank", country: "Francia", domain: "boursobank.com", colorHex: "#D5007F"),
        Bank(id: "ce", name: "Caisse d'Épargne", country: "Francia", domain: "caisse-epargne.fr", colorHex: "#D7182A"),
        Bank(id: "hellobank", name: "Hello bank!", country: "Francia", domain: "hellobank.fr", colorHex: "#00A0E1"),

        // Italia
        Bank(id: "unicredit", name: "UniCredit", country: "Italia", domain: "unicredit.it", colorHex: "#E2001A"),
        Bank(id: "intesa", name: "Intesa Sanpaolo", country: "Italia", domain: "intesasanpaolo.com", colorHex: "#00833E"),
        Bank(id: "fineco", name: "Fineco", country: "Italia", domain: "finecobank.com", colorHex: "#00205B"),
        Bank(id: "bpm", name: "Banco BPM", country: "Italia", domain: "bancobpm.it", colorHex: "#0058A3"),
        Bank(id: "mps", name: "Monte dei Paschi", country: "Italia", domain: "mps.it", colorHex: "#7B1416"),
        Bank(id: "bper", name: "BPER Banca", country: "Italia", domain: "bper.it", colorHex: "#00915A"),

        // Portugal
        Bank(id: "millennium", name: "Millennium bcp", country: "Portugal", domain: "millenniumbcp.pt", colorHex: "#D1005D"),
        Bank(id: "cgd", name: "Caixa Geral", country: "Portugal", domain: "cgd.pt", colorHex: "#0062A8"),
        Bank(id: "novobanco", name: "Novo Banco", country: "Portugal", domain: "novobanco.pt", colorHex: "#00A99D"),
        Bank(id: "bpi", name: "BPI", country: "Portugal", domain: "bancobpi.pt", colorHex: "#FF6600"),
        Bank(id: "activobank", name: "ActivoBank", country: "Portugal", domain: "activobank.pt", colorHex: "#81BC00"),

        // Países Bajos
        Bank(id: "abnamro", name: "ABN AMRO", country: "Países Bajos", domain: "abnamro.nl", colorHex: "#009286"),
        Bank(id: "rabobank", name: "Rabobank", country: "Países Bajos", domain: "rabobank.nl", colorHex: "#000099"),
        Bank(id: "ing-nl", name: "ING Nederland", country: "Países Bajos", domain: "ing.nl", colorHex: "#FF6200"),
        Bank(id: "sns", name: "SNS", country: "Países Bajos", domain: "snsbank.nl", colorHex: "#4F2683"),

        // Bélgica
        Bank(id: "kbc", name: "KBC", country: "Bélgica", domain: "kbc.be", colorHex: "#00AEEF"),
        Bank(id: "belfius", name: "Belfius", country: "Bélgica", domain: "belfius.be", colorHex: "#C30045"),
        Bank(id: "fortis", name: "BNP Paribas Fortis", country: "Bélgica", domain: "bnpparibasfortis.be", colorHex: "#00965E"),
        Bank(id: "argenta", name: "Argenta", country: "Bélgica", domain: "argenta.be", colorHex: "#8DB83F"),

        // Irlanda
        Bank(id: "aib", name: "AIB", country: "Irlanda", domain: "aib.ie", colorHex: "#7F2B7B"),
        Bank(id: "boi", name: "Bank of Ireland", country: "Irlanda", domain: "bankofireland.com", colorHex: "#0033A0"),
        Bank(id: "ptsb", name: "PTSB", country: "Irlanda", domain: "ptsb.ie", colorHex: "#5E2D91"),

        // Reino Unido
        Bank(id: "barclays", name: "Barclays", country: "Reino Unido", domain: "barclays.co.uk", colorHex: "#00AEEF"),
        Bank(id: "hsbc", name: "HSBC", country: "Reino Unido", domain: "hsbc.co.uk", colorHex: "#DB0011"),
        Bank(id: "lloyds", name: "Lloyds", country: "Reino Unido", domain: "lloydsbank.com", colorHex: "#006A4D"),
        Bank(id: "natwest", name: "NatWest", country: "Reino Unido", domain: "natwest.com", colorHex: "#5A287D"),
        Bank(id: "nationwide", name: "Nationwide", country: "Reino Unido", domain: "nationwide.co.uk", colorHex: "#1A3A6C"),
        Bank(id: "santander-uk", name: "Santander UK", country: "Reino Unido", domain: "santander.co.uk", colorHex: "#EC0000"),

        // Suiza
        Bank(id: "ubs", name: "UBS", country: "Suiza", domain: "ubs.com", colorHex: "#E60000"),
        Bank(id: "postfinance", name: "PostFinance", country: "Suiza", domain: "postfinance.ch", colorHex: "#FFCC00"),
        Bank(id: "raiffeisen-ch", name: "Raiffeisen Suiza", country: "Suiza", domain: "raiffeisen.ch", colorHex: "#E30613"),
        Bank(id: "zkb", name: "Zürcher Kantonalbank", country: "Suiza", domain: "zkb.ch", colorHex: "#0075BF"),

        // Austria
        Bank(id: "erste", name: "Erste Bank", country: "Austria", domain: "sparkasse.at", colorHex: "#2870ED"),
        Bank(id: "raiffeisen-at", name: "Raiffeisen", country: "Austria", domain: "raiffeisen.at", colorHex: "#FFE600"),
        Bank(id: "bankaustria", name: "Bank Austria", country: "Austria", domain: "bankaustria.at", colorHex: "#E2001A"),
        Bank(id: "bawag", name: "BAWAG", country: "Austria", domain: "bawag.at", colorHex: "#D6001C"),

        // Nórdicos
        Bank(id: "nordea", name: "Nordea", country: "Países nórdicos", domain: "nordea.com", colorHex: "#0000A0"),
        Bank(id: "danske", name: "Danske Bank", country: "Países nórdicos", domain: "danskebank.com", colorHex: "#003755"),
        Bank(id: "seb", name: "SEB", country: "Países nórdicos", domain: "seb.se", colorHex: "#60CD18"),
        Bank(id: "swedbank", name: "Swedbank", country: "Países nórdicos", domain: "swedbank.se", colorHex: "#FF7900"),
        Bank(id: "handelsbanken", name: "Handelsbanken", country: "Países nórdicos", domain: "handelsbanken.se", colorHex: "#005A8C"),
        Bank(id: "dnb", name: "DNB", country: "Países nórdicos", domain: "dnb.no", colorHex: "#007272"),

        // Polonia
        Bank(id: "pko", name: "PKO Bank Polski", country: "Polonia", domain: "pkobp.pl", colorHex: "#003574"),
        Bank(id: "mbank", name: "mBank", country: "Polonia", domain: "mbank.pl", colorHex: "#E11A27"),
        Bank(id: "pekao", name: "Bank Pekao", country: "Polonia", domain: "pekao.com.pl", colorHex: "#D52B1E"),
    ]

    static let byID: [String: Bank] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
}
