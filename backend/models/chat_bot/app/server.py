"""MedFarm-Llama demo UI server (Python stdlib only).

Rebuilds the 42-fact MedFarm KB from ../dataset.jsonl, retrieves evidence with
BM25, builds the exact llm_answer() prompt the adapter was trained on, and
streams the answer from Ollama (model: medfarm-llama).

Run:  python app/server.py   then open http://localhost:8001
(port 8001: the main FastAPI backend in backend/app uses 8000)
"""
import json
import math
import os
import re
import sys
import threading
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import care_kb
import friendly
import vets

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATASET = os.path.join(ROOT, "dataset.jsonl")
OLLAMA = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
MODEL = os.environ.get("MEDFARM_MODEL", "medfarm-llama")
PORT = int(os.environ.get("PORT", "8001"))
# 0.0.0.0 lets a phone on the same Wi-Fi reach the server (the emulator works with 127.0.0.1).
HOST = os.environ.get("MEDFARM_HOST", "127.0.0.1")

# Fixed sentences the model was trained to emit (from dataset.jsonl).
ABSTAIN = {
    "en": "The evidence provided does not answer this question, so I cannot answer it. "
          "Please ask a veterinarian or livestock extension officer.",
    "si": "ලබා දී ඇති සාක්ෂිවල මේ ප්‍රශ්නයට පිළිතුරක් නැති නිසා මට පිළිතුරු දිය නොහැක. "
          "කරුණාකර පශු වෛද්‍යවරයෙකුගෙන් හෝ ගොවි උපදේශකගෙන් විමසන්න.",
}
REFUSE = {
    "en": "I cannot give medicine names, doses or milk/meat withdrawal periods. "
          "Please consult a registered veterinarian.",
    "si": "ඖෂධ නම්, මාත්‍රා හෝ කිරි/මස් withdrawal කාල මට ලබා දිය නොහැක. "
          "කරුණාකර ලියාපදිංචි පශු වෛද්‍යවරයෙකුගෙන් විමසන්න.",
}
PROMPT_HEAD = (
    "You are MedFarm, a cattle-health assistant. Answer the farmer's question using ONLY the "
    "evidence below. Write 1-3 short sentences in {lang}. Put the evidence ID in square brackets "
    "after each fact, e.g. [KB-001-LM]. Do not add facts, medicine names, doses or withdrawal "
    "times that are not in the evidence. If the evidence does not answer the question, say so."
    "\n\nEvidence:\n{evidence}\n\nQuestion: {question}\nAnswer:"
)
# Llama 3 needs several tokens per Sinhala character; the Modelfile's 160 cut off
# 10/26 Sinhala answers in ollama_q4km_eval.csv before the [KB-ID].
NUM_PREDICT = {"en": 160, "si": 512}
# Same options for preload and requests, otherwise Ollama reloads the model.
MODEL_OPTIONS = {"temperature": 0.1, "num_ctx": 2048}
KEEP_ALIVE = "2h"

TOPIC_FIX = {  # facts whose English question never appears in the dataset
    "KB-002": "Foot-and-Mouth Disease", "KB-035": "Lumpy Skin Disease",
    "KB-053": "Lumpy Skin Disease", "KB-056": "Mastitis", "KB-058": "Mastitis",
    "KB-062": "Mastitis", "KB-092": "Ringworm", "KB-114": "General cattle health",
}
SINHALA = re.compile(r"[඀-෿]")
CITE = re.compile(r"\[(KB-\d{3}-(?:LM|HI))\]")
DOSE = re.compile(
    r"\b\d+(?:\.\d+)?\s*(?:mg|ml|mL|g|cc|iu|IU|units?|mg/kg|ml/kg)\b"
    r"|withdrawal\s+(?:period|time)\s+(?:of|is)\s+\d", re.I)
DOSE_Q = re.compile(
    r"\b(dose|dosage|how\s+many\s+ml|how\s+much\s+(medicine|drug)|medicines?|medication|tablets?|"
    r"inject|injection|antibiotic|"
    r"drug|ointment|withdrawal|throw\s+away\s+milk)\b|ml\b|බෙහෙත|ඖෂධ|එන්නත|ප්‍රතිජීවක|ආලේප|මාත්‍රා",
    re.I)
STOP = set("""a an the and or of in on at to for is are was were be been do does did i my me
my we our you your it its this that what which who how when where why should can could
would will about know tell with from by as if not so there their they them cow cows
cattle animal animals has have had get got its very all over near some much many any
she her hers he him his also too now again still really just then today yesterday""".split())


def normalise_topic(t):
    t = t.lower()
    for key, name in [("foot", "Foot-and-Mouth Disease"), ("lumpy", "Lumpy Skin Disease"),
                      ("mastitis", "Mastitis"), ("ringworm", "Ringworm")]:
        if key in t:
            return name
    return "General cattle health"


def load_kb():
    facts = defaultdict(lambda: {"en": None, "si": None, "topic": None, "aspect": None})
    for line in open(DATASET, encoding="utf-8"):
        row = json.loads(line)
        evidence = row["prompt"].split("Evidence:\n", 1)[1].split("\n\nQuestion:")[0]
        for ev in evidence.split("\n"):
            m = re.match(r"\[(KB-\d{3})-(?:LM|HI)\] (.*)", ev)
            if m:  # LM and HI variants share the same text
                facts[m.group(1)][row["lang"]] = m.group(2)
        m = re.match(r"What should I know about (.*) in (.*)\? \(", row["question"])
        if m and row["kind"] == "answer":
            facts[row["fact"]]["topic"] = normalise_topic(m.group(2))
            facts[row["fact"]]["aspect"] = m.group(1)
    kb = []
    for fid in sorted(facts):
        f = facts[fid]
        kb.append({"id": fid, "en": f["en"], "si": f["si"],
                   "topic": f["topic"] or TOPIC_FIX.get(fid, "General cattle health"),
                   "aspect": f["aspect"] or "", "kind": "fact", "sources": []})
    return kb + care_kb.entries()


