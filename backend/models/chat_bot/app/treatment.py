"""Treatment guides for the diseases the image model detects (FMD, LSD,
Mastitis, Ringworm), opened from "See treatment" after a photo scan.

Every item is a knowledge-base entry (care_kb.py and the original KB) shown with
its citation. Medicines come from medicines.json: names and uses from the
Merck Veterinary Manual; dose, frequency and withdrawal only where a source gives
them (otherwise shown as "set by your vet").
"""
import json
import os
import random

import care_kb
import friendly
import vets

MEDICINES = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                        "medicines.json"), encoding="utf-8"))

# KB entries per section and stage. Low and High give different steps, order
# and warnings for the same disease; sections with no entries are left out.
PLANS = {
    care_kb.FMD: {
        "Low": {
            "first": ["KB-207", "KB-206", "KB-209"],
            "dont": ["KB-394"],
            "vet": ["KB-205"],
            "milk": ["KB-210"],
            "call_vet": ["KB-243"],
            "prevent": ["KB-208", "KB-200", "KB-114"],
        },
        "High": {  # report first; young calves are at risk
            "first": ["KB-209", "KB-207", "KB-206"],
            "dont": ["KB-394"],
            "vet": ["KB-205"],
            "milk": ["KB-210"],
            "call_vet": ["KB-204", "KB-243"],
            "prevent": ["KB-208", "KB-200"],
        },
    },
    care_kb.LSD: {
        "Low": {
            "first": ["KB-215", "KB-217", "KB-218"],
            "dont": ["KB-394"],
            "vet": ["KB-214"],
            "milk": [],
            "call_vet": ["KB-243"],
            "prevent": ["KB-216", "KB-213", "KB-114"],
        },
        "High": {  # report first; sores are likely infected
            "first": ["KB-218", "KB-215", "KB-217"],
            "dont": ["KB-394"],
            "vet": ["KB-214", "KB-219"],
            "milk": [],
            "call_vet": ["KB-243"],
            "prevent": ["KB-216", "KB-213"],
        },
    },
    care_kb.MAS: {
        "Low": {
            "first": ["KB-229", "KB-226"],
            "dont": ["KB-394"],
            "vet": ["KB-222"],
            "milk": ["KB-223"],
            "call_vet": ["KB-224", "KB-243"],
            "prevent": ["KB-225", "KB-227", "KB-109"],
        },
        "High": {  # fever / weakness: the vet first, fluids matter most
            "first": ["KB-224", "KB-229"],
            "dont": ["KB-394"],
            "vet": ["KB-222"],
            "milk": ["KB-223"],
            "call_vet": ["KB-243"],
            "prevent": ["KB-225", "KB-226", "KB-227"],
        },
    },
    care_kb.RW: {
        "Low": {  # usually heals by itself: care and hygiene first
            "first": ["KB-233", "KB-235"],
            "dont": ["KB-394"],
            "vet": ["KB-232"],
            "milk": [],
            "call_vet": [],
            "prevent": ["KB-234", "KB-113", "KB-100"],
        },
        "High": {  # many thick patches: protect people, then treat
            "first": ["KB-235", "KB-233"],
            "dont": ["KB-394"],
            "vet": ["KB-232", "KB-231"],
            "milk": [],
            "call_vet": [],
            "prevent": ["KB-234", "KB-100", "KB-113"],
        },
    },
}
# The image model's class ids start with these ("LSD_High" -> LSD).
CLASS_TOPICS = {"FMD": care_kb.FMD, "LSD": care_kb.LSD, "Mastitis": care_kb.MAS,
                "Ringworm": care_kb.RW}
SECTIONS = ["first", "dont", "vet", "milk", "call_vet", "prevent"]

