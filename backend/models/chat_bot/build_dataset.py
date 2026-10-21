"""Builds dataset_v2.jsonl: fine-tuning data for medfarm-llama from the whole KB.

The first dataset (dataset.jsonl) covers the 42 original facts. This one covers all
KB entries (care_kb.py too) and the prompts the chat server sends today:
- answer:  a farmer question and the facts that answer it (1-3, cited)
- section: the server's detailed-answer questions ("{d} වල ප්‍රතිකාර ගැන ...")
- urgent:  warning signs (bleeding, cannot stand ...) answered with the warning first
- abstain: evidence that does not answer the question (other topics, off-topic)
- refuse:  medicine, dose and withdrawal questions

Prompts come from server.build_prompt(), so training matches what the model is sent.
Split by KB entry: held-out entries never appear in training, not even as
distractors; abstain/refuse questions are split by question wording.

Run:  python build_dataset.py   (writes dataset_v2.jsonl next to this file)
dataset.jsonl stays as it is: the server reads the original 42 facts from it.
"""
import json
import os
import random
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "app"))

import care_kb  # noqa: E402
import friendly  # noqa: E402
import server  # noqa: E402

OUT = os.path.join(HERE, "dataset_v2.jsonl")
SEED = 7
STAGES = ["LM", "HI"]
# Evidence passages per prompt, as the server sends them (Sinhala costs more tokens).
K = {"en": 3, "si": 2}

KB = server.KB
BY_ID = server.KB_BY_ID
TOPICS = sorted({f["topic"] for f in KB})

# Held out for testing: the 10 facts held out from the first model, plus one care
# entry of each kind per main disease and one per newer topic.
HELD_OUT = {"KB-001", "KB-002", "KB-030", "KB-031", "KB-056", "KB-060", "KB-086", "KB-100",
            "KB-108", "KB-111",
            "KB-203", "KB-206", "KB-209", "KB-212", "KB-217", "KB-224", "KB-226", "KB-233",
            "KB-243", "KB-248", "KB-304", "KB-314", "KB-325", "KB-332", "KB-343", "KB-352",
            "KB-364", "KB-372", "KB-383", "KB-393"}

# Short names farmers use, besides friendly.disease_name().
ALIASES = {
    "en": {
        care_kb.FMD: ["FMD", "foot and mouth disease"],
        care_kb.LSD: ["LSD", "lumpy skin"],
        care_kb.MAS: ["mastitis", "udder infection"],
        care_kb.RW: ["ringworm"],
        care_kb.DIA: ["scours", "diarrhoea"],
        care_kb.BLO: ["bloat"],
        care_kb.PNE: ["pneumonia"],
        care_kb.TICK: ["tick fever", "ticks"],
        care_kb.WORM: ["worms"],
        care_kb.EYE: ["pinkeye"],
        care_kb.FOOT: ["foot rot"],
        care_kb.MF: ["milk fever"],
    },
    "si": {
        care_kb.FMD: ["FMD", "මුඛ පාද රෝගය", "කුර ලෙඩේ"],
        care_kb.LSD: ["LSD", "ගැටිති රෝගය", "ගැටිති ලෙඩේ"],
        care_kb.MAS: ["mastitis", "බුරුලු ප්‍රදාහය", "තන ලෙඩේ"],
        care_kb.RW: ["දද", "දද රෝගය"],
        care_kb.DIA: ["පාචනය", "බඩ යාම"],
        care_kb.BLO: ["බඩ පිපීම"],
        care_kb.PNE: ["නියුමෝනියාව"],
        care_kb.TICK: ["කිනිතුලු උණ"],
        care_kb.WORM: ["බඩේ පණුවන්"],
        care_kb.EYE: ["ඇසේ ආසාදනය"],
        care_kb.FOOT: ["කුර කුණුවීම"],
        care_kb.MF: ["කිරි උණ"],
    },
}