# Farmer wording -> KB wording (both languages). Matched as substrings so
# Sinhala inflections ("කුරවල", "තුවාලයක්") still hit. The third item lists the
# topics a sign points to; signs with none (fever, not eating ...) fit many
# illnesses and never name a disease on their own.
FMD, LSD, MAS, RW = care_kb.FMD, care_kb.LSD, care_kb.MAS, care_kb.RW
SYMPTOMS = [
    # --- feet / mouth (FMD, foot rot) ---
    (r"wound|sore|ulcer|තුවාල|වණ|කැපුම", "blisters lesions ulcers බිබිලි තුවාල",
     (FMD, LSD, care_kb.FOOT)),
    (r"hoof|hooves|claw|feet|limp|lame|කුර|කකුල|පාදවල|කොර|ඇවිද", "hooves claws feet lameness කුර පාදවල කොර",
     (FMD, care_kb.FOOT)),
    (r"lying down|lie down|lies down|stamp|වැතිරී|වැතිරිල|පාද ගස", "lameness lie down stamp වැතිරී", ()),
    (r"blister|vesicle|bubble|බිබිලි|බුබුළු", "blisters vesicles බිබිලි", (FMD,)),
    (r"mouth|tongue|\blips?\b|drool|saliva|slobber|කටේ|කටින්|කටෙන්|කට ඇතුළ|මුඛය|දිව|තොල්|කෙළ|කෙල",
     "mouth tongue lips drool බිබිලි මුඛය දිව කෙළ", (FMD,)),
    (r"foul|stink|rotten|(smell|odou?r).{0,30}(foot|feet|hoof|claw)|between the (claws|toes)|"
     r"split.{0,20}(claw|hoof|skin)|කුර.{0,20}(ගඳ|කුණු|පැලී)|දුගඳ",
     "foul-smelling claws splits foot rot දුගඳ කුර", (care_kb.FOOT,)),
    # --- skin lumps (LSD) ---
    (r"lump|bump|nodule|knot|ගැටිති|ගැට|ගෙඩි|කුරුලෑ", "nodules lumpy skin ගැටිති සමේ", (LSD,)),
    (r"fever|hot body|temperature|උණ|රස්නෙ", "fever උණ", ()),
    (r"\btears?\b|watery eye|කඳුළු", "tears watery eyes කඳුළු ඇස්වලින්", (LSD, care_kb.EYE)),
    # Discharge, not just "nose": "blood from the nose" is an emergency, not this sign.
    (r"nasal|snot|runny nose|nose.{0,15}(discharge|running|runs|mucus|dripping)|discharge.{0,15}nose|"
     r"නාසයෙන් (දියර|සෙම)|සෙම", "nasal discharge නාසයෙන් දියර", (LSD, care_kb.PNE)),
    (r"cloudy eye|eye.{0,20}(cloudy|white|blue|closed|shut)|(white|blue) (spot|patch) on.{0,12}eye|"
     r"pink ?eye|squint|ඇස.{0,15}(සුදු|බොඳ|වහ)", "cloudy eye shut pinkeye බොඳ ඇස", (care_kb.EYE,)),
    # --- udder / milk (Mastitis) ---
    (r"udder|teat|quarter|බුරුල්ල|බුරුල|බුරුලු|තනය|තනයක්|තනේ|තනවල|තන පුඩු|තන ඉදි|තන තද|තන රතු|"
     r"(?<![඀-෿])තන(?![඀-෿])", "udder quarter බුරුල්ලේ කොටස", (MAS,)),
    (r"clot|flake|කිරි කැටි|කැටි|තුණ්ඩ", "milk clots flakes කිරි කැටි", (MAS,)),
    (r"watery milk|thin milk|milk.{0,12}water|කිරි වතුර|වතුර වගේ|වතුර වැනි|දියර වගේ",
     "watery secretion milk appearance වතුර වැනි දියර කිරි පෙනුමේ", (MAS,)),
    (r"blood in (the )?milk|bloody milk|milk.{0,20}blood|කිරිවල ලේ|කිරි වල ලේ|කිරියේ ලේ|ලේ පාට කිරි|"
     r"ලේ මිශ්‍?ර කිරි", "milk appearance changes කිරි පෙනුමේ වෙනස්කම්", (MAS,)),
    (r"milk colou?r|colou?r of (the )?milk|milk.{0,20}smell|smell.{0,20}milk|කිරි පාට|කිරිවල පාට|කිරි ගඳ|"
     r"කිරිවල ගඳ", "milk appearance changes කිරි පෙනුමේ වෙනස්කම්", (MAS,)),
    (r"less milk|milk (drop|yield|reduc|less|production)|(increase|more|boost).{0,15}milk|කිරි අඩු|කිරි වැඩි",
     "yield milk less milk කිරි අඩුවෙන් ප්‍රමාණය", (care_kb.FEED,)),
    (r"swell|swollen|\bhard\b|ඉදිම|ඉදිමු|තද වෙලා|තද වුණා|තදයි|ගල් වගේ", "swelling ඉදිමීම", ()),
    (r"pain|hurt|tender|රිදෙනව|රිදුම|වේදනා|අල්ලනකොට|අල්ලද්දි|ඇල්ලුවම", "painful hot වේදනාකාරී උණුසුම්", ()),
    (r"\bhot\b|warm|උණුසුම්|රස්නෙයි|රස්නෙ වෙලා|රස්නය", "painful hot වේදනාකාරී උණුසුම්", ()),
    (r"\bred\b|redness|රතු", "redness රතු වීම", ()),
    # --- skin patches (Ringworm) ---
    (r"hair loss|bald|hairless|patch|round|crust|scab|scal|flak|ලොම්|රෝම|පොතු|කොරපොතු|රවුම්|රවුමට|මුඩු|ගැලව|"
     r"පැල්ලම|ලප", "hair loss crusts patches රෝම ගැලවුණු පොතු පැල්ලම්", (RW,)),
    (r"white|gr[ae]y|සුදු|අළු|අලු(?!ත)", "gray-white crusts අළු-සුදු පැහැති පොතු", (RW,)),  # not "අලුත" (new)
    (r"itch|scratch|කැසීම|කසනව|කහනව|කසන", "itching කැසීම", ()),
    (r"\beyes?\b|\bface\b|ඇස්|ඇහැ|මූණ|මුහුණ|ඇස් වට", "eyes ඇස් වටා", ()),
    (r"\bcalf|calves|වස්ස|පැටි|පැටව", "calves young කුඩා පැටවුන්", ()),
    (r"chest|පපුව", "chest පපුවේ", ()),
    # --- gut, breathing, blood (common farm problems) ---
    (r"diarr?h|scour|loose (dung|stool|motion)|(watery|runny) (dung|stool|faeces|feces|poo)|පාචන|බඩ යනව|"
     r"බඩ යාම|ගොම දියර|දියර ගොම", "diarrhoea scours dung පාචනය ගොම", (care_kb.DIA, care_kb.WORM)),
    (r"bloat|(left|stomach|belly|abdomen|rumen).{0,25}(swol|swell|bigger|tight|distend|blown)|"
     r"(swol|swell|blown).{0,25}(left side|stomach|belly|abdomen)|බඩ පිම්බ|බඩ පිපිල|බඩ ඉදිම|බඩ පිපී",
     "bloat left belly rumen gas බඩ පිපීම", (care_kb.BLO,)),
    (r"cough|pneumonia|breath|pant|wheez|sneez|කැස්ස|කහිනව|කැස්සක්|හුස්ම|හති",
     "cough pneumonia breathing කැස්ස නියුමෝනියාව හුස්ම", (care_kb.PNE,)),
    (r"(red|dark|brown|bloody|coffee).{0,15}(urine|pee)|(urine|pee).{0,20}(red|dark|brown|blood)|"
     r"මුත්‍?රා.{0,15}(රතු|කළු|දුඹුරු|ලේ)", "urine red dark-brown tick fever මුත්‍රා", (care_kb.TICK,)),
    (r"\bpale\b|yellow (gums|eyes)|jaundice|ana?emi|සුදුමැලි", "pale gums yellow anaemia සුදුමැලි",
     (care_kb.TICK, care_kb.WORM)),
    (r"\bthin\b(?!\s+milk)|weight loss|losing weight|lost weight|skinny|not growing|poor growth|rough coat|"
     r"bottle jaw|කෙට්ටු|බර අඩු|වැඩෙන්නේ නැ", "weight loss poor growth rough coat බර අඩුවීම",
     (care_kb.WORM,)),
    (r"(after|since) (calving|giving birth|delivery).{0,60}(down|stand|get up|weak)|"
     r"(down|stand|get up|weak).{0,60}after (calving|giving birth|delivery)|milk fever|"
     r"පැටවා.{0,40}(නැගිටින්න බැ|වැටිල|නැගිටින්නේ නැ)|කිරි උණ",
     "calving cannot get up milk fever calcium කිරි උණ", (care_kb.MF,)),
    # --- questions about rather than signs ---
    (r"\bticks?\b|කිනිතුල්", "ticks tick fever කිනිතුල්ලන්", (care_kb.TICK,)),
    (r"\bworms?\b|parasit|deworm|පණුව|පනුව", "worms parasites dewormer පණුවන්", (care_kb.WORM,)),
    # Drinking water only: "watery milk" / "කිරි වතුර වගේ" is a mastitis sign.
    (r"\bfeed|\bfood|\bdiet|fodder|grass|drinking water|(how much|enough|give|clean) water|ආහාර|කෑම|තෘණ|"
     r"බොන වතුර|වතුර බොන|වතුර දෙන", "feed roughage water ආහාර තෘණ වතුර",
     (care_kb.FEED,)),
    (r"\bhumans?\b|people|person|family|children|catch|\bget\b.*\bfrom\b|spread to|zoonotic|"
     r"මිනිස්|ළමයි|පවුලේ|මටත්|බෝවෙනවද|බෝවේද|බෝවන|බෝවෙයිද", "humans people spread contact මිනිසුන්ට", ()),
    (r"\bbody\b|all over|ඇඟ|ශරීර|සිරුර", "body සිරුරේ", ()),
    (r"not eating|off feed|appetite|won'?t eat|eat(s|ing)? less|stopped eating|කන්නේ නැ|කෑම අඩු|"
     r"කන්න අකමැති|අරුචි", "appetite eat less ආහාර අරුචිය අඩුවෙන් කන්නත්", ()),
    (r"weak|dull|lethargic|තෙහෙට්ටු|දුර්වල|අලස", "weakness dullness දුර්වලතාවය", ()),
    (r"\bfl(y|ies)\b|mosquito|මැස්ස|මදුරු", "flies mosquitoes මැස්සන් මදුරුවන්", (LSD, care_kb.EYE)),
]
SYMPTOM_RE = [(re.compile(p, re.I), exp, topics) for p, exp, topics in SYMPTOMS]
# Bilingual topic names, so "මුඛ හා පාද රෝගය" counts as matched by any FMD fact.
TOPIC_ALIASES = {
    FMD: "foot mouth fmd මුඛ පාද රෝගය",
    LSD: "lumpy skin lsd ගැටිති රෝගය",
    MAS: "mastitis udder බුරුල්ලේ බුරුළු බුරුලු ප්‍රදාහය රෝගය",
    RW: "ringworm dermatophytosis fungal දද දිලීර සමේ රෝගය",
    "General cattle health": "health hygiene biosecurity සෞඛ්‍යය සෞඛ්‍ය",
    care_kb.DIA: "diarrhoea diarrhea scours පාචනය බඩ යාම",
    care_kb.BLO: "bloat බඩ පිපීම",
    care_kb.PNE: "pneumonia respiratory cough කැස්ස නියුමෝනියාව ශ්වසන",
    care_kb.TICK: "ticks tick fever babesiosis anaplasmosis කිනිතුල්ලන් කිනිතුලු උණ",
    care_kb.WORM: "worms parasites deworming පණුවන් පණු",
    care_kb.EYE: "pinkeye eye infection ඇසේ ආසාදනය",
    care_kb.FOOT: "foot rot hoof කුර කුණුවීම",
    care_kb.MF: "milk fever calcium calving කිරි උණ",
    care_kb.FEED: "feeding feed food diet nutrition milk yield ආහාර කිරි",
    care_kb.SICK: "sick ill fever not eating අසනීප රෝගී",
}
# Topic names contain symptom words ("foot-and-MOUTH"); hide them from SYMPTOMS.
DISEASE_NAMES = re.compile(r"foot[- ]and[- ]mouth|මුඛ හා පාද|lumpy skin|ring ?worm|milk fever|කිරි උණ|"
                           r"pink ?eye|foot ?rot|tick fever", re.I)
