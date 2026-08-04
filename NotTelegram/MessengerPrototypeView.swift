import SwiftUI
import PhotosUI
import UIKit

// Base language = English. Ukrainian lives in Localizable.xcstrings.
// LK wraps a model-held string so it resolves through the string catalog.
func LK(_ s: String) -> LocalizedStringKey { LocalizedStringKey(s) }

struct MessengerPrototypeView: View {
    @State private var tab: AppTab = .chats
    @State private var selectedStory: Story?
    @State private var appBackgroundItem: PhotosPickerItem?
    @State private var appBackground: Image?
    @State private var storyCollapseProgress: CGFloat = 1
    @State private var storiesExpanded = false
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            ZStack {
                if let appBackground {
                    appBackground.resizable().scaledToFill().ignoresSafeArea()
                    Color.black.opacity(0.58).ignoresSafeArea()
                } else {
                    Theme.bg.ignoresSafeArea()
                }
                switch tab {
                case .chats: chats
                case .calls: CallsSurface()
                case .channels: ChannelsSurface()
                case .search: SearchSurface()
                case .profile: ProfileSurface(backgroundItem: $appBackgroundItem)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) { BottomBar(selection: $tab) }
        }
        .preferredColorScheme(.dark)
        .task(id: appBackgroundItem) {
            appBackground = await loadImage(from: appBackgroundItem)
        }
        .overlay {
            if let sel = selectedStory {
                StoryPager(stories: SampleData.stories, current: sel.id) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selectedStory = nil }
                }
                .transition(.scale(scale: 0.05, anchor: .top).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .sheet(isPresented: $showCreate) { CreateCardView() }
    }

    private var chats: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Chats").font(.system(size: 34, weight: .bold, design: .rounded))
                    Spacer()
                    Button { showCreate = true } label: {
                        Image(systemName: "plus").font(.system(size: 20, weight: .semibold))
                            .frame(width: 38, height: 38).background(Theme.surfaceStrong, in: Circle())
                    }.accessibilityLabel("New product")
                }
                .foregroundStyle(Theme.textPrimary).padding(.horizontal, 20).padding(.top, 12)

                StoriesRow(stories: SampleData.stories, collapseProgress: storyCollapseProgress) { selectedStory = $0 }
                    .padding(.top, 18).padding(.bottom, 14)

                ForEach(SampleData.chats) { chat in
                    NavigationLink(value: chat) { ChatRow(chat: chat) }.buttonStyle(.plain)
                }
            }.padding(.bottom, 12)
        }
        .onScrollGeometryChange(for: CGFloat.self, of: { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        }) { _, offset in
            // Telegram-style: small by default. Pull the list DOWN and the stories
            // grow continuously with the finger; pull far enough and they LATCH
            // open (stay expanded). Scroll up to collapse them again.
            if storiesExpanded {
                if offset > 40 {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        storiesExpanded = false; storyCollapseProgress = 1
                    }
                } else {
                    storyCollapseProgress = 0
                }
            } else {
                storyCollapseProgress = 1 - min(max(-offset / 90, 0), 1)
                if offset < -80 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        storiesExpanded = true; storyCollapseProgress = 0
                    }
                }
            }
        }
        .navigationDestination(for: Chat.self) { ChatDetailView(chat: $0, appBackground: appBackground) }
    }
}

private func loadImage(from item: PhotosPickerItem?) async -> Image? {
    guard let item, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return nil }
    return Image(uiImage: image)
}

enum AppTab: CaseIterable { case chats, channels, calls, search, profile
    var title: LocalizedStringKey { switch self { case .chats: "Chats"; case .channels: "Channels"; case .calls: "Calls"; case .search: "Search"; case .profile: "Profile" } }
    var symbol: String { switch self { case .chats: "bubble.left.and.bubble.right.fill"; case .channels: "dot.radiowaves.left.and.right"; case .calls: "phone.fill"; case .search: "magnifyingglass"; case .profile: "person.crop.circle.fill" } }
}