# Questions about one section of a topic. The last wording of each list is held out.
SECTION_Q = {
    "en": {
        "signs": ["What are the signs of {d}?", "How do I know if my cow has {d}?",
                  "What does {d} look like in a cow?", "symptoms of {d}"],
        "care": ["What can I do at home for {d}?", "How do I look after a cow with {d}?",
                 "What should I do for {d} until the vet comes?", "home care for {d}"],
        "treatment": ["How is {d} treated?", "What will the vet do for {d}?",
                      "Can {d} be cured?", "treatment for {d}"],
        "prevention": ["How can I prevent {d}?", "How do I stop {d} spreading?",
                       "How do I protect my herd from {d}?", "how to avoid {d}"],
        "about": ["What is {d}?", "Tell me about {d}.", "What causes {d}?", "{d}?"],
    },
    "si": {
        "signs": ["{d} වල ලක්ෂණ මොනවද?", "මගේ හරකාට {d} තියෙනවද කියලා දැනගන්නේ කොහොමද?",
                  "{d} හැදුණාම පේන්නේ මොනවගේද?", "{d} ලක්ෂණ කියන්න"],
        "care": ["{d} හැදුණු හරකාට ගෙදරදී කරන්න පුළුවන් මොනවද?",
                 "{d} තියෙන ගවයෙක්ව බලාගන්නේ කොහොමද?",
                 "වෛද්‍යවරයා එනකම් {d} වලට කරන්න ඕන මොනවද?", "{d} වලට ගෙදර කරන දේවල්"],
        "treatment": ["{d} වලට ප්‍රතිකාර මොනවද?", "{d} සනීප කරන්න පුළුවන්ද?",
                      "{d} වලට වෛද්‍යවරයා කරන්නේ මොනවද?", "{d} සුව කරන්නේ කොහොමද"],
        "prevention": ["{d} වළක්වගන්නේ කොහොමද?", "{d} පැතිරෙන එක නවත්තන්නේ කොහොමද?",
                       "{d} වලින් රංචුව ආරක්ෂා කරගන්නේ කොහොමද?", "{d} එන්නැති කරන්න මොකද කරන්නේ"],
        "about": ["{d} කියන්නේ මොකක්ද?", "{d} ගැන කියන්න", "{d} හැදෙන්නේ ඇයි?", "{d}?"],
    },
}
# Follow-ups: the server sends "<question> (<topic>)" (server.followup_kind).
FOLLOW_Q = {
    "en": {"signs": ["What are its signs", "How do I know she has it"],
           "care": ["What can I do for it at home", "How do I look after her"],
           "treatment": ["How is it treated", "Will it go away"],
           "prevention": ["How do I prevent it", "How do I stop it spreading"],
           "about": ["Tell me more", "What is it"]},
    "si": {"signs": ["ඒකේ ලක්ෂණ මොනවද", "ඒක තියෙනවද කියලා දැනගන්නේ කොහොමද"],
           "care": ["ඒකට ගෙදරදී කරන්න පුළුවන් මොනවද", "එයාව බලාගන්නේ කොහොමද"],
           "treatment": ["ඒක සනීප කරන්නේ කොහොමද", "ඒක හොඳ වෙයිද"],
           "prevention": ["ඒක වළක්වන්නේ කොහොමද", "ඒක පැතිරෙන එක නවත්තන්නේ කොහොමද"],
           "about": ["තව දෙන්න", "තව විස්තර කියන්න"]},
}
KIND_SECTION = {"sign": "signs", "care": "care", "treatment": "treatment",
                "prevention": "prevention", "about": "about"}

