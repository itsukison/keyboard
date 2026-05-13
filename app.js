const examples = [
  {
    label: "Mixed Japanese with English noun",
    text: "kyou no meeting wa 3ji ni",
    note: "meeting stays English because Japanese intent would be mi-tinngu",
  },
  {
    label: "Pure romaji Japanese",
    text: "watashi wa Tokyo ni sunde iru",
    note: "Tokyo should be Japanese intent despite capitalization",
  },
  {
    label: "English short-token trap",
    text: "no problem, to be honest",
    note: "no and to should not become Japanese particles",
  },
  {
    label: "Katakana loanword intent",
    text: "ashita no mi-tinngu wa daijoubu",
    note: "mi-tinngu previews as ミーティング",
  },
  {
    label: "Japanese names",
    text: "Tanaka san to Suzuki san ni atta",
    note: "common Japanese names should prefer Japanese",
  },
  {
    label: "Code switch after phrase",
    text: "sugoi ne, that's amazing",
    note: "Japanese tag, English clause",
  },
  {
    label: "Ambiguous particles only",
    text: "ka no to wa de ni",
    note: "little context means the model should stay cautious",
  },
  {
    label: "Long Japanese string",
    text: "osewaninarimasu yoroshikuonegaishimasu",
    note: "long kana-valid romaji is strong Japanese intent",
  },
  {
    label: "English proper nouns",
    text: "John and Mary are going to Tokyo",
    note: "John and Mary stay English; Tokyo is a Japanese place override",
  },
  {
    label: "Time expression",
    text: "raishuu no getsuyoubi 10ji ni call shiyou",
    note: "10ji acts Japanese in a Japanese run; call stays English",
  },
  {
    label: "English consonant clusters",
    text: "strong light switched quickly",
    note: "clusters and dictionary hits should pull English",
  },
  {
    label: "Verb endings",
    text: "kinou tabetemita kedo mada wakaranai",
    note: "Japanese endings and kana validity reinforce the run",
  },
  {
    label: "Kanji candidate ambiguity",
    text: "hashi wo wataru mae ni taberu",
    note: "hashi needs a candidate choice: bridge, chopsticks, or edge",
  },
  {
    label: "No-space Japanese chunk",
    text: "hashiwowatarumaenitaberu",
    note: "Japanese users do not space words; segment after kana conversion",
  },
  {
    label: "No-space mixed Japanese phrase",
    text: "kyounomeetingha3jini",
    note: "Split one no-space run into Japanese, English, then Japanese again",
  },
  {
    label: "Bilingual clause",
    text: "korekara we can get in the car",
    note: "Japanese opening phrase, then English sentence",
  },
];

const englishWords = new Set(
  [
    "a",
    "about",
    "am",
    "amazing",
    "an",
    "and",
    "are",
    "as",
    "at",
    "be",
    "call",
    "called",
    "can",
    "car",
    "computer",
    "day",
    "do",
    "does",
    "english",
    "for",
    "from",
    "get",
    "going",
    "good",
    "hello",
    "honest",
    "i",
    "in",
    "is",
    "it",
    "its",
    "japanese",
    "john",
    "light",
    "mary",
    "meeting",
    "my",
    "no",
    "not",
    "of",
    "on",
    "problem",
    "quickly",
    "smart",
    "strong",
    "switched",
    "that",
    "the",
    "this",
    "to",
    "was",
    "we",
    "with",
    "you",
    // colloquial contractions (apostrophe-less forms commonly typed in chat)
    "wanna", "gonna", "gotta", "kinda", "sorta", "lemme", "gimme", "dunno",
    "imma", "tryna", "finna", "shoulda", "woulda", "coulda", "hafta",
    "oughta", "betcha", "gotcha", "whatcha", "yall", "aint", "nah", "mhm",
    "hmm", "huh", "omg", "lol", "lmao", "btw", "fyi", "idk", "tbh", "ngl",
    "imo", "imho", "asap", "etc", "brb", "ok", "okay", "yeah", "yep", "nope",
    "hi", "hey", "thanks", "thank", "please", "sorry", "wow", "oh",
  ].sort()
);
const embeddedEnglishWords = [...englishWords]
  .filter((word) => word.length >= 4)
  .sort((left, right) => right.length - left.length || left.localeCompare(right));

const knownJapanese = new Map([
  ["tokyo", "東京"],
  ["toukyou", "東京"],
  ["osaka", "大阪"],
  ["oosaka", "大阪"],
  ["kyoto", "京都"],
  ["tanaka", "田中"],
  ["suzuki", "鈴木"],
  ["sato", "佐藤"],
  ["satou", "佐藤"],
  ["yamada", "山田"],
  ["nihon", "日本"],
  ["nippon", "日本"],
]);

