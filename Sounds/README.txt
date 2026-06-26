SOUNDS README
=============
Replace these .aiff placeholder files with real audio assets.

Recommended:
- transaction_added.aiff  → pleasant chime (~0.3s)
- payment_received.aiff   → success sound (~0.5s)
- reminder_complete.aiff  → tick/check sound (~0.2s)
- backup_success.aiff     → ascending tone (~0.5s)
- faceid_success.aiff     → subtle unlock (~0.3s)
- overdue_alert.aiff      → warning tone (~0.5s)
- button_tap.aiff         → soft tap (~0.1s)
- error.aiff              → error buzz (~0.3s)

Free sources:
- https://freesound.org
- https://mixkit.co/free-sound-effects/
- https://zapsplat.com

Convert to .caf for iOS:
  afconvert input.wav output.caf -d ima4 -f caff
