"""Friendly, structured answers built from KB entries.

Every health statement is a KB entry shown with its [KB-ID]; this module only adds
greetings, headings, plain-language framing and a vet referral. Sections come from
care_kb.py (signs / treatment / care / prevention / urgent). No medicine names or
doses are ever added.
"""
import re

import care_kb

DISEASE = {
    "en": {
        "Foot-and-Mouth Disease": "Foot-and-Mouth Disease (FMD)",
        "Lumpy Skin Disease": "Lumpy Skin Disease (LSD)",
        "Mastitis": "mastitis (udder infection)",
        "Ringworm": "ringworm (a fungal skin infection)",
        care_kb.DIA: "diarrhoea (scours)",
        care_kb.BLO: "bloat",
        care_kb.PNE: "pneumonia (a lung infection)",
        care_kb.TICK: "ticks and tick fever",
        care_kb.WORM: "worms (internal parasites)",
        care_kb.EYE: "pinkeye (an eye infection)",
        care_kb.FOOT: "foot rot",
        care_kb.MF: "milk fever (low calcium after calving)",
        care_kb.FEED: "feeding and milk yield",
        care_kb.SICK: "a sick cow",
    },
    "si": {
        "Foot-and-Mouth Disease": "මුඛ හා පාද රෝගය (FMD)",
        "Lumpy Skin Disease": "ගැටිති සමේ රෝගය (LSD)",
        "Mastitis": "බුරුලු ප්‍රදාහය (Mastitis)",
        "Ringworm": "දද (Ringworm)",
        care_kb.DIA: "පාචනය (බඩ යාම)",
        care_kb.BLO: "බඩ පිපීම (Bloat)",
        care_kb.PNE: "නියුමෝනියාව (පෙනහළු ආසාදනය)",
        care_kb.TICK: "කිනිතුල්ලන් සහ කිනිතුලු උණ",
        care_kb.WORM: "බඩේ පණුවන්",
        care_kb.EYE: "ඇසේ ආසාදනය (Pinkeye)",
        care_kb.FOOT: "කුර කුණුවීම (Foot rot)",
        care_kb.MF: "කිරි උණ (Milk fever)",
        care_kb.FEED: "ආහාර සහ කිරි නිෂ්පාදනය",
        care_kb.SICK: "අසනීප ගවයෙක්",
    },
}

# Symptom-dictionary keys (first word of each expansion in server.SYMPTOMS) that
# describe what the farmer sees, as opposed to "can people catch it?".
SIGN_WORDS = {"blisters", "hooves", "mouth", "nodules", "fever", "udder", "milk",
              "swelling", "hair", "itching", "eyes", "body", "tears", "nasal",
              "appetite", "lameness", "foul-smelling", "cloudy", "diarrhoea", "bloat",
              "cough", "urine", "pale", "weight", "calving", "weakness"}