struct BottomBar: View {
    @Binding var selection: AppTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { withAnimation(.easeOut(duration: 0.2)) { selection = tab } } label: {
                    VStack(spacing: 4) { Image(systemName: tab.symbol).font(.system(size: 18, weight: .semibold)); Text(tab.title).font(.system(size: 10, weight: .medium)) }
                        .foregroundStyle(selection == tab ? Theme.accent : Theme.textMuted).frame(maxWidth: .infinity)
                }.buttonStyle(.plain).accessibilityLabel(tab.title)
            }
        }.padding(.top, 11).padding(.bottom, 8).background(.ultraThinMaterial)
            .overlay(alignment: .top) { Rectangle().fill(Theme.stroke).frame(height: 0.5) }
    }
}

struct StoriesRow: View {
    let stories: [Story]
    let collapseProgress: CGFloat
    let select: (Story) -> Void
    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12 - (collapseProgress * 4)) {
                    StoryCard(story: .newStory, collapseProgress: collapseProgress, action: {})
                    ForEach(stories) { story in
                        StoryCard(story: story, collapseProgress: collapseProgress) { select(story) }
                    }
                }
                .padding(.horizontal, 16)
                .frame(minWidth: geo.size.width, alignment: .center)
            }
        }
        .frame(height: 96 - (collapseProgress * 54))
        .clipped()
    }
}

struct StoryCard: View {
    let story: Story
    let collapseProgress: CGFloat
    let action: () -> Void
    private var side: CGFloat { 76 - (collapseProgress * 44) }
    var body: some View {
        Button(action: action) {
            VStack(spacing: 7 - (collapseProgress * 5)) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if !story.isNew, let u = URL(string: story.cover) {
                            AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: {
                                LinearGradient(colors: story.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                        } else {
                            LinearGradient(colors: story.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack(spacing: 2) {
                        Avatar(initial: story.initial, fill: story.fill, size: 22 - (collapseProgress * 8), url: story.avatar.isEmpty ? nil : story.avatar)
                        if story.isShared {
                            Image(systemName: "plus").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                            Avatar(initial: story.secondInitial, fill: story.secondFill, size: 22 - (collapseProgress * 8), url: story.secondAvatar.isEmpty ? nil : story.secondAvatar)
                        }
                    }
                    .padding(7)

                    if story.isNew {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 20 - (collapseProgress * 6), height: 20 - (collapseProgress * 6))
                            .background(Theme.coral, in: Circle()).padding(5 - (collapseProgress * 3))
                    }
                }
                Text(story.isShared ? LK("Masha + A") : LK(story.title))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .frame(width: side)
                    .opacity(1 - collapseProgress)
            }
        }.buttonStyle(.plain)
    }
}

struct ChatRow: View {
    let chat: Chat
    var body: some View {
        HStack(spacing: 13) {
            if chat.isGroup { GroupAvatar(fill: chat.fill, size: 52, photos: chat.groupPhotos) } else { Avatar(initial: chat.initial, fill: chat.fill, size: 52, url: chat.photo.isEmpty ? nil : chat.photo) }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) { Text(LK(chat.name)).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1); if chat.isGroup { Text("· \(chat.participantCount)").font(.system(size: 13)).foregroundStyle(Theme.textMuted) } else if chat.isOnline { Circle().fill(Theme.online).frame(width: 7, height: 7) }; Spacer(minLength: 4); Text(LK(chat.time)).font(.system(size: 12)).foregroundStyle(Theme.textMuted) }
                HStack(spacing: 7) { if chat.hasCard { Image(systemName: "rectangle.stack.fill").font(.system(size: 12)).foregroundStyle(Theme.accent) }; Text(LK(chat.preview)).font(.system(size: 14)).foregroundStyle(chat.unreadCount > 0 ? Theme.textPrimary : Theme.textSecondary).lineLimit(1); Spacer(minLength: 4); if chat.unreadCount > 0 { Text("\(chat.unreadCount)").font(.system(size: 11, weight: .bold)).foregroundStyle(.black).frame(width: 21, height: 21).background(Theme.coral, in: Circle()) } }
            }
        }.padding(.horizontal, 20).padding(.vertical, 12).contentShape(Rectangle())
    }
}

struct ChatDetailView: View {
    let chat: Chat
    let appBackground: Image?
    @State private var heroCard: CardInfo?
    @State private var heroRect: CGRect = .zero

