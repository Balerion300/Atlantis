## Room-image scrolling follow-up — 16 October

Aimery confirmed that object and exit command links work in our rendering preview,
but reported that a room description can stop scrolling before its contents and
exits are visible. The image-completion path invalidated the attachment layout
without following the newly enlarged document. It now completes that layout and
scrolls to the end only when the pane was already following output. Readers who
have scrolled back retain their position. Images no longer present in a pane do
not change its scroll position.

`Tests/Packaged/ScrollProbe.m` exercises the actual packaged app offline with a
synthetic room and delayed image growth, including a reader in scrollback. This
check does not connect to the game or send commands. Player confirmation of the
scrolling follow-up remains necessary.

The native comparison reproduced a 319-point gap below the released app's visible
output after image growth; the patched app reached the bottom (zero gap). The
scrollback reader remained at the same 80-point scroll position in both apps,
and an absent attachment caused no movement. The native build, 43 focused
markup/image checks, three styled-output checks, and Telnet/MXP checks passed.
[Build and offline comparison](https://github.com/Balerion300/Atlantis/actions/runs/38969214371).

## Additional native room comparison — 16 October

The old and repaired released apps were also connected as separate guests and brought to Balerion's actual room, then returned to their starting lounge. Both received room-image URLs and created two native image attachments. The repaired app retained room text and command-link attributes without literal protocol tags; normal angle-bracket help/channel/exit labels remain plain text. The old app still leaked the initial closing XCH_MUDTEXT control. Broad raw-tag corruption was not reproduced there, so Aimery's precise report still needs their room/configuration or a retest. Reports redact room prose and player output before artifact upload. [Native room comparison](https://github.com/Balerion300/Atlantis/actions/runs/38967061933).

## 16 October 2026 rendering repair

The 11 October published app was exercised against Blood of Dragons using its actual native world/session classes on a macOS 15.7.9 Apple Silicon runner. Plain Telnet received the full game response but lost most styled output when the disabled markup filter replaced its mutable input with itself. The filter now leaves unchanged input untouched. With Pueblo enabled, PennMUSH's initial closing literal-mode tag leaked into the transcript, and its hide-graphics control produced a false image placeholder. Both controls are now consumed without adding visible text or image requests.

Focused tests and a fresh packaged-app guest connection over plain Telnet, Pueblo/Telnet and Pueblo/TLS passed. The normal welcome, guest-room description and exits are present; protocol tags and the false image placeholder are absent; Pueblo command-link attributes remain. Only the public Guest login, look and protocol handshake were sent. No private profiles or credentials are bundled.

This does not establish Aimery's exact room/settings report is fully resolved. That report needs a player retest. The guest room supplied no image URL, so real remote-image acceptance is not claimed by this live check. Downloads retain ad-hoc signing and are not notarized. Quit every running Atlantis copy, unzip the update separately, and enable Pueblo in Address Book → Pueblo and MXP before reconnecting. Existing Address Book settings are retained.

---

# Pueblo and MXP Mac preview

This experimental branch extends jimcheng256's modernized Atlantis and uses the
matching Lemuria fork. The baseline release remains available separately.

The spacing update treats PennMUSH's paired `<BR>` and trailing wire newline
as one display break, preserving intentional blank lines and fixed-width
spacing. Closing preformatted blocks and paragraph tags no longer insert a
redundant newline when the last output line already ended. Inline image loading
and clickable links retain their existing behavior.

## Turn it on

Open the Address Book, edit the world (or its character), and select **Pueblo and
MXP**. Enable Pueblo for Blood of Dragons. Enable **Load inline images from the
game** if wanted, then reconnect. MXP is a separate option for games that offer
it. Both protocols and image loading start off. Character settings can inherit
the world settings.

Click a game command link to send its command. Receiving the link does not send
anything. Web links use the existing browser handling. Command links stop
working after disconnect/reconnect; this prevents old scrollback links from
being reused in a different connection.

## Implemented display subset

- Pueblo greeting and `PUEBLOCLIENT 1.10` response, once per connection.
- Pueblo HTML/text mode controls and `xch_mudtext` literal sections.
- `a href`, `a xch_cmd`, inline `img src`, basic bold/italic/underline/color,
  breaks, paragraphs, and common/numeric entities. Existing ANSI attributes stay.
- MXP Telnet option 91, start subnegotiation, open/secure/locked/reset modes,
  temporary secure and persistent default modes. Secure command/image tags are
  rejected in open lines. Open formatting closes at newline.
- MXP `SEND HREF`, `A HREF`, `IMAGE FNAME URL`, basic formatting,
  version and supported-subset replies, including attribute queries. SEND
  menus, PROMPT and text-derived commands remain ordinary text in this preview.
- Fragmented markup, a 4 KiB token limit, 64-level nesting and 4096 command links
  per connection. No browser engine or automatic script execution.
- Asynchronous HTTP/HTTPS images: up to 16 pending requests, 2 MiB compressed
  per image, 4 megapixels, 4096 pixels per side, bounded redirects and timeouts.
  Images are downsampled and displayed within 560 by 320 points. Images use an
  ephemeral session with no cookies; no file URLs or embedded credentials.

## Deliberate limits of this first preview

This is not full MXP 1.0 parity. Custom ELEMENT/ENTITY definitions, automapping,
server frames, relocation, sounds, gauges, SEND menus and advanced CSS/tables are
not implemented. Pueblo server-controlled panes/page clearing and browser page
navigation are also outside this first link/image milestone. Unsupported active
markup has no side effects; locked text remains literal.

Images show a placeholder while loading or if blocked/unavailable. Animated
images display their first frame. Existing log formats may represent image
attachments as object replacement characters; plain text logs remain usable.

## What is verified and what needs a Mac user

GitHub's Apple Silicon runner compiles the app, runs focused parser/image
fixtures against a local server, and verifies an ad-hoc signature. These checks
do not prove native interactive behavior, live game negotiation, Gatekeeper
acceptance, or connection-specific server behavior. A Mac user should first
test the unchanged baseline, then this preview with Pueblo and images enabled.

Build target: Apple Silicon, macOS 13.5 or later. Test builds are not notarized.
Back up Atlantis preferences before testing; this fork retains the original
application settings identity. No personal worlds or passwords are bundled.

Protocol references: [MXP specification](https://www.zuggsoft.com/zmud/mxp.htm)
and [Pueblo compatibility notes](https://www.zuggsoft.com/zmud/zmudpueblo.htm).