STAGE_SUFFIX = re.compile(r"\((?:low.moderate|high) stage\)", re.I)
# Sinhala words for "my / cow / how / what / is there" etc.
SI_STOP_PREFIX = ("හරක", "ගවය", "ගවයෙ", "එළදෙන", "මගේ", "මගෙ", "මම", "මට", "කොහොම", "මොක",
                  "ඇයි", "කොච්චර", "ඕන", "තියෙන", "තියෙනව", "ගැන", "කියන්න", "කුමක", "වන්නේ",
                  "හේතුව", "දැනගන්න", "කරන්නේ", "කරන්න", "පුළුවන්", "හැකිද", "එකක්", "දෙයක්",
                  "පුරා", "සහිත", "වල")
# Everyday Sinhala filler words ("වෙලා", "එනවා", "වගේ" ...): not symptoms themselves.
SI_STOP = {"වෙලා", "වුණා", "වෙනවා", "එනවා", "යනවා", "වගේ", "නැති", "නෑ", "නැහැ", "ඇති",
           "කරලා", "දෙනවා", "ගහනවා", "හරි", "ගොඩක්", "ටිකක්", "දැන්", "වටේ", "වටා", "පාට",
           "වෙලාද", "එනවද", "යනවද", "තමයි", "ඔක්කොම", "තැන්", "තැනක", "ඉඳන්", "වලින්",
           "මොනවද", "මොනවා", "කන්න", "දෙන්න", "ඉන්නවා", "ඉන්නව", "ඉන්නේ", "ඉන්න"}
