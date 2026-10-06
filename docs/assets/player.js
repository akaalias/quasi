// The page's examples: one voice note each, played as sound, as a line of marks and as a drawing
// of who is doing what. Every example is made here from a short description of what happens in
// it, so the example on the page and the ones that open over it share all of this.
//
//   const example = Quasi.mount(element, list, Quasi.compose({ answer: "answer_tasks_2" }));
//
// `element` holds a <div class="player">, which receives a copy of <template id="player">;
// `list` receives one row for each word of the vocabulary that the example uses.
const Quasi = (() => {
  // One Audio element per sound, so that a sound can be played again before it has finished.
  const play = name => { const audio = new Audio(`assets/sounds/${name}.wav`); audio.play(); return audio; };

  // Every sound the phone makes sends a ring out from it in the drawing, at the moment it sounds:
  // a wide slow one for a chime note, a short sharp one for a wood block, a small one for each
  // tick, and the widest for a closing chord. [when, how long it lasts, how far it travels, how strong it starts]
  const tasks = (count, word, sentence) => ({
    label: `"I've added ${word}"`, text: sentence, mark: ["chime answer", "i".repeat(count) + "b"],
    notes: [...Array(count).keys()].map(n => n * 200).concat(count * 200 + 60), lasts: 1860 + count * 200,
    rings: [...Array(count).keys()].map(n => [n * 200, 700, 16 + 2 * n, .8]).concat([[count * 200 + 60, 1500, 28, .9]]),
  });

  // The vocabulary. `notes` are the moments within the sound at which each part of its mark
  // sounds, `lasts` is the length of the file. A word that says something went wrong is `failed`:
  // it is drawn in ink, because orange only ever means that the app did something. One row is not
  // the phone's but `yours`: what you say, set in the serif that the app uses for your words.
  const WORDS = {
    question: { label: `"I'm listening"`, text: "You pressed record, and the recorder is streaming live audio to your locked phone.",
                mark: ["chime", "ii"], notes: [0, 220], lasts: 1620, rings: [[0, 800, 18, .8], [220, 900, 22, .8]] },
    talking: { label: "You say what is on your mind", text: "You talk the way you think, with pauses and corrections. Your locked phone receives every word while you speak.",
               mark: ["voice", "iiiiiii"], yours: true },
    wood_1: { label: `"I've heard you"`, text: "You stopped recording, and your locked phone has received the whole voice note.",
              mark: ["wood", "i"], notes: [0], lasts: 900, rings: [[0, 420, 13, .9]] },
    wood_fail_1: { label: `"I didn't get that"`, text: "You stopped recording, but the audio did not reach your phone. The wood block is lower and rings longer, and nothing follows it.",
                   mark: ["wood fail", "i"], notes: [0], lasts: 1900, rings: [[0, 1100, 16, .9]], failed: true },
    ticking: { label: `"I'm working on it"`, text: "A quiet tick-tock plays while your phone works out which tasks you asked for.", mark: ["tock", "iii"] },
    answer_tasks_1: tasks(1, "one task", "Your phone has added the task to your to-do list. It plays one quick note for the task and then a chord."),
    answer_tasks_2: tasks(2, "two tasks", "Your phone has added both tasks to your to-do list. It plays one quick note for each task and then a chord, so you can count the tasks."),
    answer_tasks_3: tasks(3, "three tasks", "Your phone has added all three tasks to your to-do list. It plays one quick note for each task and then a chord, so you can count the tasks."),
    answer_nothing: { label: `"I've kept it as a note"`, text: "You did not ask for anything, so your phone keeps what you said as a note. It plays the home note alone, without a chord.",
                      mark: ["chime answer", "b"], notes: [0], lasts: 1400, rings: [[0, 1300, 26, .85]] },
    answer_failed: { label: `"I couldn't do it"`, text: "Your phone could not work out the tasks or could not add them. The answer falls and rings out. Your note is safe.",
                     mark: ["chime fall", "ii"], notes: [0, 355], lasts: 2750, rings: [[0, 800, 18, .8], [355, 1800, 26, .8]], failed: true },
    silence: { label: "Silence", text: "No sound follows the press of the button. That is how you know that your phone is not listening.",
               mark: ["silence", "i"], notes: [0], lasts: 1500, rings: [], silent: true },
  };

  // Someone talking, without words: a murmur with the rhythm, melody and vowels of speech, so
  // there is no recording of anyone. It is made anew for every play, and each time someone else
  // is talking: a lower or a higher voice (a higher one has a shorter throat, so its resonances
  // are higher too), faster or slower, flatter or more sing-song, more or less breath in it.
  //
  // What keeps it from sounding like a machine is what a machine would leave out. The voice is
  // a softened buzz whose every cycle differs a little in length and strength. It goes through
  // three resonances that slide from vowel to vowel and often move within a syllable. Syllables
  // come in phrases: each phrase starts high and sinks, stressed syllables are longer, louder
  // and higher, and the last one falls, or now and then rises as in a question. Many syllables
  // begin with a consonant: a hiss, a short stop with a click, or a hum through the nose. And
  // the voice does not switch off between syllables, it only dips.
  //
  // Returns the sound as an address to play, and its loudness slice by slice for the bars on the line.
  const TALK = 3600, RATE = 44100;
  const VOWELS = [[700, 1150], [420, 1900], [310, 2200], [520, 950], [360, 820], [600, 1600], [480, 1350]];
  const ONSETS = ["", "", "hiss", "stop", "hum"];
  const between = (low, high) => low + Math.random() * (high - low);
  const any = list => list[Math.floor(Math.random() * list.length)];
  const resonance = width => {                   // two poles, with a centre that can move from sample to sample
    const r = Math.exp(-Math.PI * width / RATE);
    let y1 = 0, y2 = 0;
    return (x, freq) => { const y = (1 - r) * x + 2 * r * Math.cos(2 * Math.PI * freq / RATE) * y1 - r * r * y2; y2 = y1; y1 = y; return y; };
  };
  const babble = lasts => {
    const seconds = lasts / 1000, syllables = [];
    const height = Math.random(), voice = 95 * 2.3 ** height, throat = 0.92 + 0.26 * height + between(-0.04, 0.04);
    const pace = between(0.85, 1.2), lilt = between(0.7, 1.5), breath = between(0.03, 0.08), wander = between(0, 6);
    for (let t = 0.05; t < seconds - 0.2; t += pace * between(0.2, 0.38)) {      // a breath between phrases
      const first = syllables.length, count = Math.round(between(2, 6));
      for (let k = 0; k < count; k++) {
        const stressed = Math.random() < 0.35, length = pace * between(0.11, 0.24) * (stressed ? 1.3 : 1);
        if (t + length > seconds - 0.05) break;
        const vowel = any(VOWELS);
        syllables.push({ start: t, length, stressed, vowel, glide: Math.random() < 0.4 ? any(VOWELS) : vowel, onset: any(ONSETS),
                         loud: between(0.55, 0.85) * (stressed ? 1.25 : 1), hiss: between(2800, 4200), place: 0, end: 1 });
        t += length + pace * between(0.015, 0.05) + (Math.random() < 0.1 ? between(0.08, 0.16) : 0);      // now and then a hesitation
      }
      const said = syllables.slice(first);
      said.forEach((syllable, k) => syllable.place = k / Math.max(1, said.length - 1));
      if (said.length) said[said.length - 1].end = Math.random() < 0.25 ? 1.14 : 0.86;
    }
    const out = new Float32Array(Math.round(RATE * seconds));
    const low = resonance(90 * throat), high = resonance(120 * throat), third = resonance(190 * throat), hiss = resonance(1400);
    let f1 = 500 * throat, f2 = 1400 * throat, pitch = voice, tune = voice, level = 0, phase = 0, cycle = 1, shimmer = 1, tilt = 0, soft = 0, n = 0, peak = 0;
    for (let i = 0; i < out.length; i++) {
      const time = i / RATE;
      while (n < syllables.length && time >= syllables[n].start + syllables[n].length) n++;
      const now = n < syllables.length && time >= syllables[n].start ? syllables[n] : null;
      let target = 0, noise = 0;
      if (now) {
        const early = time - now.start, x = early / now.length;
        let v1 = now.vowel[0] + (now.glide[0] - now.vowel[0]) * x, v2 = now.vowel[1] + (now.glide[1] - now.vowel[1]) * x;
        target = now.loud * (1 - 0.2 * now.place) * Math.sin(Math.PI * x ** 0.8) ** 0.6;
        if (now.onset === "stop") { if (early < 0.03) target = 0; else if (early < 0.042) noise = 4 * now.loud; }
        if (now.onset === "hiss" && early < 0.06) noise = 9 * now.loud * Math.sin(Math.PI * early / 0.06);
        if (now.onset === "hum" && early < 0.055) { target *= 0.45; v1 = 260; v2 = 1100; }
        f1 += (v1 * throat - f1) * 0.0015; f2 += (v2 * throat - f2) * 0.0015;        // slide towards this syllable's vowel
        tune = voice * (1.07 - 0.14 * now.place) * (1 + (now.stressed ? 0.09 * lilt * Math.sin(Math.PI * x) : 0)) * (1 + (now.end - 1) * x * x);
      }
      level += (target - level) * (target > level ? 0.006 : 0.0015);               // the voice dips between syllables, it does not stop
      pitch += (tune - pitch) * 0.002;
      phase += pitch * (1 + 0.025 * lilt * Math.sin(2 * Math.PI * 0.9 * time + wander)) * cycle / RATE;
      if (phase >= 1) { phase -= 1; cycle = 1 + between(-0.012, 0.012); shimmer = 1 + between(-0.07, 0.07); }      // no two cycles alike
      tilt += 0.3 * (2 * phase - 1 - tilt);                                        // softer than a bare sawtooth
      const buzz = level * (tilt * shimmer + breath * between(-1, 1));             // the voice, with a little breath
      const sample = 6 * low(buzz, f1) + 3.5 * high(buzz, f2) + 1.4 * third(buzz, 2650 * throat) + hiss(noise * between(-1, 1), now ? now.hiss : 3500);
      soft += 0.35 * (sample - soft);                                              // heard from a little away
      out[i] = soft; peak = Math.max(peak, Math.abs(soft));
    }
    // As a WAV file in memory, so that it plays the way the other sounds do.
    const wav = new DataView(new ArrayBuffer(44 + 2 * out.length));
    [..."RIFF"].forEach((c, k) => wav.setUint8(k, c.charCodeAt(0))); wav.setUint32(4, 36 + 2 * out.length, true);
    [..."WAVEfmt "].forEach((c, k) => wav.setUint8(8 + k, c.charCodeAt(0))); wav.setUint32(16, 16, true);
    wav.setUint16(20, 1, true); wav.setUint16(22, 1, true); wav.setUint32(24, RATE, true); wav.setUint32(28, 2 * RATE, true);
    wav.setUint16(32, 2, true); wav.setUint16(34, 16, true);
    [..."data"].forEach((c, k) => wav.setUint8(36 + k, c.charCodeAt(0))); wav.setUint32(40, 2 * out.length, true);
    out.forEach((sample, i) => wav.setInt16(44 + 2 * i, sample / (peak || 1) * 0.42 * 32767, true));
    const slices = Math.round(lasts / 106), size = Math.floor(out.length / slices), loudness = [];
    for (let k = 0; k < slices; k++) loudness.push(Math.sqrt(out.subarray(k * size, (k + 1) * size).reduce((sum, sample) => sum + sample * sample, 0) / size));
    const top = Math.max(...loudness) || 1;
    return { url: URL.createObjectURL(new Blob([wav], { type: "audio/wav" })), loudness: loudness.map(level => level / top) };
  };
  // The recorder's button: how far in it is, so long after a press. press.wav goes down at once
  // and comes up again after 110 ms.
  const pressed = age => age > 300 ? 0 : age < 50 ? age / 50 : age < 120 ? 1 : 1 - (age - 120) / 180;

  // A word's mark. With `at`, each part of it carries the moment at which it sounds.
  const mark = (word, at = null, style = "") =>
    `<span class="mark ${word.mark[0]}${word.failed ? " failed" : ""}"${style && ` style="${style}"`}>` +
    [...word.mark[1]].map((part, n) => `<${part}${at === null || !word.notes ? "" : ` data-at="${at + word.notes[n]}"`}></${part}>`).join("") + "</span>";

  const row = name => {
    const word = WORDS[name];
    return `<div class="sound${word.failed || word.silent ? " failed" : ""}${word.yours ? " yours" : ""}" data-word="${name}">${mark(word)}<div><b>${word.label}</b><span>${word.text}</span></div>` +
           (word.silent || word.yours ? "" : `<button data-sound="${name}">Play</button>`) + "</div>";
  };

  // One whole note, laid out in time with roughly the pauses it has in real life.
  //   answer   the sound that ends it (one of the answer_… words)
  //   talk     how long the speaker talks, in milliseconds
  //   work     how long the phone works on it, in milliseconds (ticks are half a second apart)
  //   heard    false: the audio did not reach the phone, so the wood block fails and nothing follows
  //   reach    false: the phone is not listening at all, so silence follows each press of the button
  //   online   false: the phone cannot reach Anthropic
  const compose = ({ answer = null, talk = TALK, work = 3000, heard = true, reach = true, online = true }) => {
    const stop = 1850 + talk + 400, steps = [[0, "press"]];
    steps.push([600, reach ? "question" : "silence"]);
    steps.push([1850, "talking"], [stop, "press"]);
    let asking = null;
    steps.push([stop + 450, !reach ? "silence" : heard ? "wood_1" : "wood_fail_1"]);
    if (reach && heard) {
      // The ticking stops, and the answer comes after a short silence.
      asking = [stop + 1350, stop + 1350 + work];
      steps.push([asking[0], "ticking"], [asking[1], null], [asking[1] + 700, answer]);
    }
    const [last, sound] = steps[steps.length - 1];
    const length = last + Math.max(1100, (WORDS[sound]?.lasts ?? 0) - 260);
    steps.push([length - 100, null]);
    const words = [...new Set(steps.map(step => step[1]).filter(name => WORDS[name]))];
    return { steps, length, talk, asking, words, recording: [100, stop + 100], presses: [0, stop],
             flag: !reach ? "deaf" : !heard ? "lost" : !online ? "offline" : "" };
  };

  // Puts an example into `element` and its words into `list`, and returns its controls.
  const mount = (element, list, scene) => {
    const { steps, length } = scene;
    element.querySelector(".player").replaceChildren(document.getElementById("player").content.cloneNode(true));
    ["deaf", "lost", "offline", "recording", "asking"].forEach(name => element.classList.toggle(name, name === scene.flag));
    list.innerHTML = scene.words.map(row).join("");
    const stage = element.querySelector(".stage"), timeline = element.querySelector(".timeline");
    const track = timeline.querySelector(".track"), button = timeline.querySelector("button");
    const percent = time => `${(100 * time / length).toFixed(2)}%`;
    // The row of the list that belongs to the sound now playing is lit, and it moves to the top
    // of the list, right under the player, so that it can be seen without scrolling down to it.
    // The rows it passes move down by one; when the note is over they all go back in order.
    const calm = matchMedia("(prefers-reduced-motion: reduce)").matches;
    const arrange = order => {
      const rows = [...list.children], was = new Map(rows.map(row => [row, row.getBoundingClientRect().top]));
      if (order.every((name, n) => rows[n].dataset.word === name)) return;
      order.forEach(name => list.appendChild(rows.find(row => row.dataset.word === name)));
      if (!calm) rows.forEach(row => {
        const moved = was.get(row) - row.getBoundingClientRect().top;
        if (moved) row.animate([{ transform: `translateY(${moved}px)` }, { transform: "none" }], { duration: 420, easing: "cubic-bezier(.2, .8, .2, 1)" });
      });
    };
    const light = sound => {
      const now = [...list.children].map(row => row.dataset.word);
      if (now.includes(sound)) arrange([sound, ...now.filter(name => name !== sound)]);
      list.querySelectorAll(".sound").forEach(row => row.classList.toggle("on", row.dataset.word === sound));
    };
    // The line: a mark for each word, the talking as a cloud of bars, the working as one dot per tick.
    const RINGS = [], BEATS = [], runs = [];
    let cloud = null;
    steps.forEach(([at, sound], n) => {
      const word = WORDS[sound];
      if (sound === "talking" || sound === "ticking") {
        const run = document.createElement("div"), lasts = sound === "talking" ? scene.talk : steps[n + 1][0] - at;
        run.className = sound === "talking" ? "talk" : "ticks";
        run.style.left = percent(at); run.style.width = percent(lasts);
        run.dataset.from = at; run.dataset.to = at + lasts;
        if (sound === "talking") cloud = run;
        else for (let tick = at; tick < at + lasts; tick += 500) {
          run.appendChild(document.createElement("i"));
          RINGS.push([tick, 360, 8, .55]);
          if (scene.flag !== "offline") BEATS.push(tick);
        }
        track.appendChild(run); runs.push(run);
      } else if (word?.notes) {
        track.insertAdjacentHTML("beforeend", mark(word, at, `left:${percent(at)}`));
        word.rings.forEach(([after, ...ring]) => RINGS.push([at + after, ...ring, word.failed]));
      }
    });
    const spread = (run, time) => [...run.children].forEach((part, n, all) =>
      part.classList.toggle("on", time > 0 && time >= +run.dataset.from + (run.dataset.to - run.dataset.from) * n / all.length));

    // The drawing. The rings leave the phone, which is 64 by 128 around (551, 76).
    const rings = RINGS.map(ring => {
      const rect = stage.querySelector(".rings").appendChild(document.createElementNS("http://www.w3.org/2000/svg", "rect"));
      if (ring[4]) rect.classList.add("failed");
      return rect;
    });
    const ripple = time => RINGS.forEach(([at, lasts, far, strength], n) => {
      const age = time === null ? -1 : (time - at) / lasts, ring = rings[n];
      if (age < 0 || age >= 1) return ring.setAttribute("opacity", 0);
      const out = 3 + far * (1 - (1 - age) ** 2);        // fast at first, then slowing
      ring.setAttribute("x", 519 - out); ring.setAttribute("y", 12 - out);
      ring.setAttribute("width", 64 + 2 * out); ring.setAttribute("height", 128 + 2 * out); ring.setAttribute("rx", 14.7 + out);
      ring.setAttribute("stroke-width", 2.6 - 1.4 * age); ring.setAttribute("opacity", strength * (1 - age));
    });
    // Anthropic's mark beats once with every tick: it jumps a little larger and settles back.
    const anthropic = stage.querySelector(".anthropic .beat");
    const beat = time => {
      const age = time === null ? 1 : Math.min(1, ...BEATS.map(at => time >= at ? (time - at) / 420 : 1));
      anthropic.setAttribute("transform", `translate(28 28) scale(${1 + .14 * (1 - age) ** 2}) translate(-28 -28)`);
    };
    // With each press the recorder dips and its button goes in.
    const casing = stage.querySelector(".press"), knob = stage.querySelector(".knob");
    const press = time => {
      const depth = pressed(time === null ? Infinity : Math.min(...scene.presses.map(at => time >= at ? time - at : Infinity)));
      casing.setAttribute("transform", `scale(${1 - .045 * depth})`);
      knob.setAttribute("transform", `translate(33 -67) scale(${1 - .3 * depth}) translate(-33 67)`);
    };
    const within = (span, time) => span !== null && time !== null && time >= span[0] && time < span[1];
    const show = time => {
      const now = running || time > 0 ? time : null;
      element.classList.toggle("recording", within(scene.recording, now));
      element.classList.toggle("asking", within(scene.asking, now));
      ripple(now); beat(now); press(now);
      track.style.setProperty("--done", `${Math.min(100, 100 * time / length)}%`);
      track.querySelectorAll("[data-at]").forEach(part => part.classList.toggle("on", time > 0 && time >= +part.dataset.at));
      runs.forEach(run => spread(run, time));
    };

    // The line's own copy of each sound, loaded at once, so that none starts late. The talking
    // is new for every play: its sound, and with it the bars on the line.
    const voices = steps.map(([, sound]) => { if (!sound || sound === "talking" || WORDS[sound]?.silent) return null; const audio = new Audio(`assets/sounds/${sound}.wav`); audio.preload = "auto"; audio.load(); return audio; });
    let spoken = null;
    const speak = () => {
      if (spoken) URL.revokeObjectURL(spoken.url);
      spoken = babble(scene.talk);
      voices[steps.findIndex(step => step[1] === "talking")] = new Audio(spoken.url);
      cloud.replaceChildren(...spoken.loudness.map(level => { const bar = document.createElement("i"); bar.style.height = `${3 + level * 38}px`; return bar; }));
    };
    // Where the note is: how far in, which steps have sounded, and what is audible right now.
    let elapsed = 0, since = 0, next = 0, frame = 0, running = false, sounding = [], held = null, presses = 0;
    const label = () => { button.textContent = running ? "❚❚" : "▶"; button.setAttribute("aria-label", running ? "Pause" : "Play the whole note"); };
    const reset = (again = true) => {
      elapsed = 0; next = 0; sounding = []; held = null;
      voices.forEach(audio => { if (audio) { audio.pause(); audio.currentTime = 0; } });
      if (again) speak();
      show(0); light(null); arrange(scene.words); timeline.classList.remove("playing");
    };
    const sound = () => {
      const audio = voices[next], name = steps[next++][1];
      light(name);
      // The ticking stops as soon as the next sound comes, as it does on the phone.
      if (held) { held.pause(); sounding = sounding.filter(other => other !== held); held = null; }
      if (!audio) return Promise.resolve();
      if (name === "ticking") held = audio;
      sounding.push(audio);
      return audio.play();
    };
    const tick = () => {
      const time = elapsed + performance.now() - since;
      while (next < steps.length && steps[next][0] <= time) sound().catch(() => {});
      show(time);
      if (time < length) frame = requestAnimationFrame(tick);
      else { running = false; reset(); label(); }
    };
    const pause = () => {                          // hold everything where it is
      if (!running) return;
      presses++;
      elapsed += performance.now() - since;
      cancelAnimationFrame(frame);
      sounding = sounding.filter(audio => !audio.ended);
      sounding.forEach(audio => audio.pause());
      running = false; label();
    };
    const start = () => {                          // play, or carry on from the pause
      const mine = ++presses, go = () => { if (mine !== presses) return; since = performance.now(); frame = requestAnimationFrame(tick); };
      since = performance.now();
      timeline.classList.add("playing");
      running = true; label();
      // The line starts moving when the first sound is heard, not when the button is pressed,
      // so that the marks and the notes stay together.
      // An iPhone only lets a sound start by itself if a touch has started it once, or if
      // another sound has just ended. The answer follows a silence, so it stayed mute there.
      // The touch that starts the note therefore starts every later sound as well and holds
      // it at once.
      if (next === 0) voices.forEach((audio, n) => { if (audio && n > 0) { audio.play().catch(() => {}); audio.pause(); } });
      if (next === 0) sound().then(go, go);
      else { sounding.forEach(audio => audio.play()); go(); }
    };
    button.addEventListener("click", () => running ? pause() : start());
    label(); speak(); show(0);

    return {
      pause,
      // Ends the example for good: it is not played again after this.
      close() { pause(); reset(false); URL.revokeObjectURL(spoken.url); },
      // The example as it stands at a moment, without sound (for checking the layout).
      peek(time) { timeline.classList.add("playing"); show(time); light([...steps].reverse().find(step => step[0] <= time)?.[1] ?? null); },
    };
  };

  document.addEventListener("click", event => {
    const button = event.target.closest("button[data-sound]");
    if (button) play(button.dataset.sound);
  });

  return { WORDS, compose, mount, mark };
})();
