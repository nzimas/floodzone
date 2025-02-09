## FLOODZONE: 3-slot granular sample nanipulation with smooth morphing, extensive randomisation and harmonizer

FLOODZONE builds upon [Twine](https://norns.community/twine) and [Thrine](http://llllllll.co/t/thrine/70762/3) to offer evolving granular soundscapes and textures, by morphing seamlessly between sample slots.

### Overview

In addition to all the features found in Twine and Thrine, Floodzone has completely new screen visuals, comprising 3 horizontally aligned squares. 

The square that represents the active slot is filled, whereas the other 2 remain empty until a transition is engaged.

When **K2** is long-pressed, the transition begins and the next randomly picked slot will start to fill up, while the currently active slot will be emptying at the same rate, in sync with the audio crossfade set in the transition time parameter (up to 90 secs).

The higher the transition time, the smoother the morphing.

Audio demo:
[https://drive.google.com/file/d/1xeN0hV0-saPefjAblRql0KOoiZr85TSb/view?usp=sharing](https://drive.google.com/file/d/1xeN0hV0-saPefjAblRql0KOoiZr85TSb/view?usp=sharing)

### Main screen
![IMG_20250205_123341](https://github.com/user-attachments/assets/df9c52d6-417e-4372-9199-4034112740a2)


### Requirements

Norns / Norns Shield / Fates

### Documentation

## 1. Overview & Interaction

### Keys

- **K2** (Short-press):  
  Randomizes **Slot 1**.

- **K2** (Long-press):  
  Initiates a **transition** from the **active slot** to a new slot picked at random (either slot 1, 2, or 3).  
  During transition, the new slot is faded in and randomized.  

- **K3** (Short-press):  
  Randomizes **Slot 2**.

- **K3** (Long-press):  
  **Triggers two extra harmony slots** (4 & 5). These harmony slots:  
  - Load the **same sample** as the active slot, but with different pitches set at intervals locked to scale
  - Randomize their own granular parameters in the background
  - Fade in to user-set volumes/pans. 

  Releasing K3 fades the harmony slots back out.

### Encoders

- **E1**:  Adjusts **volume** (in dB) for Slots 1, 2, and 3 simultaneously.  
- **E2**:  
  Adjusts the **seek** parameter for **Slot 1**.  
- **E3**:  
  Adjusts the **seek** parameter simultaneously for **Slot 2** (forward) and **Slot 3** (in the opposie direction of the turning of the encoder).

---

## 2. Parameter Reference

All parameters are grouped by section in the Norns EDIT menu. Below is a quick description of each:

### 2.1 Random Sample

1. **random sample?** (no / yes)  
   - If "yes," whenever a transition occurs, a random sample is automatically loaded into the new slot from the specified directory.

2. **sample directory**  
   - Path to a folder containing *.wav, *.aif, *.aiff, or *.flac files. Used for random sample loading; you must choose any sample from said directory as a token, so that the path to the directory can be built corredctly.

---

### 2.2 Samples

Each slot **1**, **2**, and **3** has identical parameters:

1. **(i) sample**  
   - Direct file selector for slot i’s sample.

2. **(i) playhead rate**  
   - Controls playback speed (0 – 4× normal). Values below 1 slow playback, above 1 speed it up.

3. **(i) playhead direction** (>> / << / <->)  
   - **>>** = forward  
   - **<<** = backward  
   - **<->** = ping-pong (automatically flips direction every 2 seconds)

4. **(i) volume**  
   - Volume in dB for slot i.

5. **(i) jitter**  
   - Jitter value for the granulator’s onset times.

6. **(i) size**  
   - Grain size (in ms).

7. **(i) density**  
   - Grain generation rate (in Hz).

8. **(i) pitch**  
   - Pitch in semitones (st). Internally converted to a playback speed ratio for the granulator.

9. **(i) spread**  
   - Stereo spread (%). Higher values distribute grains more broadly.

10. **(i) fade**  
   - Grain envelope time (ms). Controls both attack and decay shape.

11. **(i) seek**  
   - Position in the file, as a percent (0–100%). If random_seek is off, this is static; if on, it updates randomly.

12. **(i) random_seek** (off / on)  
   - Toggles periodic randomization of the seek position.

13. **(i) random_seek_freq**  
   - Frequency (in ms) at which the seek position is randomly updated when random_seek = on.

14. **(i) automate_density** (off / on)  
    - Toggles an internal LFO that modulates density.

15. **(i) automate_size** (off / on)  
    - Toggles an internal LFO that modulates size.

16. **(i) density_lfo**  
    - Rate (Hz) for the density LFO (if automation is on).

17. **(i) size_lfo**  
    - Rate (Hz) for the size LFO (if automation is on).

18. **(i) pitch_change?** (no / yes)  
    - If "yes," short-press randomization changes pitch.  
    - If "no," pitch is left alone when that slot is randomized.

---

### 2.3 Key & Scale

1. **root note**  
   - Select a musical root (C, C#/Db, D, etc.) for randomizing pitch in a specific key.

2. **scale**  
   - Chooses the scale type (dorian, major, etc.). 
     Used whenever the script randomizes pitch, ensuring the pitch is harmonically locked to the chosen scale.

---

### 2.4 Transition

1. **transition time (ms)**  
   - Duration of a slot transition (e.g. from slot 1 to slot 2).

2. **morph time (ms)**  
   - Used when randomizing a slot without a transition (e.g. short-press randomization). 
     Controls how quickly certain parameters morph to new values.

3. **k2_release_action** (no change / randomize)  
   - Controls what happens to the **active slot** after a K2 long-press transition is underway. 
   - If set to “randomize,” the active slot that is fading out is randomized when K2 is released.

---

### 2.5 Reverb

1. **reverb_mix**  
   - Overall reverb wet/dry mix (%).

2. **reverb_room**  
   - Reverb “room” size.

3. **reverb_damp**  
   - Damping factor (higher damping => less brightness).

---

### 2.6 Randomizer

These define the **range** of random values used whenever a slot is randomized:

1. **min_jitter / max_jitter** (ms)  
2. **min_size / max_size** (ms)  
3. **min_density / max_density** (Hz)  
4. **min_spread / max_spread** (%)  
5. **pitch_1 / pitch_2 / pitch_3 / pitch_4 / pitch_5** (st)  
   - Used internally when picking random pitches around the chosen scale intervals.  
   - The script effectively picks from scale degrees offset by these values.

---

### 2.7 Harmony

- **A_volume** / **B_volume** (dB)  
  - Target volume for Harmony Slot A / Slot B.  

- **A_pan** / **B_pan**  
  - Stereo pan position for A / B (-1 = hard left, +1 = hard right).

- **A_fade_in** / **B_fade_in** (ms)  
  - Fade-in duration when you start holding K3.

- **A_fade_out** / **B_fade_out** (ms)  
  - Fade-out duration when K3 is released.

### Download / Install

Floodzone - v 20250209

Via maiden:
`;install https://github.com/nzimas/floodzone`