TEXT = {
    "en": {
        "title": "Treatment",
        "for": ["Treatment and care for {d}", "How to look after a cow with {d}",
                "{d}: treatment and home care"],
        "first": "Do this first",
        "dont": "Do not",
        "vet": "What the vet will do",
        "milk": "Milk and meat safety",
        "call_vet": "Call a vet at once if",
        "prevent": "Prevention",
        "severe": ["Severe stage: please call your vet today.",
                   "This looks severe. Call your vet today; do not wait.",
                   "Severe stage: the cow needs a vet's examination today."],
        "early": ["Early stage: start these steps now and ask your vet to check the cow.",
                  "This looks like an early stage. Begin the steps below and let your vet examine the cow."],
        "no_medicine": "Only a vet who examines the animal can choose medicines and doses. "
                       "Medicines given without a vet can harm the cow and leave residues in milk and meat.",
        "ask": "How is {d} treated?",
        "ask_button": "Ask the assistant about this",
        "sources": "Sources",
        "medicines": "Medicines",
        "medicine_labels": {
            "dose": "Dose", "route": "How it is given", "frequency": "How often",
            "duration": "How long", "withdrawal": "Milk and meat withdrawal",
            "by_vet": "Set by your vet", "withdrawal_default": "Ask your vet and read the product label",
            "prescription": "Prescription: given by a vet", "source": "Source",
            "all_by_vet": "Dose, how often and how long: set by your vet after examining the cow",
        },
    },
    "si": {
        "title": "ප්‍රතිකාර",
        "for": ["{d} සඳහා ප්‍රතිකාර සහ සත්කාර", "{d} ඇති ගවයෙකු රැකබලා ගන්නා ආකාරය",
                "{d}: ප්‍රතිකාර සහ නිවසේ සත්කාර"],
        "first": "මුලින්ම කරන්න",
        "dont": "නොකරන්න",
        "vet": "පශු වෛද්‍යවරයා කරන දේ",
        "milk": "කිරි සහ මස් ආරක්ෂාව",
        "call_vet": "මේවා දුටුවොත් වහාම පශු වෛද්‍යවරයාට කතා කරන්න",
        "prevent": "වැළැක්වීම",
        "severe": ["උග්‍ර අවස්ථාව: අදම ඔබේ පශු වෛද්‍යවරයාට කතා කරන්න.",
                   "මෙය උග්‍ර තත්ත්වයක් ලෙස පෙනේ. බලා නොසිට අදම පශු වෛද්‍යවරයාට කතා කරන්න.",
                   "උග්‍ර අවස්ථාව: ගවයා අදම පශු වෛද්‍යවරයා ලවා පරීක්ෂා කරවිය යුතුයි."],
        "early": ["මුල් අවස්ථාව: දැන්ම මේ පියවර ආරම්භ කර පශු වෛද්‍යවරයා ලවා ගවයා පරීක්ෂා කරවන්න.",
                  "මෙය මුල් අවස්ථාවක් ලෙස පෙනේ. පහත පියවර ආරම්භ කර ගවයා පශු වෛද්‍යවරයාට පෙන්වන්න."],
        "no_medicine": "බෙහෙත් සහ මාත්‍රා තීරණය කළ හැක්කේ සතා පරීක්ෂා කරන පශු වෛද්‍යවරයාට පමණි. "
                       "පශු වෛද්‍ය උපදෙස් නොමැතිව දෙන බෙහෙත් ගවයාට හානි කළ හැකි අතර කිරි හා මස්වල අපද්‍රව්‍ය ඉතිරි කළ හැක.",
        "ask": "{d} වලට ප්‍රතිකාර මොනවද?",
        "ask_button": "මේ ගැන සහායකයාගෙන් අහන්න",
        "sources": "මූලාශ්‍ර",
        "medicines": "ඖෂධ",
        "medicine_labels": {
            "dose": "මාත්‍රාව", "route": "දෙන ආකාරය", "frequency": "කොපමණ වාරයක්",
            "duration": "කොපමණ කාලයක්", "withdrawal": "කිරි හා මස් භාවිත නොකළ යුතු කාලය",
            "by_vet": "පශු වෛද්‍යවරයා තීරණය කරයි",
            "withdrawal_default": "පශු වෛද්‍යවරයාගෙන් අසා නිෂ්පාදනයේ ලේබලය කියවන්න",
            "prescription": "පශු වෛද්‍ය නිර්දේශය අවශ්‍යයි", "source": "මූලාශ්‍රය",
            "all_by_vet": "මාත්‍රාව, වාර ගණන සහ කාලය: ගවයා පරීක්ෂා කර පශු වෛද්‍යවරයා තීරණය කරයි",
        },
    },
}


def topic_for(disease):
    """"LSD_High", "LSD" or "Lumpy Skin Disease" -> the KB topic, else None."""
    key = (disease or "").split("_")[0]
    if key in CLASS_TOPICS:
        return CLASS_TOPICS[key]
    return disease if disease in PLANS else None


def guide(kb_by_id, disease, lang="en", stage=None):
    """The treatment guide for a disease, or None if there is none."""
    topic = topic_for(disease)
    if topic is None:
        return None
    t = TEXT[lang]
    name = friendly.disease_name(topic, lang)
    level = "High" if stage == "High" else "Low"
    plan = PLANS[topic][level]
    used = []
    sections = []
    for key in SECTIONS:
        items = []
        for kb_id in plan[key]:
            entry = kb_by_id[kb_id]
            used.append(entry)
            items.append({"id": f"{kb_id}-{'HI' if stage == 'High' else 'LM'}",
                          "text": friendly.localize(entry[lang] or entry["en"], lang)})
        if items:
            sections.append({"key": key, "title": t[key], "items": items})
    # Entries with "stages" (e.g. fluids for severe mastitis) only show for those stages.
    medicines = [_medicine(m, lang) for m in MEDICINES.get(topic, [])
                 if level in m.get("stages", ["Low", "High"])]
    sources = sorted({url for e in used for url in e.get("sources", [])}
                     | {m["source"] for m in medicines if m["source"]})
    return {
        "disease": name,
        "topic": topic,
        "stage": stage,
        "title": t["title"],
        "heading": _capitalise(random.choice(t["for"]).format(d=name)),
        "severe": random.choice(t["severe"]) if level == "High" else None,
        "stage_note": random.choice(t["early"]) if level == "Low" else None,
        "no_medicine": t["no_medicine"],
        "sections": sections,
        "medicines_title": t["medicines"],
        "medicine_labels": t["medicine_labels"],
        "medicines": medicines,
        "contacts_title": friendly.VET_TEXT[lang]["offices"],
        "contacts": vets.all_contacts(lang),
        "call_label": friendly.VET_TEXT[lang]["call"],
        "sources_title": t["sources"],
        "sources": sources,
        "ask": t["ask"].format(d=name),
        "ask_button": t["ask_button"],
    }


def _medicine(entry, lang):
    """One medicine in the farmer's language; empty fields stay None."""
    def text(field):
        value = entry.get(field)
        return (value.get(lang) or value.get("en")) if isinstance(value, dict) else value
    return {
        "name": text("name"), "kind": text("kind"), "use": text("use"), "route": text("route"),
        "dose": text("dose"), "frequency": text("frequency"), "duration": text("duration"),
        "withdrawal": text("withdrawal"), "prescription": bool(entry.get("prescription")),
        "source": care_kb.SOURCES.get(entry.get("source"), ""),
    }


def _capitalise(text):
    """"mastitis (udder infection): ..." -> "Mastitis (udder infection): ..."."""
    return text[:1].upper() + text[1:]