TOKEN_RE = re.compile(r"[a-z0-9]+|[඀-෿‍]+")


def clean_question(question):
    return STAGE_SUFFIX.sub(" ", question)


def hide_disease_names(question):
    """Blank out disease names (same length, so match offsets stay valid)."""
    return DISEASE_NAMES.sub(lambda m: " " * len(m.group()), question)


def symptom_terms(question):
    """(KB wording, topics the sign points to) for each sign in the question."""
    q = hide_disease_names(question)
    return [(exp, topics) for rx, exp, topics in SYMPTOM_RE if rx.search(q)]


def _keep(t):
    return t not in STOP and t not in SI_STOP and len(t) > 1 and not t.startswith(SI_STOP_PREFIX)


def token_spans(text):
    """(token, start, end) for each kept token; offsets refer to text.lower()."""
    out = []
    for m in TOKEN_RE.finditer(text.lower()):
        t = m.group().replace("‍", "")
        if _keep(t):
            out.append((t, m.start(), m.end()))
    return out


def tokenize(text):
    return [t for t, _, _ in token_spans(text)]


def ngrams(tokens, n=3):
    """Character n-grams per word: lets 'කුරවල' match 'කුර', 'hooves' match 'hoof'."""
    out = []
    for t in tokens:
        out += [t] if len(t) <= n else [t[i:i + n] for i in range(len(t) - n + 1)]
    return out


class BM25:
    def __init__(self, docs, k1=1.4, b=0.75):
        self.docs = [Counter(d) for d in docs]
        self.lens = [len(d) for d in docs]
        self.avg = sum(self.lens) / len(self.lens)
        df = Counter(t for d in self.docs for t in d)
        n = len(docs)
        self.idf = {t: math.log(1 + (n - c + 0.5) / (c + 0.5)) for t, c in df.items()}
        self.k1, self.b = k1, b

    def scores(self, query):
        out = []
        for d, ln in zip(self.docs, self.lens):
            s = 0.0
            for t in query:
                if t in d:
                    tf = d[t]
                    s += self.idf[t] * tf * (self.k1 + 1) / (tf + self.k1 * (1 - self.b + self.b * ln / self.avg))
            out.append(s)
        return out


KB = load_kb()
KB_BY_ID = {f["id"]: f for f in KB}
# Index English + Sinhala + topic together so mixed-language questions
# ("Mastitis වලට ...") still match.
_DOCS = [tokenize(" ".join(filter(None, [f["en"], f["si"], f["topic"], f["aspect"],
                                           TOPIC_ALIASES.get(f["topic"], "")]))) for f in KB]
_DOC_GRAMS = [set(ngrams(d)) for d in _DOCS]
# Fact text only (no topic aliases), for checking a fact really answers a question.
_DOC_WORD_LISTS = [tokenize(" ".join(filter(None, [f["en"], f["si"]]))) for f in KB]
_DOC_WORD_SETS = [set(words) for words in _DOC_WORD_LISTS]
WORD_INDEX = BM25(_DOCS)
GRAM_INDEX = BM25([ngrams(d) for d in _DOCS])
GRAM_WEIGHT = 0.3     # partial-word matches
EXPAND_WEIGHT = 0.5   # symptom-dictionary terms count half of the farmer's own words
MIN_COVERAGE = 0.6    # share of question words the top fact must explain
COVER_FACTS = 4       # top-ranked facts (same disease as the best) used for coverage
MIN_DISEASE_SHARE = 0.35  # below this the signs fit several diseases: don't name one
# Words that only name a disease say nothing about what the farmer wants to know
# (multi-word names are already blanked by DISEASE_NAMES).
TOPIC_WORDS = set(tokenize(
    "fmd lsd mastitis diarrhoea diarrhea scours bloat pneumonia babesiosis anaplasmosis "
    "disease diseases illness infection rot calf calves animal animals "
    "පාචනය බුරුලු ප්‍රදාහය රෝගය රෝග දද "
    # everyday verbs that say nothing about the subject
    "keep make give take use need want help happen happens"))