TEXT = {
    "en": {
        "sick_open": "I'm sorry to hear about your cow. From what you describe, this may be {d}.",
        "info_open": "Good question! Here's what I know about {d}:",
        "treat_open": "Here's how {d} is usually treated and managed:",
        "prevent_open": "Here's how to protect your herd from {d}:",
        "plain_open": "Here's what I know:",
        "unclear": "I can't tell which disease this is from this description alone.",
        "general_open": "These signs can be caused by many different illnesses, so I can't say which disease it is from this description alone. Here is what to do now. If you notice more signs (in the udder or milk, mouth, feet, skin, dung or breathing), tell me and I can narrow it down.",
        "urgent_head": "Urgent:",
        "signs_head": "Signs that match:",
        "treat_head": "Treatment (by a vet):",
        "care_head": "Care at home:",
        "prevent_head": "Prevention and recommendations:",
        "vet_will": "What a vet will do:",
        "sick_close": "Please contact your vet or the government veterinary office soon, so they can examine your cow and give the right treatment. I'm here if you have more questions!",
        "info_close": "I hope this helps! Feel free to ask me anything else.",
        "abstain": "Sorry, I don't have information about that yet. I can help with Foot-and-Mouth Disease, Lumpy Skin Disease, mastitis, ringworm, diarrhoea, bloat, pneumonia, ticks and tick fever, worms, pinkeye, foot rot, milk fever, feeding and keeping your farm clean. For other questions, your vet or livestock extension officer is the best person to ask.",
        "refuse": "I'm sorry, I can't suggest medicine names or doses. The wrong medicine or amount can harm your cow and affect milk safety. Please call a registered vet; they can examine the animal and prescribe the right treatment.",
        "hello": "Hello! I'm MedFarm, your cattle-health helper. Tell me what you notice in your cow, for example \"my cow has blisters in its mouth\", and I'll tell you the likely disease, how it is treated and what you can do.",
        "thanks": "You're welcome! Wishing your herd good health. Ask me anytime.",
        "about": "I'm MedFarm, a cattle-health helper. Describe your cow's signs and I'll tell you which problem they may match (such as FMD, lumpy skin disease, mastitis, diarrhoea, bloat or pneumonia), how a vet treats it, how to care for the animal and how to prevent it. I can't prescribe medicines or doses.",
    },
    "si": {
        "sick_open": "ඔබේ ගවයාට මෙහෙම වීම ගැන කනගාටුයි. ඔබ කියන ලක්ෂණ අනුව මෙය {d} වෙන්න පුළුවන්.",
        "info_open": "හොඳ ප්‍රශ්නයක්! {d} ගැන මම දන්නා දේ:",
        "treat_open": "{d} සාමාන්‍යයෙන් ප්‍රතිකාර කරන සහ පාලනය කරන ආකාරය:",
        "prevent_open": "{d} වලින් ඔබේ රංචුව ආරක්ෂා කරගන්නා ආකාරය:",
        "plain_open": "මම දන්නා දේ:",
        "unclear": "මේ විස්තරයෙන් පමණක් මෙය කුමන රෝගයදැයි මට කියන්න බැහැ.",
        "general_open": "මෙම ලක්ෂණ විවිධ රෝග රාශියක් නිසා ඇති විය හැකි බැවින්, මේ විස්තරයෙන් පමණක් මෙය කුමන රෝගයදැයි මට කියන්න බැහැ. දැන් කළ යුතු දේ මෙන්න. තවත් ලක්ෂණ (බුරුල්ලේ හෝ කිරිවල, කටේ, පාදවල, සමේ, ගොමවල හෝ හුස්ම ගැනීමේ) දුටුවොත් මට කියන්න, එවිට මට වඩාත් නිවැරදිව කියන්න පුළුවන්.",
        "urgent_head": "හදිසි අවධානයට:",
        "signs_head": "ගැළපෙන ලක්ෂණ:",
        "treat_head": "ප්‍රතිකාර (පශු වෛද්‍යවරයා මගින්):",
        "care_head": "නිවසේදී කළ හැකි සත්කාර:",
        "prevent_head": "වැළැක්වීම සහ නිර්දේශ:",
        "vet_will": "පශු වෛද්‍යවරයා කරන දේ:",
        "sick_close": "ඉක්මනින් ඔබේ පශු වෛද්‍යවරයාට හෝ රජයේ පශු වෛද්‍ය කාර්යාලයට කතා කරන්න. ඔවුන්ට ගවයාව පරීක්ෂා කරලා නිවැරදි ප්‍රතිකාර දෙන්න පුළුවන්. තව මොනවා හරි දැනගන්න ඕන නම් අහන්න!",
        "info_close": "මේක ප්‍රයෝජනවත් වෙයි කියලා හිතනවා! තව ප්‍රශ්න තියෙනවා නම් අහන්න.",
        "abstain": "සමාවෙන්න, ඒ ගැන තොරතුරු මා ළඟ තවම නැහැ. මට උදව් කරන්න පුළුවන් මුඛ හා පාද රෝගය, ගැටිති සමේ රෝගය (LSD), බුරුලු ප්‍රදාහය (Mastitis), දද (Ringworm), පාචනය, බඩ පිපීම, නියුමෝනියාව, කිනිතුලු උණ, බඩේ පණුවන්, ඇසේ ආසාදන, කුර කුණුවීම, කිරි උණ, ආහාර සහ ගොවිපොළ පිරිසිදුකම ගැනයි. වෙනත් ප්‍රශ්න සඳහා ඔබේ පශු වෛද්‍යවරයාගෙන් හෝ ගොවි උපදේශකගෙන් අහන්න.",
        "refuse": "සමාවෙන්න, මට බෙහෙත් නම් හෝ මාත්‍රා කියන්න බැහැ. වැරදි බෙහෙතක් හෝ වැරදි ප්‍රමාණයක් ගවයාට හානි කරන්නත්, කිරිවල ආරක්ෂාවට බලපාන්නත් පුළුවන්. කරුණාකර ලියාපදිංචි පශු වෛද්‍යවරයෙකුට කතා කරන්න; ඔවුන්ට සතාව පරීක්ෂා කරලා නිවැරදි ප්‍රතිකාරය දෙන්න පුළුවන්.",
        "hello": "ආයුබෝවන්! මම MedFarm, ඔබේ ගව සෞඛ්‍ය සහායකයා. ඔබේ ගවයාගේ ඔබ දකින ලක්ෂණ මට කියන්න, උදාහරණයක් ලෙස \"හරකාගේ කටේ බිබිලි\". ගැළපෙන රෝගය, ප්‍රතිකාර සහ ඔබට කළ හැකි දේ මම කියන්නම්.",
        "thanks": "ඔබට සාදරයෙන් පිළිගනිමු! ඔබේ ගව රංචුවට නිරෝගී සුවය ලැබේවා. ඕනම වෙලාවක අහන්න.",
        "about": "මම MedFarm, ගව සෞඛ්‍ය සහායකයෙක්. ඔබේ ගවයාගේ ලක්ෂණ කිව්වොත්, ඒවා ගැළපෙන රෝගය (මුඛ හා පාද රෝගය, ගැටිති සමේ රෝගය, බුරුලු ප්‍රදාහය හෝ දද), පශු වෛද්‍යවරයා ප්‍රතිකාර කරන ආකාරය, සත්කාර සහ වැළැක්වීම ගැන මම කියන්නම්. මට බෙහෙත් හෝ මාත්‍රා නියම කරන්න බැහැ.",
    },
}