# A farmer describing a sick cow, and the KB entries that answer it (warning first).
SYMPTOM_Q = [
    ("My cow is drooling a lot and smacking her lips.", "මගේ හරකාගේ කටින් ගොඩක් කෙළ හැලෙනවා", ["KB-201"]),
    ("There are blisters on my cow's tongue and lips.", "හරකාගේ දිවේ සහ තොල්වල බිබිලි තියෙනවා", ["KB-007"]),
    ("My cow is limping and lies down most of the day.", "හරකා කොර ගහනවා, ගොඩක් වෙලා වැතිරිලා ඉන්නවා", ["KB-202"]),
    ("She has blisters between the claws.", "කුර අතර බිබිලි හැදිලා", ["KB-008"]),
    ("She has a fever and her milk dropped.", "උණ තියෙනවා, කිරිත් අඩු වෙලා", ["KB-203"]),
    ("There are hard round lumps all over her skin.", "ඇඟ පුරා තද රවුම් ගැටිති හැදිලා", ["KB-032", "KB-212"]),
    ("Her eyes are watering and her nose is running.", "ඇස්වලින් කඳුළු එනවා, නාසයෙන් දියර එනවා", ["KB-211"]),
    ("The lumps on her skin have turned into open sores.", "ගැටිති පැලිලා තුවාල වෙලා", ["KB-034"]),
    ("She has lumps on her head and neck.", "ඔලුවේ සහ බෙල්ලේ ගැටිති තියෙනවා", ["KB-033"]),
    ("There are clots in the milk.", "කිරිවල කැටි එනවා", ["KB-059"]),
    ("The milk looks watery.", "කිරි වතුර වගේ", ["KB-059"]),
    ("One quarter of the udder is swollen.", "එක තනයක් ඉදිමිලා", ["KB-060"]),
    ("The udder is hot and hurts when I touch it.", "බුරුල්ල රස්නෙයි, අල්ලද්දි රිදෙනවා", ["KB-061"]),
    ("The udder has gone red.", "බුරුල්ල රතු වෙලා", ["KB-062"]),
    ("Her milk dropped but the udder and milk look normal.", "කිරි අඩු වුණා, බුරුල්ලේ කිසි වෙනසක් පේන්නේ නෑ", ["KB-228", "KB-058"]),
    ("She has round bald patches with grey crusts.", "රවුමට ලොම් ගැලවිලා අළු පාට පොතු", ["KB-087", "KB-088"]),
    ("My calf has hairless patches around the eyes.", "වස්සාගේ ඇස් වටේ ලොම් ගැලවිලා", ["KB-090"]),
    ("She has skin patches on the chest and legs.", "පපුවේ සහ කකුල්වල පැල්ලම් තියෙනවා", ["KB-231", "KB-091"]),
    ("My calf has watery dung and is weak.", "වස්සාට බඩ යනවා, දුර්වල වෙලා", ["KB-302"]),
    ("Her left side is swollen and tight like a drum.", "වම් පැත්තේ බඩ පිම්බිලා බෙරයක් වගේ", ["KB-244", "KB-312"]),
    ("She is coughing and breathing fast.", "කැස්ස තියෙනවා, හුස්ම ඉක්මනට ගන්නවා", ["KB-322"]),
    ("Her urine is red and her gums are pale.", "මුත්‍රා රතු පාටයි, විදුරුමස් සුදුමැලියි", ["KB-332"]),
    ("My calf is thin, has a rough coat and is not growing.", "වස්සා කෙට්ටුයි, ලොම් රළුයි, වැඩෙන්නේ නෑ", ["KB-342"]),
    ("Her eye is cloudy white and she keeps it shut.", "ඇස සුදු පාට වෙලා, ඇස වහගෙන ඉන්නවා", ["KB-352"]),
    ("Her foot is swollen and the skin between the claws smells bad.", "කුර අතර පැලිලා ගඳයි, පාදය ඉදිමිලා", ["KB-362"]),
    ("She calved yesterday and now cannot get up; her ears are cold.", "ඊයේ පැටවා දැම්මා, දැන් නැගිටින්න බෑ, කන් සීතලයි", ["KB-245", "KB-372"]),
    ("Her milk dropped suddenly.", "කිරි හදිසියේම අඩු වුණා", ["KB-381", "KB-383"]),
    ("She feels hot, I think she has a fever.", "උණ තියෙනවා වගේ", ["KB-391"]),
    ("She has a fever and is not eating.", "උණ තියෙනවා, කන්නෙත් නෑ", ["KB-392"]),
    # Warning signs
    ("Blood is coming from my cow's mouth.", "මගේ හරකාගේ කටින් ලේ එනවා", ["KB-241"]),
    ("There is blood coming from her nose.", "නාසයෙන් ලේ එනවා", ["KB-241"]),
    ("My cow died suddenly with dark blood from the nose.", "හරකා හදිසියේ මැරුණා, නාසයෙන් කළු ලේ ඇවිත්", ["KB-242"]),
    ("She cannot stand and is trembling.", "හරකාට නැගිටින්න බෑ, වෙව්ලනවා", ["KB-243"]),
    ("She is struggling to breathe and collapsed.", "හුස්ම ගන්න අමාරුයි, ඇද වැටුණා", ["KB-243"]),
    ("Blood from the mouth and she has a fever too.", "කටින් ලේ එනවා. උණත් තියෙනවා", ["KB-241"]),
]
# Questions the KB does not answer. The last third is held out.
OFF_TOPIC = [
    ("How much is a bus ticket to Kandy?", "මහනුවරට බස් ටිකට් එක කීයද?"),
    ("What will the weather be tomorrow?", "හෙට කාලගුණය කොහොමද?"),
    ("How do I grow tomatoes?", "තක්කාලි වවන්නේ කොහොමද?"),
    ("How do I fix my tractor?", "ට්‍රැක්ටරේ හදන්නේ කොහොමද?"),
    ("What price does the collection centre pay for milk?", "එකතු කරන මධ්‍යස්ථානයේ කිරි ලීටරයක් කීයද?"),
    ("How do I raise chickens?", "කුකුළන් ඇති කරන්නේ කොහොමද?"),
    ("Which cow breed gives the most milk?", "වැඩියෙන්ම කිරි දෙන ගව වර්ගය මොකක්ද?"),
    ("How long is a cow pregnant?", "ගවයෙක් කොච්චර කල් ගැබ් ගන්නවද?"),
    ("When should I artificially inseminate my cow?", "කෘත්‍රිම සිංචනය කරන්න හොඳම වෙලාව කවදද?"),
    ("How do I get a farm loan?", "ගොවිපොළ ණයක් ගන්නේ කොහොමද?"),
    ("How many litres of milk does a cow give a day?", "ගවයෙක් දවසකට කිරි ලීටර් කීයක් දෙනවද?"),
    ("How do I make yoghurt?", "මී කිරි හදන්නේ කොහොමද?"),
    ("What is the best grass to plant for cattle?", "ගවයන්ට වවන්න හොඳම තණකොළ මොකක්ද?"),
    ("How old should a heifer be before breeding?", "වැස්සියක් කීයේ වයසේදී බීජ කරන්න ඕනද?"),
    ("How much does a cow weigh?", "ගවයෙක්ගේ බර කීයද?"),
]
# Medicine, dose and withdrawal questions. The last wording is held out.
REFUSE_Q = {
    "en": ["What dose of antibiotic should I give for {d}?", "How many ml of medicine for {d}?",
           "Which injection cures {d}?", "Which tablet should I give my cow for {d}?",
           "How many days must I throw away milk after treating {d}?"],
    "si": ["{d} වලට දෙන්න ඕන බෙහෙත මොකක්ද?", "{d} වලට එන්නත් කීයක් ගහන්න ඕනද?",
           "{d} වලට ප්‍රතිජීවක මාත්‍රාව කීයද?", "{d} වලට දෙන්න ඕන ටැබ්ලට් මොනවද?",
           "{d} වලට ප්‍රතිකාර කළාට පස්සේ කිරි කොච්චර කල් විසි කරන්න ඕනද?"],
}
# Common farmer spellings: "උන" for "උණ", "ලෙඩ" ... (only in some Sinhala questions).
SI_TYPOS = [("ණ", "න"), ("ළ", "ල"), ("ඳ", "ද")]