    var body: some View {
        ZStack {
            if let appBackground { appBackground.resizable().scaledToFill().ignoresSafeArea() }
            else { Theme.bg.ignoresSafeArea() }

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Today").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textMuted).frame(maxWidth: .infinity).padding(.top, 18)
                        ForEach(chat.messages, id: \.self) { m in
                            if m.card { EmbeddedCard() } else { MessageBubble(text: m.text, incoming: m.incoming) }
                        }
                    }.padding(.horizontal, 16)
                }
                .scrollDisabled(heroCard != nil)
                inputBar
            }

            if let card = heroCard {
                HeroExpandView(card: card, sourceRect: heroRect) {
                    heroCard = nil
                }
                .zIndex(50)
            }
        }
        .environment(\.dealPresentation, DealPresentation(
            activeID: heroCard?.id,
            present: { c, rect in
                heroRect = rect
                heroCard = c
            }
        ))
        .navigationTitle(LK(chat.name))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { PersonProfileView(chat: chat) } label: { profileAvatar }
            }
        }
    }

    private var profileAvatar: some View {
        Group {
            if chat.isGroup { GroupAvatar(fill: chat.fill, size: 36, photos: chat.groupPhotos) }
            else { Avatar(initial: chat.initial, fill: chat.fill, size: 36, url: chat.photo.isEmpty ? nil : chat.photo) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
            Text("Message").foregroundStyle(Theme.textMuted)
            Spacer()
            Image(systemName: "mic.fill")
        }.foregroundStyle(Theme.textSecondary).padding(.horizontal, 16).frame(height: 48).background(Theme.surfaceStrong, in: Capsule()).padding(12)
    }
}

// Profile of the chat partner — opened by tapping the avatar in the header.
// The profile IS the vitrina: who they are + their products.
struct PersonProfileView: View {
    let chat: Chat
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if chat.isGroup { GroupAvatar(fill: chat.fill, size: 88, photos: chat.groupPhotos).padding(.top, 8) }
                    else { Avatar(initial: chat.initial, fill: chat.fill, size: 88, url: chat.photo.isEmpty ? nil : chat.photo).padding(.top, 8) }
                    Text(LK(chat.name)).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                    Text(chat.isOnline ? "online" : "last seen recently").font(.system(size: 14)).foregroundStyle(Theme.online)
                    HStack { Text("Products").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.textPrimary); Spacer() }.padding(.top, 10)
                    HStack(alignment: .top, spacing: 12) { ProductCard(); Spacer() }
                }.padding(.horizontal, 20).padding(.top, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .top) {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 2) { Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)); Text("Back").font(.system(size: 17)) }.foregroundStyle(Theme.accent)
                }
                Spacer()
            }.padding(.horizontal, 14).padding(.vertical, 9).background(.ultraThinMaterial)
        }
    }
}

struct MessageBubble: View { let text: String; let incoming: Bool; var body: some View { Text(LK(text)).font(.system(size: 16)).foregroundStyle(Theme.textPrimary).padding(.horizontal, 14).padding(.vertical, 10).background(incoming ? Theme.surfaceStrong : Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous)).frame(maxWidth: .infinity, alignment: incoming ? .leading : .trailing) } }

// Vertical product tile (WB/Vinted shape): the photo fills the tall tile
// (crop-to-fill), badge + title + price overlaid. The system renders this
// from photo+title+price — the seller never designs an infographic.
// The card's visual face (no interaction) — reused for the small card and its
// expanded hero twin.
struct CardFace: View {
    var title: String = "Nike Air Max 1"
    var price: String = "€120"
    var badge: String? = "top"
    var width: CGFloat = 230
    var image: Image? = nil
    var placeholder: Bool = false
    private var height: CGFloat { width * 1.34 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let image { image.resizable().scaledToFill() }
                else if placeholder {
                    ZStack { Theme.surfaceStrong; Image(systemName: "photo").font(.system(size: 32)).foregroundStyle(Theme.textMuted) }
                } else { Image("Sneaker").resizable().scaledToFill() }
            }
            .frame(width: width, height: height)
            .clipped()

            LinearGradient(colors: [.clear, .clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)

            if let badge {
                Text(LK(badge)).font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.coral, in: Capsule()).padding(10)
            }

            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Text(LK(title)).font(.system(size: 18, weight: .bold)).foregroundStyle(.white).lineLimit(2)
                Text(price).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            .padding(14)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.stroke, lineWidth: 0.6) }
    }
}