# Original-KB hygiene facts that also belong in a disease's sections.
EXTRA = {
    "Foot-and-Mouth Disease": {"care": ["KB-109"], "prevention": ["KB-114"]},
    "Lumpy Skin Disease": {"care": ["KB-109"], "prevention": ["KB-114"]},
    "Mastitis": {"prevention": ["KB-109", "KB-113"]},
    "Ringworm": {"prevention": ["KB-113"]},
}

TREAT_Q = re.compile(r"\btreat|\bcure|\bheal|what (should|can|do) i do|what to do|how (to|can i) help|"
                     r"ප්‍?රතිකාර|සුව කර|සනීප කර|හොඳ කර|මොකද කරන්න|මොනවද කරන්න|කරන්න ඕන|"
                     r"කරන්නේ කොහොමද|කළ යුත්තේ|කළ යුතු", re.I)
PREVENT_Q = re.compile(r"prevent|avoid|protect|stop.{0,20}spread|vaccin|\bcontrol|වළක්ව|වැළැක්ව|"
                       r"ආරක්ෂා කර|පැතිරීම නවත්ව|පාලනය", re.I)
SI = r"[඀-෿]"
URGENT = [
    (re.compile(r"\bblood|\bbleed|(?<!" + SI + r")ලේ(?!" + SI + r")", re.I), "KB-241"),
    (re.compile(r"\bdied\b|\bdead\b|sudden(ly)? death|මැරුණ|මැරිල|මිය ගිය|මියගිය", re.I), "KB-242"),
    (re.compile(r"can'?t stand|cannot stand|not standing|unable to stand|collaps|breath|trembl|"
                r"නැගිටින්න බැ|නැගිටින්නේ නැ|හුස්ම|වෙව්ල|ඇද වැටු|වැටිලා", re.I), "KB-243"),
    (re.compile(r"bloat|(left|stomach|belly|abdomen|rumen).{0,25}(swol|swell|distend|blown)|"
                r"බඩ පිම්බ|බඩ පිපිල|බඩ පිපී", re.I), "KB-244"),
    (re.compile(r"(after|since) (calving|giving birth|delivery).{0,60}(down|stand|get up)|"
                r"(down|stand|get up).{0,60}after (calving|giving birth|delivery)|"
                r"පැටවා.{0,40}(නැගිටින්න බැ|වැටිල|නැගිටින්නේ නැ)", re.I), "KB-245"),
]

