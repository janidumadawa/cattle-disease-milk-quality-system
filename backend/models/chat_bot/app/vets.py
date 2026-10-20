"""Government veterinary offices the chatbot refers farmers to.

Office details live in vet_offices.json so they can be updated without code
changes. Text fields are {"en": ..., "si": ...}; "doctor" and "address" are
shown only when filled in.
"""
import json
import os
import re

TOPIC = "Vet contact"
OFFICES = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                      "vet_offices.json"), encoding="utf-8"))

# Asking for a vet: a vet word plus where / contact / need, or a short "vet?".
VET_WORD = re.compile(r"\b(vets?|veterinar\w*|doctors?|docs?|animal hospital)\b|"
                      r"පශු වෛද්‍?ය|වෛද්‍?ය|ඩොක්ටර්|දොස්තර|ඩොක්ට|වෙද ?මහත්ත", re.I)
VET_NEED = re.compile(r"\b(where|nearest|near|closest|close to|find|contact|number|phone|call|"
                      r"need|want|address|location|office|clinic|get|meet|see|visit|help|please)\b|"
                      r"කොහෙද|කොතනද|ළඟම|ලඟම|ළඟ|ලඟ|අංක|නම්බර්|ෆෝන්|දුරකථන|ඕන|ලිපින|"
                      r"කාර්යාල|හොයා|හොයන්න|කතා කර|කෙනෙක්|හමු ?වෙන්න|හම්බ ?වෙන්න|අවශ්‍?ය|"
                      r"ගෙන්වන්න|ඉක්මනින්|හදිසි", re.I)
# "I need a vet urgently": show every office at once instead of asking the town first.
URGENT = re.compile(r"\b(urgent\w*|emergency|quick\w*|asap|right away|immediately)\b|"
                    r"ඉක්මනින්|හදිසි|වහාම|දැන්ම", re.I)


def wants_vet(text):
    return bool(VET_WORD.search(text)) and (bool(VET_NEED.search(text)) or len(text.split()) <= 3)


def is_urgent(text):
    return bool(URGENT.search(text))


def _name_re(name):
    # Sinhala has no \b; English names must be whole words ("buttala", not "abuttalax").
    return re.escape(name) if re.search(r"[඀-෿]", name) else r"\b" + re.escape(name) + r"\b"


_NAMES = [(re.compile(_name_re(n), re.I), office) for office in OFFICES for n in office["names"]]


def find_office(text):
    """The office for a town named in the text, if any."""
    for rx, office in _NAMES:
        if rx.search(text or ""):
            return office
    return None


def only_place(text):
    """A message that is just a town ("Buttala", "I'm in බුත්තල"): the answer to
    "where are you?" or a request for that town's vet."""
    words = re.sub(r"[^\w඀-෿\s]", " ", text).split()
    return find_office(text) is not None and len(words) <= 4


def _text(value, lang):
    """A field that is either one string or {"en": ..., "si": ...}."""
    if isinstance(value, dict):
        return value.get(lang) or value.get("en") or ""
    return value or ""


def contact(office, lang):
    """One office as shown to the farmer (empty fields left out)."""
    row = {"office": _text(office["office"], lang), "area": _text(office["area"], lang),
           "phone": office["phone"]}
    for field in ("doctor", "address"):
        if _text(office.get(field), lang):
            row[field] = _text(office[field], lang)
    return row


def all_contacts(lang):
    return [contact(o, lang) for o in OFFICES]


def town_names(lang):
    return [o["area"][lang] for o in OFFICES]