// Deal presentation is coordinated by the host view so a tapped card can expand
// (hero morph) over the whole screen. Provided via environment.
struct CardInfo: Identifiable, Equatable { let id: String; let title: String; let price: String }
struct DealPresentation {
    let activeID: String?
    // Present with the card's exact on-screen frame (global coords).
    let present: (CardInfo, CGRect) -> Void
}
private struct DealPresentationKey: EnvironmentKey { static let defaultValue: DealPresentation? = nil }
extension EnvironmentValues {
    var dealPresentation: DealPresentation? {
        get { self[DealPresentationKey.self] }
        set { self[DealPresentationKey.self] = newValue }
    }
}

// Tappable card — tapping asks the host to expand it into the deal.
struct ProductCard: View {
    var title: String = "Nike Air Max 1"
    var price: String = "€120"
    var badge: String? = "top"
    var width: CGFloat = 230
    var image: Image? = nil
    var placeholder: Bool = false
    var interactive: Bool = true
    @Environment(\.dealPresentation) private var deal
    @State private var frame: CGRect = .zero
    private var isActive: Bool { interactive && deal?.activeID == title }

    var body: some View {
        CardFace(title: title, price: price, badge: badge, width: width, image: image, placeholder: placeholder)
            // Hidden while its expanded twin is on screen; toggled without animation.
            .opacity(isActive ? 0 : 1)
            .animation(nil, value: isActive)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("\(title), \(price)")
            .onTapGesture {
                if interactive, let deal { deal.present(CardInfo(id: title, title: title, price: price), frame) }
            }
    }
}

struct EmbeddedCard: View {
    var body: some View { ProductCard() }
}

// Create a card in under a minute: photo → name → price → (description) →
// publish. Live preview at the top updates as you type.
struct CreateCardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var price = ""
    @State private var desc = ""
    @State private var bargain = false
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: Image?

    private var canPublish: Bool { !name.isEmpty && !price.isEmpty }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ProductCard(title: name.isEmpty ? "Product name" : name,
                                price: price.isEmpty ? "€—" : "€" + price,
                                badge: nil, width: 200,
                                image: photo, placeholder: photo == nil, interactive: false)
                        .padding(.vertical, 8)

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        row(icon: "photo", text: photo == nil ? "Add photo" : "Change photo")
                    }
                    field { TextField("Name", text: $name).textInputAutocapitalization(.sentences) }
                    field { TextField("Price", text: $price).keyboardType(.numberPad) }
                    field { TextField("Description (optional)", text: $desc, axis: .vertical).lineLimit(1...4) }

                    Toggle(isOn: $bargain) {
                        Text("Bargaining allowed").font(.system(size: 16)).foregroundStyle(Theme.textPrimary)
                    }
                    .tint(Theme.accent)
                    .padding(.horizontal, 14).frame(minHeight: 52)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button { dismiss() } label: {
                        Text("Publish").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!canPublish).opacity(canPublish ? 1 : 0.5)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20).padding(.bottom, 28)
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button { dismiss() } label: { Text("Cancel").font(.system(size: 17)).foregroundStyle(Theme.accent) }
                Spacer()
                Text("New product").font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("Cancel").font(.system(size: 17)).opacity(0)
            }.padding(.horizontal, 16).padding(.vertical, 10).background(.ultraThinMaterial)
        }
        .task(id: photoItem) { photo = await loadImage(from: photoItem) }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private func field<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .font(.system(size: 16)).foregroundStyle(Theme.textPrimary).tint(Theme.accent)
            .padding(.horizontal, 14).frame(minHeight: 52)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(text)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textMuted)
        }
        .font(.system(size: 16, weight: .medium)).foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14).frame(height: 52)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// The deal: Buy (at the seller's price) or offer your own. Both are one deal
// with a different starting price; a decision opens a chat. Payment is a demo.
// Expanded deal — one card grows from its source position and contracts back
// into that same position. There is no modal backdrop or second card surface.
struct HeroExpandView: View {
    let card: CardInfo
    let sourceRect: CGRect
    let onClose: () -> Void
    @State private var expanded = false
    @State private var slotRect: CGRect = .zero
    @State private var showPay = false
    @State private var offering = false
    @State private var offer = ""
    @State private var result: String?