GREETING = re.compile(r"^\W*(hi+|hello|hey|hai|good (morning|afternoon|evening)|ayubowan|"
                      r"ආයුබෝවන්|හලෝ|හායි|සුබ උදෑසනක්)(?![a-z])", re.I)  # not \b: "්" is not \w
THANKS = re.compile(r"(thank|thanks|thx|sthuthi|isthuthi|ස්තූතියි|ස්තුතියි|බොහොම ස්තූති)", re.I)
ABOUT = re.compile(r"(who are you|what can you do|what do you do|help me|ඔයා කවුද|ඔබ කවුද|"
                   r"මොනවද කරන්න පුළුවන්|ඔයාට මොනවද)", re.I)
NAMED = [  # disease named outright, used when symptom matching is unsure
    (re.compile(r"foot[- ]and[- ]mouth|\bfmd\b|මුඛ හා පාද", re.I), "Foot-and-Mouth Disease"),
    (re.compile(r"lumpy|\blsd\b|ගැටිති සමේ", re.I), "Lumpy Skin Disease"),
    (re.compile(r"mastitis|බුරුල්ලේ ප්‍?රදාහ|බුරුලු ප්‍?රදාහ|බුරුළු ප්‍?රදාහ", re.I), "Mastitis"),
    (re.compile(r"ringworm|dermatophyt|දිලීර|(?<!" + SI + r")දද", re.I), "Ringworm"),
    (re.compile(r"milk fever|කිරි උණ", re.I), care_kb.MF),
    (re.compile(r"tick fever|babesi|anaplasm|කිනිතුලු උණ", re.I), care_kb.TICK),
    (re.compile(r"foot ?rot|කුර කුණු", re.I), care_kb.FOOT),
    (re.compile(r"pink ?eye", re.I), care_kb.EYE),
    (re.compile(r"diarr?h|scour|පාචන", re.I), care_kb.DIA),
    (re.compile(r"\bbloat|බඩ පිපීම", re.I), care_kb.BLO),
    (re.compile(r"pneumonia|නියුමෝනියා", re.I), care_kb.PNE),
    (re.compile(r"\bworms?\b|deworm|පණුවන්", re.I), care_kb.WORM),
]


def disease_name(topic, lang):
    return DISEASE[lang].get(topic, topic)


def named_disease(question):
    for rx, topic in NAMED:
        if rx.search(question):
            return topic
    return None


def intents(question):
    return {"treat": bool(TREAT_Q.search(question)), "prevent": bool(PREVENT_Q.search(question))}


MILK_BLOOD = re.compile(r"milk.{0,20}blood|blood.{0,15}milk|bloody milk|කිරි.{0,6}ලේ|ලේ.{0,6}කිරි", re.I)
BODY_OPENING = re.compile(r"mouth|nose|nostril|anus|කට|නාස|ගුද", re.I)


