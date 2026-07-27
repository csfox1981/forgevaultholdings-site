#!/bin/bash
# Generates every Higgsfield prompt file for the ForgeVault world.
# Edit the SUBJECT/MOVE blocks below and re-run to regenerate prompts.
WORK="$(cd "$(dirname "$0")" && pwd)"

PREAMBLE='Cinematic photoreal industrial interior, a vast dark foundry-vault complex rendered in deep navy shadow and lit from within by molten orange forge glow and thin electric-blue circuit tracery running through the architecture. Brushed steel, blackened iron, machined brass, and armored glass. Volumetric haze, dramatic rim light, shallow depth of field, anamorphic wide-angle, premium editorial quality. Cohesive color palette of void navy #010821, vault navy #0B1B3A, circuit blue #2F8FBF, arc cyan #3FDFFF, forge orange #F08430, ember gold #FCC048. Centered composition, empty and unoccupied, no people, no figures, architectural, no text, no letters, no numbers, no logos.'

TAIL='Dark foundry-vault interior, molten orange forge glow and electric-blue circuit tracery, brushed steel and armored glass, volumetric haze, deep navy shadow, empty and unoccupied, no people, no figures. Smooth, graceful, slow motion, subtle parallax. No text, no captions.'

still () { printf '%s\nSubject: %s\n' "$PREAMBLE" "$2" > "$WORK/still_$1.txt"; }
leg   () { printf 'Single continuous cinematic camera move, no cuts. Continue the same slow, steady forward glide. %s. The camera moves into %s toward %s. In the final second, settle back into a slow, steady forward glide toward %s. %s\n' "$2" "$3" "$4" "$5" "$TAIL" > "$WORK/leg_$1.txt"; }

# ---- 1. THE FORGE ----------------------------------------------------------
still forge 'A colossal anvil on a raised steel plinth at the heart of a dark foundry hall, a suspended power hammer poised above it, molten orange sparks arcing off the anvil face and drifting up into the dark, thin blue circuit lines tracing the floor plates away toward a distant sealed vault door.'
leg forge 'pushing in close to the molten sparks on the anvil face until they nearly fill the frame, then easing gently back out' 'the foundry hall' 'the anvil and the falling power hammer' 'the distant sealed vault door'

# ---- 2. THE VAULT ----------------------------------------------------------
still vault 'A massive circular bank-vault door of brushed steel and machined brass, half swung open on its hinge, concentric gear rings and locking bolts traced with glowing blue circuitry, warm orange light spilling from the chamber beyond across a polished dark floor.'
leg vault 'sweeping in a slow half-orbit around the open vault door, keeping it centered, then continuing past it through the opening' 'the vault chamber' 'the glowing gear rings of the open door' 'a bright archway leading deeper inside'

# ---- 3. BIOPRINT -----------------------------------------------------------
still bioprint 'A tall dark data hall with curved walls of floor-to-ceiling armored glass panels displaying luminous cyan line graphs and layered biometric waveforms, a vast fingerprint pattern etched in glowing light across the far wall, a single machined steel console island at the centre of the room.'
leg bioprint 'tracking low and level alongside the glowing data panels, the foreground console edges sliding past in parallax' 'the data hall' 'the great glowing fingerprint on the far wall' 'a narrow lit passage at the far end of the hall'

# ---- 4. IGNITEREGEN --------------------------------------------------------
still igniteregen 'A precision analytical instrument bay, rows of sealed empty glass vials seated in machined steel racks under cold blue light, a large chromatograph trace glowing on a dark glass readout panel, calibration instruments and a lit spectrometer bench, clinical, exact and unoccupied.'
leg igniteregen 'tracking low and level along the racks of sealed vials, the glowing chromatograph readout sliding past on the left in parallax' 'the instrument bay' 'the illuminated racks of sealed vials at the centre' 'a dim doorway at the back of the bay'

# ---- 5. THE WORKSHOP -------------------------------------------------------
still workshop 'A dim workshop bay of large machines shrouded under heavy canvas covers, glowing blueprint schematics projected above a steel drafting table, machined prototype parts and tool racks along the walls, a single work lamp throwing warm orange light across the covered shapes.'
leg workshop 'rising smoothly as the full scale of the workshop bay reveals below' 'the workshop bay' 'the glowing blueprint table among the shrouded machines' 'a tall lit gallery entrance ahead'

# ---- 6. THE VAULT HALL (finale) -------------------------------------------
still hall 'A grand vaulted gallery with a row of illuminated alcoves along both walls, each alcove holding a tall monolithic obelisk of armored glass lit from within, the row converging on a single raised emblem plinth at the far end, warm orange uplight and blue circuit tracery running through the floor.'
leg hall 'rising smoothly as the full length of the gallery reveals, the lit alcoves passing by on both sides' 'the vaulted gallery' 'the raised emblem plinth at the far end' 'the glowing plinth as it fills the frame'

ls -1 "$WORK"/still_*.txt "$WORK"/leg_*.txt | sed "s|$WORK/||"
