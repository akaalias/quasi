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
  // it is drawn in ink, because orange only ever means that the app did something.
  const WORDS = {
    question: { label: `"I'm listening"`, text: "You pressed record, and the recorder is streaming live audio to your locked phone.",
                mark: ["chime", "ii"], notes: [0, 220], lasts: 1620, rings: [[0, 800, 18, .8], [220, 900, 22, .8]] },
    wood_1: { label: `"I've heard you"`, text: "You stopped recording, and your locked phone has received the whole voice note.",
              mark: ["wood", "i"], notes: [0], lasts: 900, rings: [[0, 420, 13, .9]] },
    wood_fail_1: { label: `"I didn't get that"`, text: "You stopped recording, but the audio did not reach your phone. The wood block is lower and rings longer, and nothing follows it.",
                   mark: ["wood fail", "i"], notes: [0], lasts: 1900, rings: [[0, 1100, 16, .9]], failed: true },
    ticking: { label: `"I'm working on it"`, text: "A quiet tick-tock plays while your phone works out which tasks you asked for.", mark: ["tock", "iii"] },
    answer_tasks_1: tasks(1, "one task", "Your phone has added the task to your to-do list. It plays one quick note for the task and then a chord."),
    answer_tasks_2: tasks(2, "two tasks", "Your phone has added both tasks to your to-do list. It plays one quick note for each task and then a chord, so you can count the tasks."),
    answer_tasks_3: tasks(3, "three tasks", "Your phone has added all three tasks to your to-do list. It plays one quick note for each task and then a chord, so you can count the tasks."),
    answer_nothing: { label: `"There is nothing to do"`, text: "You did not ask for anything, so your phone keeps what you said as a note. It plays the home note alone, without a chord.",
                      mark: ["chime answer", "b"], notes: [0], lasts: 1400, rings: [[0, 1300, 26, .85]] },
    answer_failed: { label: `"I couldn't do it"`, text: "Your phone could not work out the tasks or could not add them. The answer falls and rings out. Your note is safe.",
                     mark: ["chime fall", "ii"], notes: [0, 355], lasts: 2750, rings: [[0, 800, 18, .8], [355, 1800, 26, .8]], failed: true },
    silence: { label: "Silence", text: "No sound follows the press of the button. That is how you know that your phone is not listening.",
               mark: ["silence", "i"], silent: true },
  };

  // The loudness of talking.wav, slice by slice, for the little cloud of sound on the line.
  const TALK = 3600;
  const LOUDNESS = [0.45, 1.0, 0.26, 0.74, 0.27, 0.97, 0.52, 0.25, 0.1, 0.98, 0.67, 0.0, 0.0, 0.0, 0.52, 0.45, 0.14, 0.14, 0.35, 0.25, 0.56, 0.02, 0.0, 0.0, 0.77, 0.72, 0.18, 0.28, 0.15, 0.73, 0.19, 0.27, 0.0, 0.0];
  // The recorder's button: how far in it is, so long after a press. press.wav goes down at once
  // and comes up again after 110 ms.
  const pressed = age => age > 300 ? 0 : age < 50 ? age / 50 : age < 120 ? 1 : 1 - (age - 120) / 180;

  // A word's mark. With `at`, each part of it carries the moment at which it sounds.
  const mark = (word, at = null, style = "") =>
    `<span class="mark ${word.mark[0]}${word.failed ? " failed" : ""}"${style && ` style="${style}"`}>` +
    [...word.mark[1]].map((part, n) => `<${part}${at === null || !word.notes ? "" : ` data-at="${at + word.notes[n]}"`}></${part}>`).join("") + "</span>";

  const row = name => {
    const word = WORDS[name];
    return `<div class="sound${word.failed ? " failed" : ""}" data-word="${name}">${mark(word)}<div><b>${word.label}</b><span>${word.text}</span></div>` +
           (word.silent ? "" : `<button data-sound="${name}">Play</button>`) + "</div>";
  };

  // One whole note, laid out in time with roughly the pauses it has in real life.
  //   answer   the sound that ends it (one of the answer_… words)
  //   work     how long the phone works on it, in milliseconds (ticks are half a second apart)
  //   heard    false: the audio did not reach the phone, so the wood block fails and nothing follows
  //   reach    false: the phone is not listening at all, so it makes no sound
  //   online   false: the phone cannot reach Anthropic
  const compose = ({ answer = null, work = 3000, heard = true, reach = true, online = true }) => {
    const steps = [[0, "press"]];
    if (reach) steps.push([600, "question"]);
    steps.push([1850, "talking"], [5850, "press"]);
    let asking = null;
    if (reach) steps.push([6300, heard ? "wood_1" : "wood_fail_1"]);
    if (reach && heard) {
      // The ticking stops, and the answer comes after a short silence.
      steps.push([7200, "ticking"], [7200 + work, null], [7200 + work + 700, answer]);
      asking = [7200, 7200 + work];
    }
    const [last, sound] = steps[steps.length - 1];
    const length = last + Math.max(1100, (WORDS[sound]?.lasts ?? 0) - 260);
    steps.push([length - 100, null]);
    const words = reach ? steps.map(step => step[1]).filter(name => WORDS[name]) : ["silence"];
    return { steps, length, asking, words, recording: [100, 5950], presses: [0, 5850],
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
    // The row of the list that belongs to the sound now playing is lit.
    const light = sound => list.querySelectorAll(".sound").forEach(row => row.classList.toggle("on", row.dataset.word === sound));

    // The line: a mark for each word, the talking as a cloud of bars, the working as one dot per tick.
    const RINGS = [], BEATS = [], runs = [];
    steps.forEach(([at, sound], n) => {
      const word = WORDS[sound];
      if (sound === "talking" || sound === "ticking") {
        const run = document.createElement("div"), lasts = sound === "talking" ? TALK : steps[n + 1][0] - at;
        run.className = sound === "talking" ? "talk" : "ticks";
        run.style.left = percent(at); run.style.width = percent(lasts);
        run.dataset.from = at; run.dataset.to = at + lasts;
        if (sound === "talking") LOUDNESS.forEach(level => { run.appendChild(document.createElement("i")).style.height = `${3 + level * 38}px`; });
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

    // The line's own copy of each sound, loaded at once, so that none starts late.
    const voices = steps.map(([, sound]) => { if (!sound) return null; const audio = new Audio(`assets/sounds/${sound}.wav`); audio.preload = "auto"; audio.load(); return audio; });
    // Where the note is: how far in, which steps have sounded, and what is audible right now.
    let elapsed = 0, since = 0, next = 0, frame = 0, running = false, sounding = [], ticking = null, presses = 0;
    const label = () => { button.textContent = running ? "❚❚" : "▶"; button.setAttribute("aria-label", running ? "Pause" : "Play the whole note"); };
    const reset = () => {
      elapsed = 0; next = 0; sounding = []; ticking = null;
      voices.forEach(audio => { if (audio) { audio.pause(); audio.currentTime = 0; } });
      show(0); light(null); timeline.classList.remove("playing");
    };
    const sound = () => {
      const audio = voices[next], name = steps[next++][1];
      light(name);
      // The ticking stops as soon as the next sound comes, as it does on the phone.
      if (ticking) { ticking.pause(); sounding = sounding.filter(other => other !== ticking); ticking = null; }
      if (!audio) return Promise.resolve();
      if (name === "ticking") ticking = audio;
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
      if (next === 0) sound().then(go, go);
      else { sounding.forEach(audio => audio.play()); go(); }
    };
    button.addEventListener("click", () => running ? pause() : start());
    label(); show(0);

    return {
      pause,
      stop() { pause(); reset(); },
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
