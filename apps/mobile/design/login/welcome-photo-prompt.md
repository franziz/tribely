# Tribely — Welcome screen mood photograph

## Use

The hero image on the pre-auth Welcome screen (`apps/mobile`, route `/welcome`).
Edge-to-edge across the top ~50% of the screen, behind the headline
"Find your people, anywhere."

## Aspect / format

- Portrait orientation
- Aspect ratio between 4:5 and 3:4 (the screen crop is roughly 9:8 of the
  full image, so we need head- and bleed-room top + bottom)
- Min 2400px on the long edge, 8-bit RGB, sRGB color space
- Exported as **WebP**, quality ≥ 85; expected final size 400–800 KB
- Save at: `apps/mobile/assets/images/welcome-hero.webp`

## Subject

A real-life evening gathering moment in Singapore. Specifically:

- A hawker centre, kopitiam, or small neighborhood restaurant at dusk /
  early evening (golden-hour into blue-hour transition).
- People present BUT anonymous — no recognizable faces. Backs of heads,
  hands holding chopsticks or beer, silhouettes, mid-conversation gestures.
  The point is "this looks like an evening worth showing up to," not
  "look at this exotic destination."
- Warm artificial light from above (hawker stall fluorescents,
  tungsten lamps, neon signage) is the signature of the shot.
- Small details that read "Singapore" without being touristy:
  red plastic stools, condensation on a Tiger Beer glass, a stack of
  trays, a bowl of sambal, a weathered chop on a sign.

## Light

- Mixed light: ambient blue-hour from outside + warm artificial inside.
- The viewer's eye should land on a warm focal point (a lit sign, a
  bowl of food, a hand). Surrounding falls darker.
- NOT studio-lit. NOT overcast flat. Embrace shadow and grain.

## Composition

- Low angle (camera around table-height) — puts the viewer "in" the
  scene rather than looking down on it.
- Wide-ish lens (24–35mm equivalent), some environmental context.
- Foreground / midground / background layered — depth, not a flat
  product shot.
- Negative space in the upper portion (sky, ceiling beams, signage) so
  the headline can sit cleanly over it.

## Post / treatment

- Slight desaturation of greens and blues (~−15) so warm tones dominate.
- Warm gradient overlay applied **in-app** (don't bake it in): 18% opacity,
  ember coral (`#D85730` light) / brass (`#D5A86F` dark) on the lower third.
- 3% film grain overlay applied in-app.

## Strictly avoid

- Generic "travel" imagery: airplane wings, suitcases, airports,
  passports, beach sunsets (Bali, Phuket, Maldives), backpacker hostels.
- Recognizable Singapore landmarks: Marina Bay Sands, Merlion, Gardens
  by the Bay, Changi. Too touristic — Tribely is for the local moment,
  not the postcard.
- Stock-photo "diverse friends laughing at camera" energy. Faces facing
  camera at all is wrong.
- Over-stylized / over-saturated / HDR. We want the texture of real
  evening light, not Instagram preset.
- Models. The figures should read as "people who happen to be there,"
  not posed.
- Group selfies, peace signs, drinks held up to camera.

## For AI image generation (Midjourney / similar)

Prompt seed:

> A hawker centre in Singapore at dusk, low angle from a red plastic
> stool, anonymous figures mid-conversation, warm tungsten and
> fluorescent overhead light spilling onto a marble table with bowls and
> beer glasses, blue-hour outside through open shutters, shallow depth
> of field, 35mm film grain, photographed by a documentary photographer,
> muted desaturated greens and blues, no recognizable faces, no
> landmarks --ar 4:5 --style raw

Negative: tourist, beach, sunset, suitcase, airplane, marina bay sands,
merlion, hdr, oversaturated, faces to camera, posed, peace sign, model,
selfie, instagram filter, studio lighting

## For stock search

Search terms: "hawker centre dusk anonymous", "kopitiam evening", "asian
night market low angle warm light", "back of head dinner street food
asia". Filter HARD against tourist / family-laughing / aerial drone shots.

## For commission

A 2-hour shoot at one of: Tiong Bahru Market, Old Airport Road Hawker,
Maxwell, Lau Pa Sat (avoid the photographed-to-death center of Lau Pa
Sat — go to the edges). Cost ~SGD 800–1500 plus location releases.
Brief the photographer: "documentary, no posed shots, shoot what's
already there." Get model releases for any face that ends up
identifiable, even if we plan to avoid them — having the releases means
we can use the takes that work later.

## Versions to deliver

- 2400×3000 portrait master (source of truth, kept outside the repo)
- `welcome-hero.webp`: 1920×2400 WebP @ 85% quality, committed to the repo
- A neutral fallback (warm-cream solid block with ink mark centered) is
  built into the app — we don't need to ship a placeholder asset. If the
  photo file is missing, the welcome page renders the fallback cleanly.