const kanjiDictionary = new Map([
  ["3じ", ["3時", "3じ"]],
  ["10じ", ["10時", "10じ"]],
  ["あした", ["明日", "あした"]],
  ["あった", ["会った", "あった"]],
  ["いく", ["行く", "いく"]],
  ["いる", ["いる", "居る"]],
  ["おせわになります", ["お世話になります", "おせわになります"]],
  ["おねがいします", ["お願いします", "おねがいします"]],
  ["かえる", ["帰る", "変える", "替える", "買える", "かえる"]],
  ["かく", ["書く", "描く", "欠く", "かく"]],
  ["かんじ", ["漢字", "感じ", "幹事", "かんじ"]],
  ["きのう", ["昨日", "きのう"]],
  ["きょう", ["今日", "きょう"]],
  ["くる", ["来る", "くる"]],
  ["けど", ["けど"]],
  ["げつようび", ["月曜日", "げつようび"]],
  ["これから", ["これから", "此れから"]],
  ["さん", ["さん"]],
  ["しよう", ["しよう", "使用", "仕様"]],
  ["すごい", ["すごい", "凄い"]],
  ["すんで", ["住んで", "済んで", "澄んで", "すんで"]],
  ["だいじょうぶ", ["大丈夫", "だいじょうぶ"]],
  ["たべてみた", ["食べてみた", "たべてみた"]],
  ["たべる", ["食べる", "たべる"]],
  ["つかう", ["使う", "つかう"]],
  ["ともだち", ["友達", "ともだち"]],
  ["とうきょう", ["東京", "とうきょう"]],
  ["なに", ["何", "なに"]],
  ["にほん", ["日本", "にほん"]],
  ["のむ", ["飲む", "のむ"]],
  ["はし", ["橋", "箸", "端", "はし"]],
  ["はしる", ["走る", "はしる"]],
  ["はな", ["花", "鼻", "はな"]],
  ["ひと", ["人", "ひと"]],
  ["まえ", ["前", "まえ"]],
  ["まだ", ["まだ", "未だ"]],
  ["みる", ["見る", "観る", "みる"]],
  ["もつ", ["持つ", "もつ"]],
  ["やすみ", ["休み", "やすみ"]],
  ["よろしくおねがいします", ["よろしくお願いします", "よろしくおねがいします"]],
  ["らいしゅう", ["来週", "らいしゅう"]],
  ["わかる", ["分かる", "わかる"]],
  ["わからない", ["分からない", "わからない"]],
  ["わたし", ["私", "わたし"]],
  ["わたる", ["渡る", "わたる"]],
]);

const particleConversions = new Map([
  ["wa", ["は", "わ"]],
  ["e", ["へ", "え"]],
  ["wo", ["を"]],
  ["o", ["を", "お"]],
  ["no", ["の"]],
  ["to", ["と"]],
  ["ni", ["に"]],
  ["de", ["で"]],
  ["ga", ["が"]],
  ["mo", ["も"]],
  ["ka", ["か"]],
  ["yo", ["よ"]],
  ["ne", ["ね"]],
]);

const kanaParticleConversions = new Map([
  ["は", ["は"]],
  ["へ", ["へ"]],
  ["を", ["を"]],
  ["の", ["の"]],
  ["と", ["と"]],
  ["に", ["に"]],
  ["で", ["で"]],
  ["が", ["が"]],
  ["も", ["も"]],
  ["か", ["か"]],
  ["よ", ["よ"]],
  ["ね", ["ね"]],
]);

const loanwordHints = new Set([
  "apuri",
  "depaato",
  "koohii",
  "konpyuuta",
  "meeru",
  "mi-tinngu",
  "mi-tingu",
  "miitingu",
  "pasokon",
  "sumaato",
  "terebi",
]);

const particles = new Set(["wa", "ga", "wo", "o", "ni", "de", "mo", "ka", "yo", "ne", "no", "to", "e"]);
const weakShort = new Set(["be", "e", "he", "i", "ka", "me", "mo", "ne", "ni", "no", "o", "to", "wa", "we", "wo", "yo"]);
const standaloneKanaWeakEnglish = new Set(["be", "he", "me", "we"]);
const jaBigrams = ["shi", "tsu", "chi", "kya", "kyu", "kyo", "ryu", "ryo", "myo", "nyu", "gyu", "pyo", "ja", "ju", "jo"];
const impossibleJapaneseClusters = ["str", "spl", "spr", "ght", "ths", "rld", "sked", "ngth"];
const strongVerbEndings = ["mashita", "masu", "desu", "nai", "nakatta", "teiru", "teru", "shita", "suru"];