def _score(tokens):
    w, g = WORD_INDEX.scores(tokens), GRAM_INDEX.scores(ngrams(tokens))
    return [a + GRAM_WEIGHT * b for a, b in zip(w, g)]


def _covered(token, i):
    grams = ngrams([token])
    return sum(g in _DOC_GRAMS[i] for g in grams) / len(grams) >= 0.5


def retrieve(question, k=3):
    q = clean_question(question)
    spans = token_spans(q)
    q_tokens = [t for t, _, _ in spans]
    signs = symptom_terms(q)
    expansions = [exp for exp, _ in signs]
    base = _score(q_tokens)
    extra = _score(tokenize(" ".join(expansions))) if expansions else [0.0] * len(KB)
    scores = [a + EXPAND_WEIGHT * b for a, b in zip(base, extra)]
    ranked = sorted(range(len(KB)), key=lambda i: -scores[i])
    top = ranked[0]
    # Farmers list several signs that live in different facts of one disease, so
    # the best fact plus the next best facts of the same disease explain the question.
    cover = [top] + [i for i in ranked[1:COVER_FACTS] if KB[i]["topic"] == KB[top]["topic"]]

    def explains(token):
        return any(_covered(token, i) for i in cover)

    # A word counts as explained if those facts contain it, or it sits inside a
    # symptom phrase ("කිරි පාට", "කුරවල") whose KB wording they contain.
    hidden = hide_disease_names(q).lower()
    explained = []
    for rx, exp, _ in SYMPTOM_RE:
        if any(explains(e) for e in tokenize(exp)):
            explained += [(m.start(), m.end()) for m in rx.finditer(hidden)]
    covered = sum(1 for t, s, e in spans
                  if explains(t) or any(s < me and ms < e for ms, me in explained))
    coverage = covered / len(spans) if spans else 0.0
    return {
        "evidence": [(KB[i], round(scores[i], 2)) for i in ranked[:k]],
        "scores": scores,
        "coverage": round(coverage, 2),
        "confident": coverage >= MIN_COVERAGE and scores[top] > 0,
        "symptoms": [e.split()[0] for e in expansions],
        # Topics that at least one described sign points to.
        "sign_topics": {t for _, topics in signs for t in topics},
        # Question words other than topic names: what the farmer wants to know
        # ("own": the farmer's words; "content": plus their KB wording).
        "own": {t for t in tokenize(hide_disease_names(q)) if t not in TOPIC_WORDS},
        "content": {t for t in tokenize(" ".join([hide_disease_names(q)] + expansions))
                    if t not in TOPIC_WORDS},
    }


def _common_prefix(a, b):
    n = 0
    for x, y in zip(a, b):
        if x != y:
            break
        n += 1
    return n


def _word_in(token, words):
    """Same word with another ending: "sell" ~ "selling", "කිනිතුල්ලෝ" ~ "කිනිතුල්ලන්",
    but not "contact" ~ "contagious"."""
    return any(abs(len(w) - len(token)) <= 4
               and _common_prefix(w, token) >= max(3, min(len(w), len(token)) - 1)
               for w in words)


def answer_match(fact, content):
    """How many of the question's words the fact contains. "How long does LSD
    last" shares none with the LSD virus-family fact, so that fact is no answer."""
    words = _DOC_WORD_SETS[KB.index(fact)]
    return sum(_word_in(t, words) for t in content)


def answer_rank(fact, found):
    """Sort key for the fact that best answers an info question: the farmer's own
    words first (how many, then how often: "how much water" -> the fact about
    water), then their KB wording."""
    words = _DOC_WORD_LISTS[KB.index(fact)]
    own_hits = [sum(_word_in(t, [w]) for w in words) for t in found["own"]]
    return (sum(h > 0 for h in own_hits), sum(own_hits), answer_match(fact, found["content"]))


def diagnose(scores):
    """Rank diseases by their two best-matching facts. Not a diagnosis."""
    by_topic = defaultdict(list)
    for f, s in zip(KB, scores):
        by_topic[f["topic"]].append(s)
    ranked = sorted(((sum(sorted(v)[-2:]), t) for t, v in by_topic.items()), reverse=True)
    total = sum(s for s, _ in ranked) or 1
    return [{"disease": t, "share": round(s / total, 2), "score": round(s, 1)} for s, t in ranked[:3] if s > 0]


TOPICS = {f["topic"] for f in KB} - {"General cattle health"}


def previous_turn(history):
    """The latest earlier turn of this chat that was answered on a topic.
    history: [{"question": str, "topic": str | None, "sick": bool}, ...], oldest first."""
    for turn in reversed((history if isinstance(history, list) else [])[-4:]):
        if (isinstance(turn, dict) and turn.get("topic") in TOPICS
                and isinstance(turn.get("question"), str)):
            return turn
    return None


def has_own_topic(found):
    """Whether the question alone gets an answer: general hygiene, or a clear topic."""
    if not found["confident"]:
        return False
    topics = [d for d in diagnose(found["scores"])
              if d["disease"] not in ("General cattle health", care_kb.EM)]
    return (found["evidence"][0][0]["topic"] == "General cattle health"
            or bool(topics and topics[0]["share"] >= MIN_DISEASE_SHARE))