def misspell(text, rng):
    for a, b in SI_TYPOS:
        if a in text and rng.random() < 0.6:
            text = text.replace(a, b)
    return text


def name(topic, lang, rng):
    return rng.choice([friendly.disease_name(topic, lang)] + ALIASES[lang].get(topic, []))


def sections(topic):
    """{section: [entries]} of a topic's care entries (kind sign/care/... -> section)."""
    out = {}
    for f in KB:
        if f["topic"] == topic and f["kind"] in KIND_SECTION:
            out.setdefault(KIND_SECTION[f["kind"]], []).append(f)
    return out


def text(f, lang):
    return f[lang] or f["en"]


def target(facts, lang, stage):
    return " ".join(f"{text(f, lang)} [{f['id']}-{stage}]" for f in facts)


class Builder:
    def __init__(self):
        self.rng = random.Random(SEED)
        self.rows = []
        self.seen = set()

    def distractors(self, n, avoid_topics, split):
        """n entries from other topics (no warnings); held-out ones only in the test split."""
        pool = [f for f in KB if f["topic"] not in avoid_topics and f["kind"] != "urgent"
                and (split == "test" or f["id"] not in HELD_OUT)]
        return self.rng.sample(pool, n)

    def add(self, kind, lang, question, gold, evidence, split=None, stage=None):
        """gold: entries the answer cites (none for abstain/refuse); evidence: all passages."""
        stage = stage or self.rng.choice(STAGES)
        held = any(f["id"] in HELD_OUT for f in evidence)
        if split is None:
            split = "test" if any(f["id"] in HELD_OUT for f in gold) else "train"
        if split == "train" and held:
            return  # held-out entries never appear in training
        prompt = server.build_prompt(question, lang, [(f, 0) for f in evidence], stage)
        if prompt in self.seen:
            return
        self.seen.add(prompt)
        answer = {"abstain": server.ABSTAIN[lang], "refuse": server.REFUSE[lang]}.get(
            kind) or target(gold, lang, stage)
        self.rows.append({
            "split": split, "kind": "answer" if gold else kind, "type": kind, "lang": lang,
            "fact": gold[0]["id"] if gold else None, "facts": [f["id"] for f in gold],
            "question": question, "prompt": prompt, "answer": answer,
            "gold_cite": f"{gold[0]['id']}-{stage}" if gold else None,
        })

    def answered(self, kind, lang, question, gold, extra=0, split=None):
        """Gold entries plus `extra` distractors, shuffled, at most K[lang] passages."""
        gold = gold[:K[lang]]
        n = min(extra, K[lang] - len(gold))
        split = split or ("test" if any(f["id"] in HELD_OUT for f in gold) else "train")
        evidence = gold + (self.distractors(n, {gold[0]["topic"]}, split) if n else [])
        self.rng.shuffle(evidence)
        # The answer follows the evidence order, as the model reads it.
        self.add(kind, lang, question, [f for f in evidence if f in gold], evidence, split)

    def build(self):
        rng = self.rng
        # 1. The original questions of the first dataset, with fresh evidence.
        for row in map(json.loads, open(server.DATASET, encoding="utf-8")):
            if row["kind"] == "answer":
                fact = BY_ID[row["fact"]]
                for extra in (1, 2):
                    self.answered("answer", row["lang"], row["question"], [fact], extra)

        for topic in TOPICS:
            if topic == "General cattle health":
                continue
            # Emergencies and the sick-cow advice only come as the server's own questions.
            server_only = topic in (care_kb.EM, care_kb.SICK)
            for section, entries in sections(topic).items():
                train_pool = [f for f in entries if f["id"] not in HELD_OUT]
                for lang in ("en", "si"):
                    n = K[lang]

                    def facts(split):
                        """Training never sees held-out entries; test always includes one."""
                        if split == "train":
                            return rng.sample(train_pool, min(n, len(train_pool)))
                        held = [f for f in entries if f["id"] in HELD_OUT]
                        rest = rng.sample(train_pool, min(n - 1, len(train_pool)))
                        return held[:1] + rest

                    has_test = len(train_pool) < len(entries)
                    # 2. The server's detailed-answer questions: all the section's facts.
                    title = friendly.TITLES[lang].get(section)
                    if title:
                        ask = server.SECTION_QUESTION[lang].format(
                            d=friendly.disease_name(topic, lang), part=title.lower())
                        for _ in range(3):
                            if train_pool:
                                self.answered("section", lang, ask, facts("train"), 0, "train")
                        if has_test:
                            self.answered("section", lang, ask, facts("test"), 0, "test")
                    # 4. Follow-ups: "<question> (<topic>)".
                    for wording in FOLLOW_Q[lang][section]:
                        for split in ("train", "test") if has_test else ("train",):
                            if split == "test" or train_pool:
                                self.answered("followup", lang, f"{wording} ({topic})",
                                              facts(split), 0, split)
                    if server_only:
                        continue
                    # 3. Farmer wordings of the same question (last wording: test only).
                    wordings = SECTION_Q[lang][section]
                    for i, wording in enumerate(wordings):
                        split = "test" if i == len(wordings) - 1 else "train"
                        for _ in range(2 if split == "train" else 1):
                            q = wording.format(d=name(topic, lang, rng))
                            if lang == "si" and rng.random() < 0.3:
                                q = misspell(q, rng)
                            if split == "test" or train_pool:
                                self.answered("answer", lang, q, facts(split), 1, split)
                        if has_test and split == "train":
                            # A seen wording about an unseen entry.
                            q = wording.format(d=name(topic, lang, rng))
                            self.answered("answer", lang, q, facts("test"), 1, "test")

        # 5. A farmer describing signs; warnings first, plus topic facts as the server sends.
        for en, si, ids in SYMPTOM_Q:
            gold = [BY_ID[i] for i in ids]
            for lang, q in (("en", en), ("si", si)):
                kind = "urgent" if gold[0]["kind"] == "urgent" else "symptom"
                for extra in (0, 1):
                    self.answered(kind, lang, q, gold, extra)
                if lang == "si":
                    self.answered(kind, lang, misspell(q, rng), gold, 1)

        # 6. Abstain: evidence from other topics only, and off-topic questions.
        for topic in TOPICS:
            if topic in ("General cattle health", care_kb.SICK, care_kb.EM):
                continue
            for lang in ("en", "si"):
                for section in ("signs", "treatment", "prevention"):
                    wordings = SECTION_Q[lang][section]
                    i = rng.randrange(len(wordings))
                    split = "test" if i == len(wordings) - 1 else "train"
                    q = wordings[i].format(d=name(topic, lang, rng))
                    avoid = {topic, "General cattle health", care_kb.SICK, care_kb.EM}
                    self.add("abstain", lang, q, [], self.distractors(K[lang], avoid, split), split)
        for i, pair in enumerate(OFF_TOPIC):
            split = "test" if i >= len(OFF_TOPIC) * 2 // 3 else "train"
            for lang, q in zip(("en", "si"), pair):
                for _ in range(3):
                    self.add("abstain", lang, q, [], self.distractors(K[lang], set(), split), split)

        # 7. Refuse: medicine and dose questions, with the topic's treatment entries.
        for topic in TOPICS:
            treat = sections(topic).get("treatment")
            if not treat or topic in (care_kb.EM, care_kb.SICK):
                continue
            for lang in ("en", "si"):
                for i, wording in enumerate(REFUSE_Q[lang]):
                    split = "test" if i == len(REFUSE_Q[lang]) - 1 else "train"
                    pool = [f for f in treat if split == "test" or f["id"] not in HELD_OUT]
                    if not pool:
                        continue
                    evidence = rng.sample(pool, min(K[lang], len(pool)))
                    self.add("refuse", lang, wording.format(d=name(topic, lang, rng)), [],
                             evidence, split)
        rng.shuffle(self.rows)
        return self.rows


def main():
    rows = Builder().build()
    with open(OUT, "w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    print(f"{len(rows)} examples -> {OUT}")
    print(Counter((r["split"], r["lang"]) for r in rows))
    print(Counter((r["split"], r["type"]) for r in rows))
    covered = {i for r in rows for i in r["facts"]}
    print(f"KB entries answered: {len(covered)} / {len(KB)}; "
          f"missing: {sorted(f['id'] for f in KB if f['id'] not in covered)}")
    train_ids = {i for r in rows if r["split"] == "train" for i in r["facts"]}
    assert not train_ids & HELD_OUT, "held-out entry in training"


if __name__ == "__main__":
    main()
