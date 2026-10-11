# Pueblo and MXP Mac preview

This experimental branch extends jimcheng256's modernized Atlantis and uses the
matching Lemuria fork. The baseline release remains available separately.

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