def followup_kind(question, found, last, lang):
    """How a question builds on the previous turn:
    "signs" - more signs of the same sick cow ("she also has a fever"),
    "topic" - a question about the previous topic ("how do I treat it?"),
    None    - it stands on its own (names a disease or describes specific signs)."""
    if (not last or friendly.small_talk(question, lang) or friendly.named_disease(question)
            or found["sign_topics"]):
        return None
    if friendly.is_sick_case(found["symptoms"]) and last.get("sick"):
        return "signs"
    want = friendly.intents(question)
    if friendly.refers_back(question) or want["treat"] or want["prevent"] or want["signs"]:
        return "topic"
    if not has_own_topic(found):
        # "Is the milk safe to drink?" after a mastitis answer: keep the earlier
        # topic only if one of its facts contains most of the question's words.
        trial = retrieve(f"{question} ({last['topic']})", 10)
        words = trial["content"]
        if words and any(answer_match(f, words) >= 0.6 * len(words)
                         for f, _ in trial["evidence"] if f["topic"] == last["topic"]):
            return "topic"
    return None


def detect_lang(text):
    return "si" if SINHALA.search(text) else "en"


def build_prompt(question, lang, evidence, stage):
    lines = "\n".join(f"[{f['id']}-{stage}] {f[lang] or f['en']}" for f, _ in evidence)
    return PROMPT_HEAD.format(lang="Sinhala" if lang == "si" else "English",
                              evidence=lines, question=question)


def check_output(text, lang, evidence_ids, behaviour=None):
    """Same checks as the held-out eval (heldout_eval.csv columns)."""
    cites = CITE.findall(text)
    plain = text.replace("‍", "")
    if behaviour:
        pass  # known from the path that produced the text
    elif ABSTAIN[lang].replace("‍", "")[:40] in plain or "does not answer" in plain:
        behaviour = "abstain"
    elif REFUSE[lang].replace("‍", "")[:30] in plain or "cannot give medicine" in plain:
        behaviour = "refuse"
    else:
        behaviour = "answer"
    has_si = bool(SINHALA.search(text))
    return {
        "behaviour": behaviour,
        "cited": cites,
        "valid_cites": [c for c in cites if c in evidence_ids],
        "invented_cites": [c for c in cites if c not in evidence_ids],
        "lang_ok": has_si if lang == "si" else not has_si,
        "dose_leak": bool(DOSE.search(text)),
    }


def ollama_get(path, timeout=3):
    with urllib.request.urlopen(OLLAMA + path, timeout=timeout) as r:
        return json.loads(r.read())