def urgent_ids(question):
    ids = [i for rx, i in URGENT if rx.search(question)]
    # Blood in the milk is a mastitis sign, not bleeding from a body opening.
    if "KB-241" in ids and MILK_BLOOD.search(question) and not BODY_OPENING.search(question):
        ids.remove("KB-241")
    return ids


# Farmers may not know the English names the KB's Sinhala text uses.
SI_TERMS = [("Clinical mastitis හි", "පැහැදිලි ලක්ෂණ සහිත බුරුලු ප්‍රදාහයේ"),
            ("Subclinical mastitis හි", "ලක්ෂණ නොපෙනෙන බුරුලු ප්‍රදාහයේ"),
            ("Ringworm හි", "දදයේ"),
            ("Clinical mastitis","පැහැදිලි ලක්ෂණ සහිත බුරුලු ප්‍රදාහය"),
            ("Subclinical mastitis", "ලක්ෂණ නොපෙනෙන බුරුලු ප්‍රදාහය"),
            ("Mastitis", "බුරුලු ප්‍රදාහය"), ("Ringworm", "දද")]


def localize(text, lang):
    if lang == "si":
        for en, si in SI_TERMS:
            text = text.replace(en, si)
    return text


def small_talk(question, lang):
    """Reply to greetings / thanks / 'who are you' in short messages, else None."""
    if len(question.split()) > 7:
        return None
    for rx, key in ((THANKS, "thanks"), (ABOUT, "about"), (GREETING, "hello")):
        if rx.search(question):
            return TEXT[lang][key]
    return None


def is_sick_case(symptoms):
    return any(s in SIGN_WORDS for s in symptoms)




# ---------------------------------------------------------------------------
# Topic cards: a direct answer, then the same five sections for every disease.

# Original-KB facts that explain each disease ("about") and its signs, in the
# order a farmer would want them. Care entries (KB-2xx) join by their kind.
TOPIC_SETS = {
    "Foot-and-Mouth Disease": {
        "about": ["KB-001", "KB-002", "KB-003", "KB-005"],
        "signs": ["KB-006", "KB-007", "KB-008", "KB-201", "KB-202", "KB-203", "KB-204"]},
    "Lumpy Skin Disease": {
        "about": ["KB-028", "KB-029", "KB-030", "KB-213", "KB-053"],
        "signs": ["KB-031", "KB-211", "KB-032", "KB-033", "KB-212", "KB-034", "KB-035"]},
    "Mastitis": {
        "about": ["KB-055", "KB-056", "KB-057", "KB-058"],
        "signs": ["KB-059", "KB-060", "KB-061", "KB-062", "KB-228", "KB-221"]},
    "Ringworm": {
        "about": ["KB-085", "KB-086", "KB-089", "KB-100"],
        "signs": ["KB-087", "KB-088", "KB-090", "KB-091", "KB-231", "KB-092"]},
}
SECTION_KEYS = ["about", "signs", "treatment", "care", "prevention"]
TITLES = {
    "en": {"about": "About the disease", "signs": "Signs to look for",
           "treatment": "Treatment (by a vet)", "care": "Care at home",
           "prevention": "Prevention & recommendations",
           "answer": "Answer", "match": "What matches your description", "check": "Check first"},
    "si": {"about": "රෝගය ගැන", "signs": "බලන්න ඕන ලක්ෂණ",
           "treatment": "ප්\u200dරතිකාර (පශු වෛද්\u200dයවරයා මගින්)", "care": "නිවසේදී සත්කාර",
           "prevention": "වැළැක්වීම සහ නිර්දේශ",
           "answer": "පිළිතුර", "match": "ඔබ කියූ ලක්ෂණවලට ගැළපෙන දේ", "check": "මුලින්ම බලන්න"},
}
TEXT["en"]["info_open"] = "Good question! Here's a simple guide to {d}."
TEXT["si"]["info_open"] = "හොඳ ප්\u200dරශ්නයක්! {d} ගැන සරල මඟපෙන්වීමක්."