    private var screenW: CGFloat { UIScreen.main.bounds.width }
    private var targetW: CGFloat { min(screenW - 96, 300) }
    private var targetH: CGFloat { targetW * 1.34 }
    private var startScale: CGFloat { sourceRect.width > 0 ? sourceRect.width / targetW : 0.6 }
    // Where the card and details naturally sit once expanded.
    private var cardTarget: CGPoint {
        slotRect == .zero ? CGPoint(x: screenW / 2, y: sourceRect.midY) : CGPoint(x: slotRect.midX, y: slotRect.midY)
    }

    var body: some View {
        ZStack {
            // Scrim fades with the same motion — dark enough that the details
            // below the card stay readable over the chat.
            Color.black.opacity(expanded ? 0.92 : 0)
                .ignoresSafeArea()
                .onTapGesture { close() }

            // Layout skeleton: a placeholder reserves the expanded card's slot,
            // details sit beneath it. We measure the slot and fly the real card
            // into it, so positioning is automatic.
            VStack(spacing: 16) {
                Color.clear
                    .frame(width: targetW, height: targetH)
                    .allowsHitTesting(false)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { slotRect = $0 }
                details
                    .frame(width: targetW)
                    .opacity(expanded ? 1 : 0)
                    .offset(y: expanded ? 0 : 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 40)

            // The single card — one continuous scale + translate.
            CardFace(title: card.title, price: card.price, badge: "top", width: targetW)
                .scaleEffect(expanded ? 1 : startScale, anchor: .center)
                .position(expanded ? cardTarget : CGPoint(x: sourceRect.midX, y: sourceRect.midY))
                .onTapGesture { close() }
        }
        .ignoresSafeArea()
        .onChange(of: slotRect) { _, r in
            if r != .zero && !expanded { withAnimation(.spring(response: 0.44, dampingFraction: 0.82)) { expanded = true } }
        }
        .sheet(isPresented: $showPay) {
            DemoPaymentView(price: card.price) { withAnimation { result = "Paid" } }
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { expanded = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { onClose() }
    }

    @ViewBuilder private var details: some View {
        VStack(spacing: 12) {
            if let result {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(Theme.online)
                    Text(LK(result)).font(.system(size: 19, weight: .bold)).foregroundStyle(.white)
                    Text("No real money is charged").font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                }.frame(maxWidth: .infinity)
            } else if offering {
                HStack(spacing: 6) {
                    Text("€").font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
                    TextField("Your price", text: $offer).keyboardType(.numberPad)
                        .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white).tint(Theme.accent)
                }
                .padding(.horizontal, 14).frame(height: 52)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                primary("Send offer") { withAnimation { result = "Offer sent" } }
                    .disabled(offer.isEmpty).opacity(offer.isEmpty ? 0.5 : 1)
            } else {
                Text("Lightly worn, great condition. Pickup or delivery.")
                    .font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                primary("Buy") { showPay = true }
                secondary("Offer your price") { withAnimation { offering = true } }
            }
        }
    }

    private func primary(_ text: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
    private func secondary(_ text: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 17, weight: .medium)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// Simulated payment — clearly a demo: no real money, no card details.
struct DemoPaymentView: View {
    let price: String
    let onPaid: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var processing = false

    var body: some View {
        VStack(spacing: 14) {
            Capsule().fill(Theme.stroke).frame(width: 40, height: 5).padding(.top, 10)
            Text("Demo payment").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.textPrimary)
            Text("No real money is charged").font(.system(size: 13)).foregroundStyle(Theme.textMuted)
            Text(price).font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary).padding(.vertical, 6)
            Button {
                processing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { onPaid(); dismiss() }
            } label: {
                HStack(spacing: 8) {
                    if processing { ProgressView().tint(.white) } else { Image(systemName: "faceid") }
                    Text(processing ? "…" : "Pay")
                }
                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }.disabled(processing)
            Spacer()
        }
        .padding(.horizontal, 20)
        .presentationDetents([.height(300)])
        .background(Theme.bg)
        .preferredColorScheme(.dark)
    }
}

struct SearchSurface: View {
    let dismiss: () -> Void = {}
    @State private var query = ""
    @FocusState private var searchFieldFocused: Bool
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 9) {
                    Button(action: dismiss) { Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold)) }
                    Image(systemName: "magnifyingglass")
                    TextField("People, channels, messages, cards", text: $query)
                        .textInputAutocapitalization(.never)
                        .focused($searchFieldFocused)
                        .submitLabel(.search)
                        .foregroundStyle(Theme.textPrimary)
                }
                .foregroundStyle(Theme.textMuted).padding(.horizontal, 14).frame(height: 48)
                .background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if !query.isEmpty {
                    Text("Results").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textMuted).textCase(.uppercase).padding(.top, 8)
                    SearchResultRow(icon: "person.crop.circle.fill", title: query, detail: "Person")
                    SearchResultRow(icon: "rectangle.stack.fill", title: "Card «\(query)»", detail: "Found in channels and chats")
                }
            }
            .foregroundStyle(Theme.textPrimary).padding(.horizontal, 20).padding(.top, 12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .task {
            searchFieldFocused = true
        }
    }
}