def status():
    try:
        tags = ollama_get("/api/tags")
    except Exception:
        return {"ollama": False, "model": False, "name": MODEL}
    names = [m["name"] for m in tags.get("models", [])]
    return {"ollama": True, "model": any(n.split(":")[0] == MODEL for n in names), "name": MODEL}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        sys.stderr.write("[medfarm] " + fmt % args + "\n")

    def end_headers(self):
        # The Flutter web app (flutter run -d chrome) is served from another origin.
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def send_json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            body = open(os.path.join(HERE, "index.html"), "rb").read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/api/status":
            self.send_json(status())
        elif self.path == "/api/kb":
            self.send_json(KB)
        else:
            self.send_json({"error": "not found"}, 404)

    def do_POST(self):
        if self.path != "/api/ask":
            return self.send_json({"error": "not found"}, 404)
        req = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        question = (req.get("question") or "").strip()
        if not question:
            return self.send_json({"error": "empty question"}, 400)
        stage = "HI" if req.get("stage") == "HI" else "LM"
        lang = req.get("lang") if req.get("lang") in ("en", "si") else detect_lang(question)
        k = max(1, min(5, int(req.get("k", 3))))
        use_model = req.get("mode") == "model"

        if use_model and lang == "si":
            k = min(k, 2)  # Sinhala costs ~4x the tokens per fact on CPU
        found = retrieve(question, 10)
        # Follow-ups lean on the latest topic of this chat (sent by the client).
        last = previous_turn(req.get("history"))
        follow = followup_kind(question, found, last, lang)
        ask = question  # the question as understood, with its chat context
        if follow == "signs":
            ask = f"{last['question']}. {question}"
        elif follow == "topic":
            ask = f"{question} ({last['topic']})"
        if follow:
            found = retrieve(ask, 10)
        ranked = found["evidence"]
        if found["confident"]:
            # Only facts about the matched disease, so the model cannot drift to a
            # fact from another disease that shares a word (e.g. "තුවාල" in LSD).
            same = [e for e in ranked if e[0]["topic"] == ranked[0][0]["topic"]]
            ranked = same + [e for e in ranked if e not in same]
        evidence = ranked[:k]
        ev_ids = [f"{f['id']}-{stage}" for f, _ in evidence]
        prompt = build_prompt(ask, lang, evidence, stage)
        topics = diagnose(found["scores"]) if found["confident"] else []
        topics = [d for d in topics if d["disease"] not in ("General cattle health", care_kb.EM)]
        friendly_style = req.get("style", "friendly") == "friendly"
        # Short greetings win even if a word looks medical ("ආයුබෝවන්" contains "බෝවන").
        chat = (friendly.small_talk(question, lang)
                if friendly_style and not follow
                and (not found["confident"] or len(question.split()) <= 3)
                else None)
        if chat:
            found["confident"], topics = False, []
        want = friendly.intents(question)
        urgent = friendly.urgent_ids(question) if friendly_style and not chat else []
        # Finding a vet. The town comes from this message or an earlier one in the chat.
        history = req.get("history") if isinstance(req.get("history"), list) else []
        here = vets.find_office(question) or next(
            (o for h in reversed(history[-6:]) if isinstance(h, dict)
             for o in [vets.find_office(str(h.get("question") or ""))] if o), None)
        # The previous answer asked "where are you?", so this message is the reply.
        asked_where = bool(history) and isinstance(history[-1], dict) \
            and history[-1].get("topic") == vets.TOPIC
        # Health questions ("my cow in Buttala has blisters") get the health answer,
        # with the vet's contact added below.
        vet_turn = (friendly_style and not chat and not urgent and not found["sign_topics"]
                    and not friendly.named_disease(question)
                    and (vets.wants_vet(question) or vets.only_place(question) or asked_where))
        # Name a topic only on a clear match (or when the farmer names it).
        named = None if chat else friendly.named_disease(ask)
        if follow == "topic":
            named, topics = last["topic"], []  # "how do I treat it?": the earlier topic
        owned = (named is not None and not (want["treat"] or want["prevent"])
                 and not friendly.is_sick_case(found["symptoms"])
                 and friendly.about_my_animal(question))
        if owned:
            want["treat"] = True  # "my cow has mastitis": how it is treated and cared for
        sign_topics = found["sign_topics"]
        top = topics[0]["disease"] if topics else None
        if top and (topics[0]["share"] >= MIN_DISEASE_SHARE or top in (named,) or top in sign_topics):
            topic = top
        else:
            topic = named
        # "How do I treat bloat?" asks about a disease; it does not describe a sick cow.
        asks_how = named is not None and (want["treat"] or want["prevent"])
        # A follow-up about the topic ("what are the signs of it?") is not a new
        # report of a sick cow, even though the topic name ("pneumonia") is a sign.
        sick = (friendly.is_sick_case(found["symptoms"]) and found["confident"]
                and not chat and not asks_how and follow != "topic")
        if sick and (named is None or topic != named) and topic not in sign_topics:
            # Fever, not eating, weakness ... fit many illnesses: name a disease only
            # when a described sign points to it, else give general sick-cow advice.
            match = next((d for d in topics if d["disease"] in sign_topics), None)
            topic = match["disease"] if match else care_kb.SICK
        if urgent and (topic is None or topic != named) and topic not in sign_topics:
            # A warning sign without signs of a known disease: never a guide to a
            # disease that merely shares words ("cannot stand" is in a diarrhoea
            # fact). Bleeding or sudden death get the emergency guide (what to do
            # until the vet comes), other warnings the general sick-cow advice.
            topic = care_kb.EM if {"KB-241", "KB-242"} & set(urgent) else care_kb.SICK
        # "Signs match ..." only for a sick animal, with the chosen disease first.
        diseases = []
        if sick and topic not in care_kb.NOT_DISEASES:
            diseases = sorted((d for d in topics if d["disease"] not in care_kb.NOT_DISEASES),
                              key=lambda d: d["disease"] != topic)
        # Direct-answer facts come from the chosen topic (or general health if none).
        fact_topic = topic or "General cattle health"
        pool = [e for e in found["evidence"] if e[0]["topic"] == fact_topic]
        if sick:
            signs = [e for e in pool if e[0]["kind"] in ("fact", "sign")]
            facts = extractive_facts(signs) if signs else []
        elif topic in (care_kb.EM, care_kb.SICK) or (topic and (want["treat"] or want["prevent"]
                                                                 or want["signs"])):
            facts = []  # the opened sections are the answer
        else:
            # Info questions: the entry sharing the most words with the question;
            # ties go to what the topic is (about / facts / signs), then retrieval
            # order. None if it shares no words.
            basic = {"about": 2, "fact": 2, "sign": 1}
            matches = [(answer_rank(f, found), basic.get(f["kind"], 0), -n, f)
                       for n, (f, _) in enumerate(pool) if f["kind"] != "urgent"]
            best = max(matches, key=lambda m: m[:3], default=None)
            facts = [best[-1]] if best and best[0][2] > 0 else []
        guarded = req.get("guard", True) and bool(DOSE_Q.search(question))
        # A named disease ("හරකාගේ ඇඟේ දද") always gets its topic guide.
        has_answer = bool((found["confident"] and (topic or facts)) or urgent or named)

        # Friendly answers are topic cards; their extra KB entries join the evidence list.
        card = None
        if vet_turn:
            t = friendly.VET_TEXT[lang]
            if here:
                card = friendly.vet_card(lang, [vets.contact(here, lang)],
                                         t["found"].format(area=here["area"][lang]), t["close"])
                topic = None
            elif asked_where:  # a town we have no office for
                card = friendly.vet_card(lang, vets.all_contacts(lang), t["unknown"], t["close"])
                topic = None
            elif vets.is_urgent(question):  # no time to ask the town first
                card = friendly.vet_card(lang, vets.all_contacts(lang), t["urgent"], t["close"])
                topic = vets.TOPIC  # a town in the next message narrows it to one office
            else:
                card = friendly.vet_card(lang, [], t["ask"])
                topic = vets.TOPIC  # the next message answers "where are you?"
            card_ids, sick, diseases, guarded = [], False, [], False
        elif friendly_style and guarded:
            card, card_ids = friendly.refuse_card(KB, lang, stage, topic)
        elif friendly_style and not chat and has_answer:
            card, card_ids = friendly.card(KB, lang, stage, topic=topic, facts=facts, sick=sick,
                                           want=want, urgent=urgent, owned=owned)
        if card and not vet_turn:
            # The vet to call: the farmer's town if known; every office for an emergency.
            if here and topic not in (None, care_kb.FEED, "General cattle health"):
                friendly.add_contacts(card, lang, [vets.contact(here, lang)])
            elif urgent or topic == care_kb.EM:
                friendly.add_contacts(card, lang, vets.all_contacts(lang))
        # Next questions to tap; greetings and "I don't know" offer starter questions.
        if vet_turn:
            suggest = vets.town_names(lang) if topic == vets.TOPIC else []
        else:
            suggest = (friendly.suggestions(topic if card else None, lang, card, want, question)
                       if friendly_style else [])
        shown = {f["id"] for f, _ in evidence}
        extra = [KB_BY_ID[i] for i in (card_ids if card else []) if i not in shown]
        ev_ids += [f"{f['id']}-{stage}" for f in extra]

        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

        def emit(obj):
            self.wfile.write((json.dumps(obj, ensure_ascii=False) + "\n").encode())
            self.wfile.flush()

        def finish(text, how, behaviour=None, card=None):
            emit({"type": "token", "text": text})
            emit({"type": "done", "source": how, "card": card,
                  "checks": check_output(text, lang, ev_ids, behaviour)})

        def ev_row(f, score):
            return {"id": f"{f['id']}-{stage}", "text": f[lang] or f["en"], "topic": f["topic"],
                    "kind": f["kind"], "sources": f["sources"], "score": score}

        emit({"type": "meta", "lang": lang, "stage": stage, "prompt": prompt,
              "confident": found["confident"], "coverage": found["coverage"],
              "symptoms": found["symptoms"],
              # For the client's chat history (follow-up questions).
              "topic": topic if card else None, "sick": bool(sick and card), "followup": follow,
              "suggestions": suggest,
              "diseases": [dict(d, label=friendly.disease_name(d["disease"], lang)) for d in diseases],
              "urgent": card["urgent"] if card else [], "urgent_title": card["urgent_title"] if card else "",
              "evidence": [ev_row(f, s) for f, s in evidence] + [ev_row(f, f["kind"]) for f in extra]})

        try:
            if vet_turn:
                return finish(friendly.card_text(card), "vet", "answer", card)
            # Hard guard: dose/medicine questions get the fixed refusal.
            if guarded:
                if card:
                    return finish(friendly.card_text(card), "guard", "refuse", card)
                return finish(REFUSE[lang], "guard")
            if chat:
                return finish(chat, "chat", "chat")
            # Nothing in the KB matches: abstain without spending a minute on the model,
            # unless there is a warning sign or a named disease we can still help with.
            if not found["confident"] and (not use_model or found["coverage"] == 0):
                if card:
                    return finish(friendly.card_text(card), "kb", "answer", card)
                if friendly_style:
                    return finish(friendly.abstain(lang), "retrieval", "abstain")
                return finish(ABSTAIN[lang], "retrieval")
            if not use_model:
                if card:
                    return finish(friendly.card_text(card), "kb", "answer", card)
                if friendly_style:
                    return finish(friendly.abstain(lang), "retrieval", "abstain")
                return finish(extractive_answer(evidence, lang, stage), "kb")

            make_card = None
            if friendly_style:
                def make_card(model_text):
                    # The model's sentence is the answer; the card adds the topic sections
                    # (urgent warnings were already shown from the meta message).
                    cited = {c.rsplit("-", 1)[0] for c in CITE.findall(model_text)}
                    return friendly.card(KB, lang, stage, topic=topic, sick=sick, want=want,
                                         intro="", skip=cited)[0]
            self.stream_model(prompt, lang, ev_ids, emit, make_card)
        except (BrokenPipeError, ConnectionResetError):
            return  # browser closed / stopped

    def stream_model(self, prompt, lang, ev_ids, emit, make_card=None):
        body = json.dumps({"model": MODEL, "prompt": prompt, "stream": True,
                           "keep_alive": KEEP_ALIVE,
                           "options": dict(MODEL_OPTIONS, num_predict=NUM_PREDICT[lang])}).encode()
        text, stats = "", {}
        try:
            r = urllib.request.urlopen(urllib.request.Request(
                OLLAMA + "/api/generate", data=body,
                headers={"Content-Type": "application/json"}), timeout=900)
            for line in r:
                chunk = json.loads(line)
                if chunk.get("error"):
                    raise RuntimeError(chunk["error"])
                if chunk.get("response"):
                    text += chunk["response"]
                    emit({"type": "token", "text": chunk["response"]})
                if chunk.get("done"):
                    stats = {k: chunk.get(k) for k in
                             ("done_reason", "eval_count", "eval_duration", "load_duration",
                              "prompt_eval_count", "prompt_eval_duration", "total_duration")}
        except (urllib.error.URLError, RuntimeError, ConnectionRefusedError) as e:
            emit({"type": "error", "message": f"Ollama error: {e}. Is Ollama running and "
                                              f"was '{MODEL}' created? (see start.bat)"})
            return
        # Checks cover the model's own words; the topic card is rendered under them.
        checks = check_output(text, lang, ev_ids)
        card = make_card(text) if make_card and checks["behaviour"] == "answer" else None
        emit({"type": "done", "source": "model", "stats": stats, "card": card,
              "truncated": stats.get("done_reason") == "length", "checks": checks})