const hiraBase = {
  a: "あ",
  i: "い",
  u: "う",
  e: "え",
  o: "お",
  ka: "か",
  ki: "き",
  ku: "く",
  ke: "け",
  ko: "こ",
  sa: "さ",
  si: "し",
  shi: "し",
  su: "す",
  se: "せ",
  so: "そ",
  ta: "た",
  ti: "ち",
  chi: "ち",
  tu: "つ",
  tsu: "つ",
  te: "て",
  to: "と",
  na: "な",
  ni: "に",
  nu: "ぬ",
  ne: "ね",
  no: "の",
  ha: "は",
  hi: "ひ",
  hu: "ふ",
  fu: "ふ",
  he: "へ",
  ho: "ほ",
  ma: "ま",
  mi: "み",
  mu: "む",
  me: "め",
  mo: "も",
  ya: "や",
  yu: "ゆ",
  yo: "よ",
  ra: "ら",
  ri: "り",
  ru: "る",
  re: "れ",
  ro: "ろ",
  wa: "わ",
  wi: "うぃ",
  we: "うぇ",
  wo: "を",
  n: "ん",
  nn: "ん",
  ga: "が",
  gi: "ぎ",
  gu: "ぐ",
  ge: "げ",
  go: "ご",
  za: "ざ",
  zi: "じ",
  ji: "じ",
  zu: "ず",
  ze: "ぜ",
  zo: "ぞ",
  da: "だ",
  di: "ぢ",
  du: "づ",
  de: "で",
  do: "ど",
  ba: "ば",
  bi: "び",
  bu: "ぶ",
  be: "べ",
  bo: "ぼ",
  pa: "ぱ",
  pi: "ぴ",
  pu: "ぷ",
  pe: "ぺ",
  po: "ぽ",
  kya: "きゃ",
  kyu: "きゅ",
  kyo: "きょ",
  sha: "しゃ",
  shu: "しゅ",
  sho: "しょ",
  sya: "しゃ",
  syu: "しゅ",
  syo: "しょ",
  cha: "ちゃ",
  chu: "ちゅ",
  cho: "ちょ",
  tya: "ちゃ",
  tyu: "ちゅ",
  tyo: "ちょ",
  nya: "にゃ",
  nyu: "にゅ",
  nyo: "にょ",
  hya: "ひゃ",
  hyu: "ひゅ",
  hyo: "ひょ",
  mya: "みゃ",
  myu: "みゅ",
  myo: "みょ",
  rya: "りゃ",
  ryu: "りゅ",
  ryo: "りょ",
  gya: "ぎゃ",
  gyu: "ぎゅ",
  gyo: "ぎょ",
  ja: "じゃ",
  ju: "じゅ",
  jo: "じょ",
  jya: "じゃ",
  jyu: "じゅ",
  jyo: "じょ",
  bya: "びゃ",
  byu: "びゅ",
  byo: "びょ",
  pya: "ぴゃ",
  pyu: "ぴゅ",
  pyo: "ぴょ",
  fa: "ふぁ",
  fi: "ふぃ",
  fe: "ふぇ",
  fo: "ふぉ",
  va: "ゔぁ",
  vi: "ゔぃ",
  vu: "ゔ",
  ve: "ゔぇ",
  vo: "ゔぉ",
  she: "しぇ",
  je: "じぇ",
  che: "ちぇ",
  // --- Small characters via x- / l- prefix (Mozc / AzooKey convention) ---
  xa: "ぁ", xi: "ぃ", xu: "ぅ", xe: "ぇ", xo: "ぉ",
  la: "ぁ", li: "ぃ", lu: "ぅ", le: "ぇ", lo: "ぉ",
  xya: "ゃ", xyu: "ゅ", xyo: "ょ",
  lya: "ゃ", lyu: "ゅ", lyo: "ょ",
  xtu: "っ", xtsu: "っ", ltu: "っ", ltsu: "っ",
  xwa: "ゎ", lwa: "ゎ",
  xka: "ヵ", xke: "ヶ", lka: "ヵ", lke: "ヶ",
  xn: "ん",
  // --- v row extensions ---
  vya: "ゔゃ", vyu: "ゔゅ", vyo: "ゔょ",
  // --- ts / th / dh / tw / dw foreign-sound extensions ---
  tsa: "つぁ", tsi: "つぃ", tse: "つぇ", tso: "つぉ",
  tha: "てゃ", thi: "てぃ", thu: "てゅ", the: "てぇ", tho: "てょ",
  dha: "でゃ", dhi: "でぃ", dhu: "でゅ", dhe: "でぇ", dho: "でょ",
  twa: "とぁ", twi: "とぃ", twu: "とぅ", twe: "とぇ", two: "とぉ",
  dwa: "どぁ", dwi: "どぃ", dwu: "どぅ", dwe: "どぇ", dwo: "どぉ",
  sye: "しぇ", zye: "じぇ", jye: "じぇ", cye: "ちぇ",
  // --- f extensions ---
  fya: "ふゃ", fyu: "ふゅ", fyo: "ふょ",
  fwa: "ふぁ", fwi: "ふぃ", fwu: "ふぅ", fwe: "ふぇ", fwo: "ふぉ",
  // --- w extensions ---
  wha: "うぁ", whi: "うぃ", whu: "う", whe: "うぇ", who: "うぉ",
  wyi: "ゐ", wye: "ゑ",
  // --- k / g / q extensions ---
  kwa: "くぁ", kwi: "くぃ", kwu: "くぅ", kwe: "くぇ", kwo: "くぉ",
  gwa: "ぐぁ", gwi: "ぐぃ", gwu: "ぐぅ", gwe: "ぐぇ", gwo: "ぐぉ",
  kye: "きぇ", gye: "ぎぇ",
  qa: "くぁ", qi: "くぃ", qu: "く", qe: "くぇ", qo: "くぉ",
  qwa: "くぁ", qwi: "くぃ", qwu: "くぅ", qwe: "くぇ", qwo: "くぉ",
  // --- other -e yoon ---
  nye: "にぇ", hye: "ひぇ", bye: "びぇ", pye: "ぴぇ",
  mye: "みぇ", rye: "りぇ",
};