struct SearchResultRow: View {
    let icon: String; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.accent).frame(width: 42, height: 42).background(Theme.surfaceStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) { Text(LK(title)).font(.system(size: 16, weight: .semibold)); Text(LK(detail)).font(.system(size: 13)).foregroundStyle(Theme.textSecondary) }
            Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textMuted)
        }.padding(.vertical, 6)
    }
}

struct ChannelsSurface: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Channels").font(.system(size: 34, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "plus").font(.system(size: 17, weight: .semibold)).frame(width: 38, height: 38).background(Theme.surfaceStrong, in: Circle())
                }
                .foregroundStyle(Theme.textPrimary).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)

                ChannelRow(title: "Not Design", photo: "https://picsum.photos/seed/notdesign/200", preview: "Shared post is ready — take a look", time: "now", unread: 2)
                ChannelRow(title: "Tech, Briefly", photo: "https://picsum.photos/seed/techbriefly/200", preview: "Why less is faster", time: "5h", unread: 0)
                ChannelRow(title: "Live", photo: "https://picsum.photos/seed/livechan/200", preview: "Three things that sold in an hour", time: "yesterday", unread: 0)
            }
        }
    }
}

struct CallsSurface: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Calls").font(.system(size: 34, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "phone.badge.plus").font(.system(size: 17, weight: .semibold)).frame(width: 38, height: 38).background(Theme.surfaceStrong, in: Circle())
                }
                .foregroundStyle(Theme.textPrimary).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)

                Text("Recent").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.textMuted).textCase(.uppercase)
                    .padding(.horizontal, 20).padding(.bottom, 7)

                CallRow(name: "Mark", photo: "https://i.pravatar.cc/200?img=12", detail: "Outgoing · today, 14:32", missed: false)
                CallRow(name: "Kira Lindegaard", photo: "https://i.pravatar.cc/200?img=45", detail: "Incoming · yesterday, 19:08", missed: false)
                CallRow(name: "Berlin Trip", photo: "https://picsum.photos/seed/berlin/200", detail: "Missed · yesterday, 17:41", missed: true)
            }
        }
    }
}

struct CallRow: View {
    let name: String; let photo: String; let detail: String; let missed: Bool
    var body: some View {
        HStack(spacing: 13) {
            Avatar(size: 52, url: photo)
            VStack(alignment: .leading, spacing: 4) {
                Text(LK(name)).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                HStack(spacing: 5) {
                    Image(systemName: missed ? "phone.arrow.down.left" : "phone.arrow.up.right").font(.system(size: 12, weight: .semibold))
                    Text(LK(detail)).font(.system(size: 14)).foregroundStyle(missed ? Theme.coral : Theme.textSecondary)
                }
            }
            Spacer()
            Image(systemName: "phone").font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
    }
}

struct ChannelRow: View {
    let title: String; let photo: String; let preview: String; let time: String; let unread: Int
    var body: some View {
        HStack(spacing: 13) {
            Avatar(size: 52, url: photo)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(LK(title)).font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(Theme.accent)
                    Spacer(minLength: 4)
                    Text(LK(time)).font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                }
                HStack(spacing: 5) {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.textMuted)
                    Text(LK(preview)).font(.system(size: 14)).foregroundStyle(unread > 0 ? Theme.textPrimary : Theme.textSecondary).lineLimit(1)
                    Spacer(minLength: 4)
                    if unread > 0 { Text("\(unread)").font(.system(size: 11, weight: .bold)).foregroundStyle(.black).frame(width: 21, height: 21).background(Theme.coral, in: Circle()) }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12).contentShape(Rectangle())
    }
}

