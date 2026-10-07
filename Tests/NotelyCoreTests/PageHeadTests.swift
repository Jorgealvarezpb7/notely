import Foundation
import NotelyCore
import Testing

private let base = URL(string: "https://example.com/a/b")!

struct PageHeadTests {
    @Test func readsOpenGraphTagsAndIcons() {
        let html = """
        <html><head>
        <title>Plain title</title>
        <meta property="og:title" content="OG &quot;Title&quot;">
        <meta name="description" content="Plain   description">
        <meta property="og:image" content="/img.png">
        <link rel="icon" href="favicon.png">
        <link rel="apple-touch-icon" href="https://Example.com/touch.png#x">
        </head><body></body></html>
        """
        let head = PageHead.parse(html, base: base)
        #expect(head.title == "OG \"Title\"")
        #expect(head.description == "Plain description")
        #expect(head.image == URL(string: "https://example.com/img.png"))
        #expect(head.icons == [URL(string: "https://example.com/touch.png")!,
                               URL(string: "https://example.com/a/favicon.png")!])
    }

    @Test func fallsBackToTitleTag() {
        let head = PageHead.parse("<head><title>  Page &amp;\n  Title </title></head>", base: base)
        #expect(head.title == "Page & Title")
        #expect(head.description == nil)
        #expect(head.image == nil)
        #expect(head.icons.isEmpty)
    }

    @Test func noTitleAtAll() {
        #expect(PageHead.parse("<head></head><body>Hi</body>", base: base).title == nil)
    }

    @Test func ignoresTagsAfterHead() {
        let html = """
        <head><title>T</title></head>
        <body><meta property="og:description" content="from body"></body>
        """
        #expect(PageHead.parse(html, base: base).description == nil)
    }

    @Test func readsSingleQuotedAndUnquotedValues() {
        let head = PageHead.parse("<head><meta property='og:title' content=Unquoted></head>", base: base)
        #expect(head.title == "Unquoted")
    }

    @Test func decodesNumericEntitiesAndKeepsUnknownOnes() {
        let head = PageHead.parse("<head><title>&#65;&#x42; &bogus;</title></head>", base: base)
        #expect(head.title == "AB &bogus;")
    }

    @Test func asksForHttpImagesAsHttps() {
        let head = PageHead.parse(#"<head><meta property="og:image" content="http://example.com/i.png"></head>"#, base: base)
        #expect(head.image == URL(string: "https://example.com/i.png"))
    }

    @Test func dropsNonWebImages() {
        let head = PageHead.parse(#"<head><meta property="og:image" content="data:image/png;base64,AAAA"></head>"#, base: base)
        #expect(head.image == nil)
    }
}

struct LinkPageKeyTests {
    @Test func normalizesSchemeHostAndPath() {
        #expect(linkPageKey(for: URL(string: "HTTP://Example.COM")!) == URL(string: "https://example.com/"))
    }

    @Test func dropsFragment() {
        #expect(linkPageKey(for: URL(string: "https://a.com/x#y")!) == URL(string: "https://a.com/x"))
    }
}