const kataOverrides = {
  ti: "ティ",
  di: "ディ",
  tu: "トゥ",
  du: "ドゥ",
  si: "シ",
  zi: "ジ",
  wi: "ウィ",
  we: "ウェ",
  she: "シェ",
  che: "チェ",
  je: "ジェ",
  fa: "ファ",
  fi: "フィ",
  fe: "フェ",
  fo: "フォ",
  va: "ヴァ",
  vi: "ヴィ",
  vu: "ヴ",
  ve: "ヴェ",
  vo: "ヴォ",
};

const vowels = new Set(["a", "i", "u", "e", "o"]);
const consonants = new Set("bcdfghjklmnpqrstvwxyz".split(""));

// Trigram language model. The data is generated by `swift run TrigramBuilder`
// and emitted as `trigrams-data.js` next to this file. The fields mirror
// `Sources/KeyboardCore/TrigramScorer.swift` so both runtimes give the same
// scores. If the data file is missing (e.g. local dev), the scorer falls
// back to zero-zero scores and the legacy heuristics take over.
const TrigramModel = (typeof window !== "undefined" && window.TRIGRAMS) || null;

function scoreTrigram(token) {
  if (!TrigramModel) return { ja: 0, en: 0, diff: 0 };
  const normalized = (token || "").toLowerCase().replace(/[^a-z0-9-]/g, "");
  if (normalized.length === 0) return { ja: 0, en: 0, diff: 0 };
  const padded = TrigramModel.startMark + normalized + TrigramModel.endMark;
  const ja = TrigramModel.ja;
  const en = TrigramModel.en;
  let jaSum = 0;
  let enSum = 0;
  for (let i = 0; i + 3 <= padded.length; i++) {
    const tri = padded.slice(i, i + 3);
    jaSum += ja.trigrams[tri] !== undefined ? ja.trigrams[tri] : ja.unseenLogProb;
    enSum += en.trigrams[tri] !== undefined ? en.trigrams[tri] : en.unseenLogProb;
  }
  return { ja: jaSum, en: enSum, diff: jaSum - enSum };
}

// Note: an earlier revision used a beam-search segmenter here, but it
// violated the structural rule that a single whitespace-delimited token
// represents one language. The beam happily split "type" into "ty"+"pe" →
// "tyぺ" whenever trigram costs slightly favored a mixed path. The current
// design uses the greedy dictionary-word split in `splitEmbeddedEnglish`
// and treats the trigram score as a per-piece classification feature only.

const input = document.querySelector("#romajiInput");
const rows = document.querySelector("#analysisRows");
const preview = document.querySelector("#outputPreview");
const summaryBadge = document.querySelector("#summaryBadge");
const sentenceSummary = document.querySelector("#sentenceSummary");
const exampleSelect = document.querySelector("#exampleSelect");
const corpusGrid = document.querySelector("#corpusGrid");
const candidateList = document.querySelector("#candidateList");
const candidatePopover = document.querySelector("#candidatePopover");
const selectedCandidates = new Map();
let activeSegmentKey = "";

function toKatakana(hiragana) {
  return [...hiragana]
    .map((char) => {
      const code = char.charCodeAt(0);
      if (code >= 0x3041 && code <= 0x3096) return String.fromCharCode(code + 0x60);
      return char;
    })
    .join("");
}

function normalizeWord(raw) {
  return raw.toLowerCase().replace(/[’]/g, "'").replace(/^[^a-z0-9']+|[^a-z0-9'-]+$/g, "");
}

function hasLetters(value) {
  return /[a-z]/i.test(value);
}

function isLoanwordIntent(clean) {
  return (
    loanwordHints.has(clean) ||
    clean.includes("-") ||
    /(fa|fi|fe|fo|she|che|je|ti|di|tu|du|wi|we|va|vi|vu|ve|vo)/.test(clean)
  );
}

function kanaForMora(mora, script) {
  if (script === "katakana" && kataOverrides[mora]) return kataOverrides[mora];
  const hira = hiraBase[mora];
  if (!hira) return null;
  return script === "katakana" ? toKatakana(hira) : hira;
}

function romanVowel(mora) {
  for (let i = mora.length - 1; i >= 0; i -= 1) {
    if (vowels.has(mora[i])) return mora[i];
  }
  return "";
}