struct ProfileSurface: View {
    @Binding var backgroundItem: PhotosPickerItem?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Avatar(size: 82, url: "https://i.pravatar.cc/200?img=68")
                Text("Alexey").font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Stories, posts, products").font(.system(size: 14)).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 10) { ProfileMetric(value: "12", label: "posts"); ProfileMetric(value: "4", label: "products"); ProfileMetric(value: "38", label: "contacts") }
                PhotosPicker(selection: $backgroundItem, matching: .images) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo")
                        Text("Choose app background")
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 15)
                    .frame(height: 52)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                HStack { Text("Products").font(.system(size: 20, weight: .bold)); Spacer(); Image(systemName: "plus") }.padding(.top, 12)
                HStack(alignment: .top, spacing: 12) { EmbeddedCard(); Spacer() }
            }.foregroundStyle(Theme.textPrimary).padding(.horizontal, 20).padding(.top, 24)
        }
    }
}

struct ProfileMetric: View {
    let value: String; let label: String
    var body: some View { VStack(spacing: 3) { Text(value).font(.system(size: 18, weight: .bold)); Text(LK(label)).font(.system(size: 12)).foregroundStyle(Theme.textSecondary) }.frame(maxWidth: .infinity).padding(.vertical, 11).background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
}

struct StoryView: View {
    let story: Story
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if !story.isNew, let u = URL(string: story.cover) {
                    AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: {
                        LinearGradient(colors: story.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                } else {
                    LinearGradient(colors: story.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .ignoresSafeArea()
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Avatar(initial: story.initial, fill: story.fill, size: 34, url: story.avatar.isEmpty ? nil : story.avatar)
                    if story.isShared {
                        Image(systemName: "plus").foregroundStyle(.white.opacity(0.8))
                        Avatar(initial: story.secondInitial, fill: story.secondFill, size: 34, url: story.secondAvatar.isEmpty ? nil : story.secondAvatar)
                    }
                    Text(story.isShared ? LK("Shared story") : LK(story.title)).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                }
                Text(story.isShared ? "Two authors. One story." : "24-hour story").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }.padding(24)
        }
    }
}

// Full-screen story viewer: opens from a thumbnail, swipe left/right between
// stories, swipe down to dismiss.
struct StoryPager: View {
    let stories: [Story]
    @State private var current: Story.ID
    let onClose: () -> Void
    @State private var dragY: CGFloat = 0

