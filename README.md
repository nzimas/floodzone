## FLOODZONE: 3-slot granular sample player with smooth morphing and extensive randomisation

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

**Inherited from Twine and Thrine**

- Press K2 to randomise granular params and pitch in slot 1
- Press K3 to randomise granular params and pitch in slot 2
- Turn E2 to scan through slot 1
- Turn E3 to scan through slot 2
- Long-press K1 to randomise granular params and pitch in slot 3

**Floodzone-only**

- Load a sample per slot (it can be the same sample)
- Adjust the transition time parameter in the EDIT menu
- Go back to the main screen
- Long-press K2 to switch to another sample slot
- Tinker with the many settings available per sample slot

### Download / Install

Floodzone - v 20250205 -  https://github.com/nzimas/floodzone/blob/main/floodzone.lua

Or via maiden:
`;install https://github.com/nzimas/floodzone`