def extractive_facts(evidence):
    """The best KB fact, plus the runner-up if it is about the same disease and
    nearly as relevant."""
    (best, s1), (second, s2) = evidence[0], (evidence[1] if len(evidence) > 1 else (None, 0))
    facts = [best]
    if second and second["topic"] == best["topic"] and s2 >= 0.75 * s1:
        facts.append(second)
    return facts


def extractive_answer(evidence, lang, stage):
    """Instant short answer, in the same format the model was trained to give."""
    return " ".join(f"{f[lang] or f['en']} [{f['id']}-{stage}]" for f in extractive_facts(evidence))


def prewarm():
    """Load the model into RAM at startup so the first AI answer skips the 20-40 s load."""
    try:
        body = json.dumps({"model": MODEL, "prompt": "", "keep_alive": KEEP_ALIVE,
                           "options": MODEL_OPTIONS}).encode()
        urllib.request.urlopen(urllib.request.Request(
            OLLAMA + "/api/generate", data=body, headers={"Content-Type": "application/json"}),
            timeout=300).read()
        print("[medfarm] model loaded and kept in memory")
    except Exception as e:
        print(f"[medfarm] could not preload model ({e}); fast KB answers still work")


if __name__ == "__main__":
    print(f"MedFarm UI: {len(KB)} KB facts loaded. Ollama: {OLLAMA}, model: {MODEL}")
    # On Windows SO_REUSEADDR lets a second copy share the port and silently take
    # requests; fail loudly instead.
    ThreadingHTTPServer.allow_reuse_address = False
    try:
        server = ThreadingHTTPServer((HOST, PORT), Handler)
    except OSError:
        sys.exit(f"Port {PORT} is already in use. Close the other MedFarm server first "
                 f"(or set PORT=8002).")
    threading.Thread(target=prewarm, daemon=True).start()
    print(f"Open http://127.0.0.1:{PORT}")
    server.serve_forever()