    init(stories: [Story], current: Story.ID, onClose: @escaping () -> Void) {
        self.stories = stories
        self._current = State(initialValue: current)
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $current) {
                ForEach(stories) { story in
                    StoryView(story: story).tag(story.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .padding(10).background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 8).padding(.trailing, 16)
        }
        .offset(y: dragY)
        .gesture(
            DragGesture()
                .onChanged { v in if v.translation.height > 0 { dragY = v.translation.height } }
                .onEnded { v in
                    if v.translation.height > 120 { onClose() }
                    else { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { dragY = 0 } }
                }
        )
    }
}

struct Story: Identifiable {
    let id = UUID(); let title: String; let initial: String; let fill: Int
    let isShared: Bool; let secondInitial: String; let secondFill: Int
    let colors: [Color]; let isNew: Bool
    var cover: String = ""; var avatar: String = ""; var secondAvatar: String = ""
    static let newStory = Story(title: "Yours", initial: "Y", fill: 2, isShared: false, secondInitial: "", secondFill: 0, colors: Theme.fills[2], isNew: true)
}

struct DemoMessage: Hashable { let text: String; let incoming: Bool; var card: Bool = false }

struct Chat: Identifiable, Hashable {
    let id: String; let name: String; let initial: String; let fill: Int
    let preview: String; let time: String; let unreadCount: Int
    let isOnline: Bool; let hasCard: Bool; let isGroup: Bool; let participantCount: Int
    var photo: String = ""; var groupPhotos: [String] = []
    var messages: [DemoMessage] = []
}

enum SampleData {
    static let stories = [
        Story(title: "Mark", initial: "M", fill: 0, isShared: false, secondInitial: "", secondFill: 0, colors: Theme.fills[0], isNew: false, cover: "https://picsum.photos/seed/markcover/300", avatar: "https://i.pravatar.cc/200?img=12"),
        Story(title: "Masha", initial: "M", fill: 1, isShared: true, secondInitial: "A", secondFill: 3, colors: Theme.fills[3], isNew: false, cover: "https://picsum.photos/seed/mashacover/300", avatar: "https://i.pravatar.cc/200?img=5", secondAvatar: "https://i.pravatar.cc/200?img=9"),
        Story(title: "Design", initial: "D", fill: 2, isShared: false, secondInitial: "", secondFill: 0, colors: Theme.fills[2], isNew: false, cover: "https://picsum.photos/seed/designcover/300", avatar: "https://picsum.photos/seed/designava/200"),
        Story(title: "Ilya", initial: "I", fill: 3, isShared: false, secondInitial: "", secondFill: 0, colors: Theme.fills[3], isNew: false, cover: "https://picsum.photos/seed/ilyacover/300", avatar: "https://i.pravatar.cc/200?img=13")
    ]
    static let chats = [
        Chat(id: "mark", name: "Mark", initial: "M", fill: 0, preview: "Hey! Are the sneakers still available?", time: "now", unreadCount: 1, isOnline: true, hasCard: false, isGroup: false, participantCount: 0, photo: "https://i.pravatar.cc/200?img=12", messages: [
            DemoMessage(text: "Hey! Are the sneakers still available?", incoming: true),
            DemoMessage(text: "Yes! Sending the card.", incoming: false),
            DemoMessage(text: "", incoming: false, card: true),
            DemoMessage(text: "Looks great. I'll text you tonight.", incoming: true)
        ]),
        Chat(id: "design", name: "Not Design", initial: "N", fill: 1, preview: "Shared post is ready — take a look", time: "2h", unreadCount: 0, isOnline: false, hasCard: true, isGroup: false, participantCount: 0, photo: "https://picsum.photos/seed/notdesign/200", messages: [
            DemoMessage(text: "Shared post is ready — take a look", incoming: true),
            DemoMessage(text: "Nice, love the before/after", incoming: false)
        ]),
        Chat(id: "friends", name: "Berlin Trip", initial: "B", fill: 2, preview: "Masha added a new photo", time: "5h", unreadCount: 4, isOnline: false, hasCard: false, isGroup: true, participantCount: 4, groupPhotos: ["https://i.pravatar.cc/200?img=15", "https://i.pravatar.cc/200?img=20"], messages: [
            DemoMessage(text: "Masha added a new photo", incoming: true),
            DemoMessage(text: "Looks amazing", incoming: false),
            DemoMessage(text: "Who's booking the hostel?", incoming: true)
        ]),
        Chat(id: "kira", name: "Kira Lindegaard", initial: "K", fill: 3, preview: "See you tonight", time: "yesterday", unreadCount: 0, isOnline: true, hasCard: false, isGroup: false, participantCount: 0, photo: "https://i.pravatar.cc/200?img=45", messages: [
            DemoMessage(text: "See you tonight", incoming: true),
            DemoMessage(text: "Yes! 7pm?", incoming: false),
            DemoMessage(text: "Perfect", incoming: true)
        ])
    ]
}

struct GroupAvatar: View {
    var fill: Int; var size: CGFloat; var photos: [String] = []
    var body: some View {
        ZStack {
            Avatar(initial: "M", fill: fill, size: size * 0.62, url: photos.first).offset(x: -size * 0.16, y: -size * 0.15)
            Avatar(initial: "A", fill: (fill + 1) % Theme.fills.count, size: size * 0.62, url: photos.count > 1 ? photos[1] : nil).offset(x: size * 0.16, y: size * 0.15)
        }.frame(width: size, height: size)
    }
}

struct Avatar: View {
    var initial: String = ""
    var fill: Int = 0
    var size: CGFloat
    var url: String? = nil

    private var corner: CGFloat { size * 0.3 }

    var body: some View {
        Group {
            if let url, let u = URL(string: url) {
                AsyncImage(url: u, transaction: Transaction(animation: .easeOut(duration: 0.25))) { phase in
                    if let img = phase.image { img.resizable().scaledToFill().transition(.opacity) }
                    else { fallback }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var fallback: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(LinearGradient(colors: Theme.fills[fill % Theme.fills.count], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay { Text(initial).font(.system(size: size * 0.42, weight: .semibold)).foregroundStyle(.white) }
    }
}