def section_entries(kb, topic, key):
    by_id = {e["id"]: e for e in kb}
    if key in ("about", "signs") and topic in TOPIC_SETS:
        return [by_id[i] for i in TOPIC_SETS[topic][key]]
    kind = {"signs": "sign"}.get(key, key)
    entries = [e for e in kb if e["topic"] == topic and e.get("kind") == kind]
    ids = {e["id"] for e in entries}
    return entries + [by_id[i] for i in EXTRA.get(topic, {}).get(key, []) if i not in ids]


def open_sections(sick, want, refusing=False, advice=False):
    """advice: a topic that is all practical tips (feeding), shown open."""
    if refusing:
        return {"treatment"}
    if sick:
        return {"treatment", "care", "prevention"}
    if want["treat"] or want["prevent"]:
        return ({"treatment", "care"} if want["treat"] else set()) | \
               ({"prevention"} if want["prevent"] else set())
    if advice:
        return {"about", "care", "prevention"}
    return {"about"}


def card(kb, lang, stage, *, topic, facts=(), sick=False, want=None, urgent=(),
         intro=None, skip=(), refusing=False):
    """Structured answer. Each entry appears once; returns (card, cited KB ids)."""
    want = want or {"treat": False, "prevent": False}
    by_id = {e["id"]: e for e in kb}
    used = set(skip)

    def rows(entries):
        out = []
        for e in entries:
            e = by_id[e] if isinstance(e, str) else e
            if e["id"] not in used:
                used.add(e["id"])
                out.append({"id": f"{e['id']}-{stage}", "text": localize(e[lang] or e["en"], lang)})
        return out

    t, titles = TEXT[lang], TITLES[lang]
    d = disease_name(topic, lang) if topic else None
    if intro is None:
        key = (("unclear" if urgent else "plain_open") if not topic else
               "general_open" if topic == care_kb.SICK else
               "sick_open" if sick else "treat_open" if want["treat"] else
               "prevent_open" if want["prevent"] else "info_open")
        intro = t[key].format(d=d)
    c = {"intro": intro, "urgent_title": t["urgent_head"].rstrip(":"), "urgent": rows(urgent),
         "answer_title": titles["check" if topic == care_kb.SICK else "match" if sick else "answer"],
         "answer": rows(facts),
         "sections": [],
         "closing": t["sick_close"] if (sick or urgent or want["treat"] or refusing) else t["info_close"]}
    if topic and topic != "General cattle health":
        opened = open_sections(sick or topic == care_kb.SICK, want, refusing,
                               advice=topic == care_kb.FEED)
        for key in SECTION_KEYS:
            items = rows(section_entries(kb, topic, key))
            if items:
                c["sections"].append({"key": key, "title": titles[key], "open": key in opened,
                                      "items": items})
    return c, sorted(used - set(skip))


def card_text(c):
    """Plain-text version (used for checks and the Short/terminal view)."""
    parts = []
    if c["urgent"]:
        parts.append(c["urgent_title"] + ":\n" + "\n".join(f"• {r['text']} [{r['id']}]" for r in c["urgent"]))
    if c["intro"]:
        parts.append(c["intro"])
    if c["answer"]:
        parts.append("\n".join(f"• {r['text']} [{r['id']}]" for r in c["answer"]))
    for s in c["sections"]:
        parts.append(s["title"] + ":\n" + "\n".join(f"• {r['text']} [{r['id']}]" for r in s["items"]))
    parts.append(c["closing"])
    return "\n\n".join(parts)


def refuse_card(kb, lang, stage, topic):
    return card(kb, lang, stage, topic=topic, intro=TEXT[lang]["refuse"], refusing=True)


def abstain(lang):
    return TEXT[lang]["abstain"]
