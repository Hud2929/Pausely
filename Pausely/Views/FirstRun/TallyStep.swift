import SwiftUI

/// The first run, step 2: the tally. Tap what you pay for; the slip at the bottom adds it up.
struct TallyStep: View {
    @Binding var tally: Tally
    let rates: CurrencyRates
    let onBack: () -> Void
    let onReveal: () -> Void
    let onSkip: () -> Void

    @State private var asking: TallyService?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var services: [TallyService] { TallyCatalog.services(payingIn: tally.currency) }
    /// Tiles three or four across; one service to a row at accessibility text sizes, where a name
    /// no longer fits in a third of the screen.
    private var columns: [GridItem] {
        typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 96, maximum: 160), spacing: 10)]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    FirstRunBackButton(action: onBack)

                    Text("Now tap everything you pay for.")
                        .font(.question(.title2))
                        .foregroundStyle(Color.inkText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                        .accessibilityAddTraits(.isHeader)

                    if !Self.listComesStraightAfterTheHeading(largeText: typeSize.isAccessibilitySize) {
                        addedAfterwards
                            .padding(.top, 8)
                    }

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(services) { service in
                            ServiceTile(service: service, isOn: tally.contains(service),
                                        price: tally.lines.first { $0.name == service.name }
                                            .map { MoneyFormat.string($0.amount, $0.currency, locale: L10n.locale) }) {
                                let adding = !tally.contains(service)
                                // No honest typical price in this currency: ask what they pay.
                                if adding, Tally.typicalAmount(service, payingIn: tally.currency) == nil {
                                    asking = service
                                    return
                                }
                                withAnimation(Motion.unlessReduced(Motion.touch)) { tally.toggle(service) }
                                if adding { Feel.tick() } else { Feel.selection() }
                            }
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // Said where the question comes up: at the end of the list, by someone who did
                    // not find theirs.
                    if Self.listComesStraightAfterTheHeading(largeText: typeSize.isAccessibilitySize) {
                        addedAfterwards
                            .padding(.bottom, 24)
                    }
                }
                .padding(.horizontal, Layout.margin)
                .padding(.top, 8)
            }

            slipBar
        }
        .sheet(item: $asking) { service in
            PriceSheet(name: service.name, placeholder: nil, currency: tally.currency) { amount in
                withAnimation(Motion.unlessReduced(Motion.touch)) {
                    tally.toggle(service, amount: amount, confirmed: true)
                }
                Feel.tick()
            }
        }
    }

    private var addedAfterwards: some View {
        Text("Anything missing can be added afterwards.")
            .font(.subheadline)
            .foregroundStyle(Color.inkTextMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Whether the services come straight after the heading, with "Anything missing can be added
    /// afterwards." at the end of the list. At the accessibility text sizes, yes: that sentence
    /// took three lines between the heading and the first service.
    nonisolated static func listComesStraightAfterTheHeading(largeText: Bool) -> Bool { largeText }

    /// Whether the slip at the bottom edge holds only the way on. At the accessibility text sizes,
    /// yes: with its count ("On your slip", then the number, on three lines) and a button of two
    /// lines it met the heading, and no service was left on screen to tap. Each service tapped
    /// shows its own tick and its price (`ServiceTile`).
    nonisolated static func slipHoldsOnlyTheWayOn(largeText: Bool) -> Bool { largeText }

    /// The slip, feeding out of the bottom of the screen: the last line printed, and the way on.
    private var slipBar: some View {
        let onlyTheWayOn = Self.slipHoldsOnlyTheWayOn(largeText: typeSize.isAccessibilitySize)
        return VStack(alignment: .leading, spacing: 12) {
            if let last = tally.lines.last {
                if !onlyTheWayOn {
                    ProofLine(label: last.name, value: MoneyFormat.string(last.amount, last.currency, locale: L10n.locale))
                        .id(last.name)
                        .transition(.asymmetric(insertion: .arriving(.offset(y: 8)), removal: .opacity))
                    ProofLine(label: L10n.string("On your slip"), value: L10n.number(tally.lines.count), emphasised: true)
                }
                Button(action: onReveal) { Text("Show me the total") }
                    .buttonStyle(.ink(.onPaper))
                    .accessibilityIdentifier("showTotalButton")
            } else {
                if !onlyTheWayOn {
                    Text("Your slip is empty. Tap the first thing you pay for.")
                        .font(.proof(.subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: onSkip) {
                    Text("None of these")
                        .font(.subheadline.weight(.semibold))
                        .underline()
                        .tapArea()
                }
                .accessibilityIdentifier("noneOfTheseButton")
            }
        }
        .foregroundStyle(Color.paperInk)
        .padding(.horizontal, Layout.margin)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.paper
                .clipShape(SlipShape(tornTop: true, tornBottom: false))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct ServiceTile: View {
    let service: TallyService
    let isOn: Bool
    /// What it stands at on the slip, once tapped.
    var price: String?
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    /// The tick's disc grows with its glyph: at the largest text size the glyph was twice the
    /// width of a fixed disc and hung over the tile's corner.
    @ScaledMetric(relativeTo: .caption2) private var tickSize: CGFloat = 20

    var body: some View {
        Button(action: action) {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        // A name is not hyphenated: where its longest word is wider than the
                        // tile it is drawn smaller ("Crunchy-roll" and "PlaySta-tion Plus" were
                        // what the largest text size showed, 2026-11-17).
                        Text(verbatim: service.name)
                            .wholeWords(service.name, font: .body.weight(.medium), measuredIn: .body, weight: .medium)
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.leading)
                        // What the tap put on the slip. The slip at the foot of the screen shows
                        // only the way on at these sizes, so the price is said here.
                        if isOn, let price {
                            Text(verbatim: price)
                                .font(.proof(.subheadline))
                                .foregroundStyle(Color.inkTextMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, tickSize + 8)
                } else {
                    VStack(spacing: 8) {
                        ServiceLogoView(name: service.name, category: service.category.rawValue, size: 40)
                        Text(verbatim: service.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.inkText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, typeSize.isAccessibilitySize ? 14 : 6)
            .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? Layout.tapTarget : 104)
            .background(isOn ? Color.inkLifted : Color.clear,
                        in: RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                    .stroke(isOn ? Color.paper : Color.line, lineWidth: isOn ? 1.5 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.paperInk)
                        .frame(width: tickSize, height: tickSize)
                        .background(Color.paper, in: Circle())
                        .padding(8)
                        .transition(.arriving(.scale))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: service.name))
        // The price a tap puts on the slip is drawn at the foot of the screen; VoiceOver hears it here.
        .accessibilityValue(Text(verbatim: price ?? ""))
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