function romajiToKana(raw, script = "hiragana") {
  const clean = normalizeWord(raw);
  if (!clean) return { kana: raw, complete: false, moraCount: 0, leftovers: raw };
  if (/^\d+ji$/.test(clean)) {
    return { kana: clean.replace("ji", "時"), complete: true, moraCount: 1, leftovers: "" };
  }

  let i = 0;
  let kana = "";
  let moraCount = 0;
  let leftovers = "";
  let previousVowel = "";

  while (i < clean.length) {
    const char = clean[i];
    const next = clean[i + 1] || "";

    if (char === "-") {
      kana += script === "katakana" ? "ー" : "ー";
      i += 1;
      previousVowel = "";
      continue;
    }

    if (char === "'") {
      i += 1;
      continue;
    }

    if (/\d/.test(char)) {
      kana += char;
      i += 1;
      continue;
    }

    if (char === "n" && next === "'") {
      kana += script === "katakana" ? "ン" : "ん";
      moraCount += 1;
      i += 2;
      previousVowel = "";
      continue;
    }

    if (char === "n" && next === "n") {
      kana += script === "katakana" ? "ン" : "ん";
      moraCount += 1;
      i += 2;
      previousVowel = "";
      continue;
    }

    if (char === "n" && next && !vowels.has(next) && next !== "y") {
      kana += script === "katakana" ? "ン" : "ん";
      moraCount += 1;
      i += 1;
      previousVowel = "";
      continue;
    }

    if (consonants.has(char) && char === next && char !== "n") {
      kana += script === "katakana" ? "ッ" : "っ";
      i += 1;
      previousVowel = "";
      continue;
    }

    let matched = false;
    for (const length of [4, 3, 2, 1]) {
      const mora = clean.slice(i, i + length);
      const kanaChunk = kanaForMora(mora, script);
      if (!kanaChunk) continue;

      const moraVowel = romanVowel(mora);
      if (script === "katakana" && length === 1 && moraVowel && moraVowel === previousVowel) {
        kana += "ー";
      } else {
        kana += kanaChunk;
      }
      moraCount += 1;
      previousVowel = moraVowel;
      i += length;
      matched = true;
      break;
    }

    if (!matched) {
      leftovers += char;
      kana += char;
      i += 1;
      previousVowel = "";
    }
  }

  return { kana, complete: leftovers.length === 0, moraCount, leftovers };
}

function splitInput(text) {
  const parts = text.match(/[A-Za-z0-9][A-Za-z0-9'’-]*|[^\sA-Za-z0-9]+|\s+/g) || [];
  return parts.flatMap((part, index) => {
    const clean = normalizeWord(part);
    if (!hasLetters(part) || /^\d+ji$/i.test(part)) {
      return {
        raw: part,
        index,
        clean,
        isWord: hasLetters(part) || /^\d+ji$/i.test(part),
        isSpace: /^\s+$/.test(part),
      };
    }

    const splitParts = splitEmbeddedEnglish(clean);
    return splitParts.map((splitPart, splitIndex) => ({
      raw: splitPart,
      index: Number(`${index}${splitIndex}`),
      clean: splitPart,
      isWord: true,
      isSpace: false,
    }));
  });
}

function splitEmbeddedEnglish(clean) {
  // Greedy left-to-right scan for known EN dictionary words (length >= 4).
  // Within a single whitespace token, language must be homogeneous unless
  // an explicit dictionary word is embedded — pure trigram-driven splits
  // would yield artefacts like "type" → "tyぺ".
  const spans = [];
  let cursor = 0;
  let japaneseBuffer = "";
  while (cursor < clean.length) {
    const match = embeddedEnglishWords.find((word) => clean.startsWith(word, cursor));
    if (match) {
      if (japaneseBuffer) {
        spans.push(japaneseBuffer);
        japaneseBuffer = "";
      }
      spans.push(match);
      cursor += match.length;
    } else {
      japaneseBuffer += clean[cursor];
      cursor += 1;
    }
  }
  if (japaneseBuffer) spans.push(japaneseBuffer);
  return spans.length > 0 ? spans : [clean];
}

function scoreToken(token, wordIndex) {
  const reasons = [];
  let ja = 0;
  let en = 0;
  const clean = token.clean;
  const script = isLoanwordIntent(clean) ? "katakana" : "hiragana";
  const kana = romajiToKana(clean, script);
  const englishHit = englishWords.has(clean.replace(/'/g, ""));
  const knownKanji = knownJapanese.get(clean);

  if (!token.isWord) {
    return { ...token, ja, en, reasons, kana, englishHit, knownKanji, script, classification: "punctuation", wordIndex };
  }

  if (/^\d+ji$/.test(clean)) {
    ja += 1.8;
    reasons.push("Japanese time suffix");
  }

  if (knownKanji) {
    ja += 4.2;
    reasons.push("known Japanese name/place");
  }

  if (kana.complete) {
    ja += clean.length <= 2 ? 0.4 : 1.1;
    reasons.push("fully decomposes to mora");
    if (kana.moraCount >= 3) {
      ja += 0.7;
      reasons.push("3+ mora token");
    }
    if (clean.length >= 8 && !englishHit) {
      ja += 1.7;
      reasons.push("long kana-valid non-English string");
    }
  } else {
    en += 1.2;
    reasons.push("not fully kana-decomposable");
  }

  // Character trigram feature. Skipped for ≤2 chars where a single unseen
  // trigram is too noisy to trust against the rules above. Mirrors
  // `BilingualSpanDetector.swift`.
  if (clean.length >= 3) {
    const tri = scoreTrigram(clean);
    const denom = Math.max(1, clean.length + 2);
    const perChar = tri.diff / denom;
    const weight = 0.9;
    const cap = 3.0;
    if (perChar > 0) {
      const v = Math.min(cap, perChar * weight);
      ja += v;
      reasons.push(`trigram favors JA (+${v.toFixed(2)})`);
    } else if (perChar < 0) {
      const v = Math.min(cap, -perChar * weight);
      en += v;
      reasons.push(`trigram favors EN (+${v.toFixed(2)})`);
    }
  }

  if (isLoanwordIntent(clean) && kana.complete) {
    ja += 2.1;
    reasons.push("katakana loanword spelling");
  }

  if (jaBigrams.some((pattern) => clean.includes(pattern)) && kana.complete) {
    ja += 0.8;
    reasons.push("Japanese-specific romaji pattern");
  }

  if (/([bcdfghjklmpqrstvwxyz])\1/.test(clean) && kana.complete && !/(ll|ee|oo)/.test(clean)) {
    ja += 0.5;
    reasons.push("possible sokuon consonant");
  }

  if (strongVerbEndings.some((ending) => clean.endsWith(ending)) && kana.complete && clean.length > 4) {
    ja += 0.9;
    reasons.push("Japanese verb/copula ending");
  }

  if (englishHit) {
    en += clean.length <= 2 ? 1.0 : 2.5;
    reasons.push("English dictionary hit");
  }

  if (/[']/g.test(clean)) {
    en += 1.6;
    reasons.push("English contraction/apostrophe");
  }

  if (/^[A-Z]/.test(token.raw) && !knownKanji && wordIndex !== 0) {
    en += 0.8;
    reasons.push("capitalized non-Japanese override");
  }

  if (impossibleJapaneseClusters.some((cluster) => clean.includes(cluster))) {
    en += 1.6;
    reasons.push("English consonant cluster");
  }

  if (/(ing|ed|ly)$/.test(clean) && englishHit) {
    en += 0.7;
    reasons.push("English suffix pattern");
  }

  if (weakShort.has(clean)) {
    reasons.push("short ambiguous token");
  }

  return { ...token, ja, en, reasons, kana, englishHit, knownKanji, script, classification: "unknown", wordIndex };
}

function classify(ja, en) {
  const margin = ja - en;
  if (margin >= 1.1 && ja >= 1.4) return "japanese";
  if (margin <= -1.1 && en >= 1.4) return "english";
  return "ambiguous";
}

function smoothScores(tokens) {
  const wordTokens = tokens.filter((token) => token.isWord);
  const isLikelyEnglish = (item) => item && item.en - item.ja >= 1.0;
  const isLikelyJapanese = (item) => item && item.ja - item.en >= 1.2;

  wordTokens.forEach((token, idx) => {
    const left = wordTokens.slice(Math.max(0, idx - 2), idx);
    const right = wordTokens.slice(idx + 1, idx + 3);
    const neighbors = [...left, ...right];
    const previous = wordTokens[idx - 1];
    const next = wordTokens[idx + 1];
    const jaNeighbors = neighbors.filter(isLikelyJapanese).length;
    const enNeighbors = neighbors.filter(isLikelyEnglish).length;
    const isAmbiguous = weakShort.has(token.clean) || Math.abs(token.ja - token.en) < 1.2;
    const englishSide = isLikelyEnglish(previous) || isLikelyEnglish(next) || enNeighbors >= 2;
    const isStandaloneKanaEnglish =
      token.englishHit &&
      standaloneKanaWeakEnglish.has(token.clean) &&
      !particles.has(token.clean) &&
      !token.knownKanji;

    if (isStandaloneKanaEnglish && englishSide) {
      token.en += 2.0;
      token.reasons.push("standalone kana would be odd beside English");
    }

    if (particles.has(token.clean) && isAmbiguous && previous && previous.ja - previous.en >= 1.2) {
      token.ja += 1.2;
      token.reasons.push("particle follows Japanese token");
    }

    if (particles.has(token.clean) && isAmbiguous && jaNeighbors > 0) {
      token.ja += 1.4;
      token.reasons.push("particle pulled by Japanese context");
    }

    if (isAmbiguous && jaNeighbors >= 2) {
      token.ja += 1.2;
      token.reasons.push("nearby Japanese run");
    }

    if (isAmbiguous && enNeighbors >= 2) {
      token.en += 1.2;
      token.reasons.push("nearby English run");
    }
  });

  for (let start = 0; start < wordTokens.length; start += 1) {
    let end = start;
    while (end < wordTokens.length && wordTokens[end].kana.complete && !wordTokens[end].englishHit) {
      end += 1;
    }
    if (end - start >= 3) {
      for (let i = start; i < end; i += 1) {
        wordTokens[i].ja += 0.9;
        wordTokens[i].reasons.push("3-token kana-valid Japanese run");
      }
    }
    start = Math.max(start, end);
  }

  tokens.forEach((token) => {
    if (token.isWord) token.classification = classify(token.ja, token.en);
  });

  return tokens;
}

function displayPreview(token) {
  return displayPreviewText(token);
}

function displayPreviewText(token) {
  if (!token.isWord) return token.raw;
  if (token.classification === "english") return token.raw;
  if (token.classification === "ambiguous") return token.raw;
  return getConversionSegments(token).map((segment) => selectedCandidates.get(segment.key) || segment.candidates[0]).join("");
}

function displayPreviewHtml(token) {
  if (token.isSpace) return token.raw;
  if (!token.isWord || token.classification !== "japanese") {
    const cls = token.classification === "punctuation" ? "" : token.classification;
    return `<span class="out-token ${cls}">${escapeHtml(displayPreviewText(token))}</span>`;
  }

  const segments = getConversionSegments(token)
    .map((segment) => {
      const selected = selectedCandidates.get(segment.key) || segment.candidates[0];
      const interactive = segment.candidates.length > 1 ? " interactive" : "";
      return `<span class="conversion-segment${interactive}" data-key="${escapeHtml(segment.key)}">${escapeHtml(selected)}</span>`;
    })
    .join("");
  return `<span class="out-token japanese">${segments}</span>`;
}

function candidateKey(token) {
  return `${token.wordIndex}:${token.clean}:${token.kana.kana}`;
}

function uniqueCandidates(values) {
  return [...new Set(values.filter(Boolean))];
}

function getConversionCandidates(token) {
  return getConversionSegments(token).flatMap((segment) => segment.candidates);
}

function candidatesForReading(reading) {
  if (kanaParticleConversions.has(reading)) return kanaParticleConversions.get(reading);
  const dictionaryCandidates = kanjiDictionary.get(reading) || [];
  return uniqueCandidates([...dictionaryCandidates, reading]);
}

function getConversionSegments(token) {
  if (!token.isWord || token.classification !== "japanese") return [];

  if (token.knownKanji) {
    return [
      {
        key: candidateKey(token),
        raw: token.raw,
        reading: token.kana.kana,
        candidates: [token.knownKanji],
      },
    ];
  }

  if (particleConversions.has(token.clean)) {
    return [
      {
        key: candidateKey(token),
        raw: token.raw,
        reading: token.kana.kana,
        candidates: particleConversions.get(token.clean),
      },
    ];
  }

  if (token.script === "katakana") {
    return [
      {
        key: candidateKey(token),
        raw: token.raw,
        reading: token.kana.kana,
        candidates: [token.kana.kana],
      },
    ];
  }

  return segmentKanaReading(token.kana.kana, token);
}

function segmentKanaReading(kana, token) {
  const dictionaryKeys = [...kanjiDictionary.keys(), ...kanaParticleConversions.keys()];
  const maxLength = Math.max(...dictionaryKeys.map((key) => key.length));
  const memo = new Map();

  function bestFrom(index) {
    if (index >= kana.length) return { score: 0, segments: [] };
    if (memo.has(index)) return memo.get(index);

    let best = {
      score: -1,
      segments: [
        {
          reading: kana[index],
          candidates: [kana[index]],
          recognized: false,
        },
      ],
    };

    for (let length = Math.min(maxLength, kana.length - index); length >= 1; length -= 1) {
      const reading = kana.slice(index, index + length);
      const hasDictionaryEntry = kanjiDictionary.has(reading) || kanaParticleConversions.has(reading);
      if (!hasDictionaryEntry) continue;

      const candidates = candidatesForReading(reading);
      const tail = bestFrom(index + length);
      const kanjiBonus = candidates.some((candidate) => candidate !== reading) ? 5 : 0;
      const particlePenalty = kanaParticleConversions.has(reading) ? 2 : 0;
      const score = length * 10 + kanjiBonus - particlePenalty + tail.score;
      if (score > best.score) {
        best = {
          score,
          segments: [{ reading, candidates, recognized: true }, ...tail.segments],
        };
      }
    }

    if (best.score < 0) {
      const tail = bestFrom(index + 1);
      best = {
        score: tail.score,
        segments: [{ reading: kana[index], candidates: [kana[index]], recognized: false }, ...tail.segments],
      };
    }

    memo.set(index, best);
    return best;
  }

  return bestFrom(0).segments.map((segment, index) => ({
    ...segment,
    raw: token.raw,
    key: `${candidateKey(token)}:${index}:${segment.reading}`,
  }));
}

function conversionLabel(token) {
  if (token.classification !== "japanese") return "—";
  const segments = getConversionSegments(token);
  const choiceCount = segments.filter((segment) => segment.candidates.length > 1).length;
  if (choiceCount === 0) return "kana";
  return `${choiceCount} choice group${choiceCount === 1 ? "" : "s"}`;
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function analyze(text) {
  let wordIndex = 0;
  const scored = splitInput(text).map((token) => scoreToken(token, token.isWord ? wordIndex++ : -1));
  return smoothScores(scored);
}

function render() {
  const tokens = analyze(input.value);
  const wordTokens = tokens.filter((token) => token.isWord);
  const counts = {
    japanese: wordTokens.filter((token) => token.classification === "japanese").length,
    english: wordTokens.filter((token) => token.classification === "english").length,
    ambiguous: wordTokens.filter((token) => token.classification === "ambiguous").length,
  };

  summaryBadge.textContent = `${wordTokens.length} token${wordTokens.length === 1 ? "" : "s"}`;
  sentenceSummary.innerHTML = [
    `<span><i class="dot ja"></i>${counts.japanese} Japanese</span>`,
    `<span><i class="dot en"></i>${counts.english} English</span>`,
    `<span><i class="dot amb"></i>${counts.ambiguous} ambiguous</span>`,
  ].join("");

  preview.innerHTML = tokens
    .map((token) => displayPreviewHtml(token))
    .join("");

  const candidateGroups = wordTokens
    .flatMap((token) => getConversionSegments(token).map((segment) => ({ token, segment })))
    .filter(({ segment }) => segment.candidates.length > 1);
  const activeGroup = candidateGroups.find(({ segment }) => segment.key === activeSegmentKey);

  if (activeGroup) {
    const selected = selectedCandidates.get(activeGroup.segment.key) || activeGroup.segment.candidates[0];
    const buttons = activeGroup.segment.candidates
      .map((candidate) => {
        const active = candidate === selected ? " active" : "";
        return `<button type="button" class="candidate-choice${active}" data-key="${escapeHtml(activeGroup.segment.key)}" data-value="${escapeHtml(candidate)}">${escapeHtml(candidate)}</button>`;
      })
      .join("");
    candidatePopover.hidden = false;
    candidatePopover.innerHTML = `
      <div class="popover-title">${escapeHtml(activeGroup.token.raw)} → ${escapeHtml(activeGroup.segment.reading)}</div>
      <div class="candidate-options">${buttons}</div>
    `;
  } else {
    candidatePopover.hidden = true;
    candidatePopover.innerHTML = "";
  }

  candidateList.innerHTML = candidateGroups.length
    ? candidateGroups
        .map(({ token, segment }) => {
          const selected = selectedCandidates.get(segment.key) || segment.candidates[0];
          const buttons = segment.candidates
            .map((candidate) => {
              const active = candidate === selected ? " active" : "";
              return `<button type="button" class="candidate-choice${active}" data-key="${escapeHtml(segment.key)}" data-value="${escapeHtml(candidate)}">${escapeHtml(candidate)}</button>`;
            })
            .join("");
          return `
            <div class="candidate-group">
              <div class="candidate-token">
                <strong>${escapeHtml(token.raw)} → ${escapeHtml(segment.reading)}</strong>
                <span>${segment.candidates.length} choices</span>
              </div>
              <div class="candidate-options">${buttons}</div>
            </div>
          `;
        })
        .join("")
    : `<div class="candidate-empty">No kanji choices for the current Japanese tokens.</div>`;

  rows.innerHTML = wordTokens
    .map((token) => {
      const reasons = token.reasons.length
        ? token.reasons.map((reason) => `<span class="reason">${escapeHtml(reason)}</span>`).join("")
        : `<span class="reason">no signal</span>`;
      const kanaPreview = token.classification === "japanese" ? displayPreview(token) : token.kana.complete ? token.kana.kana : "—";
      return `
        <tr>
          <td class="token-cell">${escapeHtml(token.raw)}</td>
          <td><span class="class-pill ${token.classification}">${token.classification}</span></td>
          <td>${escapeHtml(kanaPreview)}</td>
          <td>${escapeHtml(conversionLabel(token))}</td>
          <td class="score-cell">${token.ja.toFixed(1)}</td>
          <td class="score-cell">${token.en.toFixed(1)}</td>
          <td><div class="reasons">${reasons}</div></td>
        </tr>
      `;
    })
    .join("");
}

function setExample(index) {
  const item = examples[index];
  input.value = item.text;
  exampleSelect.value = String(index);
  selectedCandidates.clear();
  activeSegmentKey = "";
  render();
}

function buildExamples() {
  examples.forEach((item, index) => {
    const option = document.createElement("option");
    option.value = String(index);
    option.textContent = item.label;
    exampleSelect.appendChild(option);

    const button = document.createElement("button");
    button.className = "corpus-item";
    button.type = "button";
    button.innerHTML = `<strong>${escapeHtml(item.text)}</strong><span>${escapeHtml(item.note)}</span>`;
    button.addEventListener("click", () => setExample(index));
    corpusGrid.appendChild(button);
  });
}

input.addEventListener("input", () => {
  selectedCandidates.clear();
  activeSegmentKey = "";
  render();
});
exampleSelect.addEventListener("change", (event) => setExample(Number(event.target.value)));
preview.addEventListener("click", (event) => {
  const segment = event.target.closest(".conversion-segment.interactive");
  activeSegmentKey = segment ? segment.dataset.key : "";
  render();
});
candidateList.addEventListener("click", (event) => {
  const button = event.target.closest(".candidate-choice");
  if (!button) return;
  selectedCandidates.set(button.dataset.key, button.dataset.value);
  activeSegmentKey = button.dataset.key;
  render();
});
candidatePopover.addEventListener("click", (event) => {
  const button = event.target.closest(".candidate-choice");
  if (!button) return;
  selectedCandidates.set(button.dataset.key, button.dataset.value);
  activeSegmentKey = button.dataset.key;
  render();
});
document.querySelector("#prevExample").addEventListener("click", () => {
  const next = (Number(exampleSelect.value) - 1 + examples.length) % examples.length;
  setExample(next);
});
document.querySelector("#nextExample").addEventListener("click", () => {
  const next = (Number(exampleSelect.value) + 1) % examples.length;
  setExample(next);
});
document.querySelector("#clearInput").addEventListener("click", () => {
  input.value = "";
  selectedCandidates.clear();
  activeSegmentKey = "";
  render();
  input.focus();
});
document.querySelector("#resetCandidates").addEventListener("click", () => {
  selectedCandidates.clear();
  activeSegmentKey = "";
  render();
});

buildExamples();
setExample(0);
