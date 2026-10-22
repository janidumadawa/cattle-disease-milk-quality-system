"""Rule-based questions that narrow a sick cow down to one disease.

The farmer describes what they see; the server then asks one yes/no question at a
time, like a vet taking a history, until one disease clearly fits the answers.
Every disease has signs with weights (how strongly a sign points to it). A "no"
counts against the diseases that sign points to. The chat state travels with the
client's chat history (meta "triage"), so the server stays stateless.

No health facts live here: the questions only ask what the farmer sees, and the
answer after the questions is built from KB entries (friendly.card).
"""
import re

import care_kb

SI = r"[඀-෿]"
NOT_SI_BEFORE, NOT_SI_AFTER = r"(?<![඀-෿])", r"(?![඀-෿])"

# id: (what the farmer says, question en, question si, label en, label si)
SIGNS = {
    "mouth": (
        r"blister|vesicle|(mouth|tongue|lips?|gums?).{0,25}(sore|ulcer|wound|lesion)|"
        r"(sore|ulcer|wound|lesion).{0,25}(mouth|tongue|lips?)|බිබිලි|බුබුළු|"
        r"(කට|දිව|තොල්|මුඛ).{0,15}(තුවාල|වණ)",
        "Are there blisters or sores in her mouth, on the tongue or lips?",
        "ගවයාගේ කටේ, දිවේ හෝ තොල්වල බිබිලි හෝ තුවාල තියෙනවද?",
        "blisters or sores in the mouth", "කටේ බිබිලි හෝ තුවාල"),
    "drool": (
        r"drool|saliva|slobber|froth|" + NOT_SI_BEFORE + r"කෙළ|කෙල ගල|පෙණ",
        "Is she drooling a lot, with saliva hanging from the mouth?",
        "කටින් කෙළ ගොඩක් ගලනවද?",
        "drooling", "කෙළ ගැලීම"),
    "feet": (
        r"(hoof|hooves|claws?|feet|foot|toes?).{0,25}(sore|wound|blister|ulcer|lesion)|"
        r"(sore|wound|ulcer|lesion).{0,25}(hoof|hooves|claws?|feet|foot)|between the (claws|toes|hooves)|"
        r"(කුර|කකුල|පාද).{0,15}(තුවාල|වණ|බිබිලි)|කුර අතර",
        "Are there sores or blisters on her feet or between the hooves?",
        "කකුල්වල හෝ කුර අතර තුවාල හෝ බිබිලි තියෙනවද?",
        "sores on the feet", "කකුල්වල තුවාල"),
    "lame": (
        r"limp|lame|can'?t walk|hard to walk|කොර|ඇවිදින්න (අමාරු|බැ)",
        "Is she limping, or finding it hard to walk?",
        "ගවයා කොර ගහනවද, නැත්නම් ඇවිදින්න අමාරුද?",
        "limping", "කොර ගැසීම"),
    "foot_smell": (
        r"(foul|bad|rotten).{0,15}(smell|odou?r).{0,30}(foot|feet|hoof|hooves|claw)|"
        r"(foot|feet|hoof|hooves|claw).{0,30}(smell|stink|odou?r)|(කුර|කකුල|පාද).{0,20}(ගඳ|කුණු)|දුගඳ",
        "Is there a bad smell from between the hooves, with swelling above the hoof?",
        "කුර අතරින් නරක ගඳක් එනවද, කුරට උඩින් ඉදිමිලාද?",
        "a bad smell from the foot", "කුරෙන් දුගඳ"),
    "lumps": (
        r"lump|bump|nodule|knot|ගැටිති|ගැට(?![ළලු])|ගෙඩි|කුරුලෑ",
        "Are there round, firm lumps on her skin?",
        "සමේ රවුම් තද ගැටිති තියෙනවද?",
        "lumps on the skin", "සමේ ගැටිති"),
    "patches": (
        r"hair loss|bald|hairless|crust|scab|\bring|round patch|" + NOT_SI_BEFORE + r"ලප|පැල්ලම|"
        r"(රෝම|ලොම්).{0,15}(ගැලව|නැති|යන)|මුඩු|පොතු|රවුම්",
        "Are there round, grey-white, hairless crusty patches on her skin?",
        "සමේ රෝම නැති, අළු-සුදු පාට රවුම් පොතු ලප තියෙනවද?",
        "round hairless patches", "රෝම නැති රවුම් ලප"),
    "itch": (
        r"itch|scratch|rubbing|කැසීම|කසනව|කහනව|කසන|අතුල්ල",
        "Is her skin itchy, or does she keep rubbing it?",
        "සම කසනවද, නැත්නම් ගස්වල අතුල්ලනවද?",
        "itching", "කැසීම"),
    "udder": (
        r"(udder|teat|quarter).{0,30}(swol|swell|hard|hot|pain|red)|"
        r"(swol|swell|hard|hot|pain|red).{0,30}(udder|teat|quarter)|"
        r"(බුරුල්|බුරුල|බුරුලු|තන).{0,20}(ඉදිම|තද|රස්නෙ|රතු|රිදෙ|ගල්)|(ඉදිම|තද).{0,15}(බුරුල්|තන)",
        "Is one part (quarter) of her udder swollen, hard, hot or painful?",
        "බුරුල්ලේ (තනයේ) කොටසක් ඉදිමිලා, තද වෙලා, රස්නෙයි හෝ රිදෙනවද?",
        "a swollen or hot udder", "බුරුල්ල ඉදිමීම"),
    "milk_change": (
        r"clot|flake|watery milk|thin milk|(blood|pus).{0,15}milk|"
        r"milk.{0,20}(blood|clot|water|yellow|smell|colou?r|lump)|"
        r"කිරි.{0,15}(කැටි|වතුර|ලේ|පාට|ගඳ|කහ|දියර|සැරව)|(කැටි|ලේ).{0,10}කිරි",
        "Has her milk changed: clots or flakes, watery milk, or blood in it?",
        "කිරිවල කැටි, වතුර වගේ වීම හෝ ලේ වගේ වෙනසක් තියෙනවද?",
        "changed milk (clots, watery or blood)", "කිරිවල වෙනස (කැටි, වතුර වගේ හෝ ලේ)"),
    "milk_drop": (
        r"less milk|milk.{0,15}(drop|down|reduc|less|decreas)|(drop|reduc|decreas).{0,15}milk|"
        r"කිරි.{0,10}අඩු",
        "Has her milk yield dropped suddenly?",
        "කිරි ප්‍රමාණය හදිසියේ අඩු වුණාද?",
        "less milk", "කිරි අඩුවීම"),
    "fever": (
        r"fever|hot body|body.{0,10}hot|temperature|උණ(?!ු)|" + NOT_SI_BEFORE + r"උන" + NOT_SI_AFTER +
        r"|ඇඟ.{0,10}රස්න|රස්නෙ ගතිය",
        "Does she have a fever (does her body feel hot)?",
        "ගවයාට උණ තියෙනවද (ඇඟ රස්නෙයිද)?",
        "fever", "උණ"),
    "appetite": (
        r"not eating|off (her |its )?feed|appetite|won'?t eat|eat(s|ing)? less|stopped eating|"
        r"කන්නේ නැ|කන්නෑ|කෑම.{0,15}(අඩු|නැ)|අඩුවෙන් කන|කනවා අඩු|කන්න අකමැති|අරුචි",
        "Is she eating less than usual?",
        "සුපුරුදු ප්‍රමාණයට වඩා අඩුවෙන් කනවද?",
        "eating less", "කෑම අඩුවීම"),
    "dung_blood": (
        r"(blood|bloody).{0,15}(dung|stool|faeces|feces|poo)|(dung|stool|faeces|feces|poo).{0,15}blood|"
        r"ගොම.{0,10}ලේ",
        "Is there blood in the dung?",
        "ගොමවල ලේ තියෙනවද?",
        "blood in the dung", "ගොමවල ලේ"),
    "weak": (
        r"\bweak|\bdull|letharg|not drinking|stopped drinking|won'?t drink|"
        r"තෙහෙට්ටු|දුර්වල|අලස|බොන්නේ නැ|වතුර බොන්නෑ",
        "Is she weak or dull, or has she stopped drinking?",
        "ගවයා දුර්වලද, අලසද, නැත්නම් වතුර බොන එක නැවැත්තුවාද?",
        "weakness", "දුර්වලතාවය"),
    "diarrhoea": (
        r"diarr?h|scour|loose (dung|stool|motion)|(watery|runny) (dung|stool|faeces|feces|poo)|"
        r"පාචන|බඩ යනව|බඩ යාම|බඩ ගිහින්|ගොම.{0,10}(දියර|වතුර)|දියර ගොම",
        "Does she have diarrhoea (loose, watery dung)?",
        "බඩ යනවද (ගොම දියර වෙලාද)?",
        "diarrhoea", "බඩ යාම"),
    "bloat": (
        r"bloat|(left|stomach|belly|abdomen|rumen).{0,25}(swol|swell|bigger|tight|distend|blown)|"
        r"(swol|swell|blown).{0,25}(left side|stomach|belly|abdomen)|බඩ.{0,10}(පිම්බ|පිපිල|ඉදිම|පිපී)",
        "Is the left side of her belly blown up like a drum?",
        "බඩේ වම් පැත්ත බෙරයක් වගේ පිම්බිලාද?",
        "a swollen left belly", "බඩේ වම් පැත්ත පිපීම"),
    "breath": (
        r"breath|pant|gasp|wheez|හුස්ම|හති",
        "Is she breathing fast or with difficulty?",
        "ඉක්මනින් හෝ අමාරුවෙන් හුස්ම ගන්නවද?",
        "fast or hard breathing", "හුස්ම ගැනීමේ අපහසුව"),
    "cough": (
        r"cough|කැස්ස|කහිනව|කහින|කැහැ",
        "Is she coughing?",
        "ගවයා කහිනවද?",
        "coughing", "කැස්ස"),
    "nasal": (
        r"nasal|snot|runny nose|nose.{0,15}(discharge|running|runs|mucus|dripping)|discharge.{0,15}nose|"
        r"නාසයෙන් (දියර|සෙම)|" + NOT_SI_BEFORE + r"සෙම",
        "Is there a discharge from her nose?",
        "නාසයෙන් සෙම හෝ දියර ගලනවද?",
        "nasal discharge", "නාසයෙන් සෙම"),
    "eye_water": (
        r"\btears?\b|watery eyes?|eyes?.{0,15}water|කඳුළු|ඇස්.{0,10}(වතුර|ගලන)",
        "Are her eyes watering?",
        "ඇස්වලින් කඳුළු ගලනවද?",
        "watery eyes", "ඇස්වලින් කඳුළු"),
    "eye_cloudy": (
        r"cloudy eye|eyes?.{0,20}(cloudy|white|blue|closed|shut)|(white|blue) (spot|patch) on.{0,12}eye|"
        r"squint|ඇස.{0,15}(සුදු|බොඳ|වහ|නිල්)",
        "Is an eye cloudy or white, or does she keep it shut?",
        "ඇස සුදු පාට හෝ බොඳ වෙලාද, නැත්නම් ඇස වහගෙන ඉන්නවද?",
        "a cloudy eye", "බොඳ ඇස"),
    "ticks": (
        r"\bticks?\b|කිනිතුල්|කිනිතුලු",
        "Do you see many ticks on her body?",
        "ඇඟේ කිනිතුල්ලන් ගොඩක් ඉන්නවද?",
        "many ticks", "කිනිතුල්ලන්"),
    "red_urine": (
        r"(red|dark|brown|bloody|coffee).{0,15}(urine|pee)|(urine|pee).{0,20}(red|dark|brown|blood)|"
        r"මුත්‍?රා.{0,15}(රතු|කළු|දුඹුරු|ලේ|තද)",
        "Is her urine red or dark brown?",
        "මුත්‍රා රතු හෝ තද දුඹුරු පාටද?",
        "red or dark urine", "රතු හෝ තද පාට මුත්‍රා"),
    "pale": (
        r"\bpale\b|yellow (gums|eyes)|jaundice|ana?emi|සුදුමැලි|(විදුරුමස්|ඇස් ඇතුළ).{0,10}(සුදු|කහ)",
        "Are her gums or the inside of her eyelids pale or yellow?",
        "විදුරුමස් හෝ ඇස් ඇතුළ සුදුමැලි හෝ කහ පාටද?",
        "pale gums", "සුදුමැලි විදුරුමස්"),
    "thin": (
        r"\bthin\b(?!\s+milk)|weight loss|losing weight|lost weight|skinny|not growing|poor growth|"
        r"rough coat|bottle jaw|කෙට්ටු|බර අඩු|වැඩෙන්නේ නැ",
        "Is she getting thin or not growing, even though she eats?",
        "කෑවත් කෙට්ටු වෙනවද, නැත්නම් වැඩෙන්නේ නැද්ද?",
        "weight loss", "කෙට්ටු වීම"),
    "calved": (
        r"calved|calving|gave birth|giving birth|delivered|after delivery|"
        r"(පැටවා|පැටියා|වස්සා) (දැම්|දැමු|වැදු)|ප්‍රසූත",
        "Did she give birth (calve) in the last few days?",
        "පසුගිය දවස් කීපය ඇතුළත පැටවා දැම්මාද?",
        "calved recently", "මෑතකදී පැටවා දැමීම"),
    "down": (
        r"can'?t stand|cannot stand|not standing|unable to (stand|get up)|can'?t get up|collaps|"
        r"නැගිටින්න බැ|නැගිටින්නේ නැ|වැතිරිලා|ඇද වැටු|වැටිලා",
        "Is she unable to stand up, or lying down most of the time?",
        "ගවයාට නැගිටින්න බැරිද, නැත්නම් වැඩි වෙලාවක් වැතිරිලාද ඉන්නේ?",
        "cannot stand up", "නැගිටින්න බැරිවීම"),
    "cold": (
        r"cold (ears|legs|body)|(ears|legs).{0,10}cold|කන්.{0,10}සීතල|ඇඟ සීතල",
        "Do her ears and legs feel cold?",
        "ගවයාගේ කන් සහ කකුල් සීතලද?",
        "cold ears and legs", "සීතල කන් සහ කකුල්"),
    "calf": (
        r"\bcalf\b|\bcalves\b|(වස්ස|පැටි|පැටව)(?!ා (දැම්|දැමු|වැදු)|ු (දැම්|දැමු|වැදු))",
        "Is the sick animal a young calf?",
        "අසනීප සතා කුඩා වස්සෙක්ද?",
        "a young calf", "කුඩා වස්සෙක්"),
    "herd": (
        r"other (cows|cattle|animals)|whole herd|several (cows|cattle)|many cows|"
        r"අනිත් (ගව|හරක|සතුන්)|රංචුවේ|කීප දෙනෙක|හැම හරක|ඔක්කොම හරක",
        "Do other cattle in the herd have the same signs?",
        "රංචුවේ අනිත් ගවයන්ටත් මේ ලක්ෂණ තියෙනවද?",
        "others in the herd affected", "අනිත් ගවයන්ටත් ලක්ෂණ"),
    "lush": (
        r"fresh grass|lush|legume|clover|ate a lot|අලුත් තණකොළ|රනිල|ගොඩක් කෑව",
        "Did she eat a lot of fresh green grass or legumes just before this?",
        "මීට කලින් අලුත් තණකොළ හෝ රනිල ශාක ගොඩක් කෑවද?",
        "ate lots of fresh grass", "අලුත් තණකොළ ගොඩක් කෑම"),
    "flies": (
        r"\bfl(y|ies)\b|mosquito|මැස්ස|මදුරු",
        "Are there many flies or mosquitoes around the shed?",
        "ගාල වටේ මැස්සන් හෝ මදුරුවන් ගොඩක් ඉන්නවද?",
        "many flies or mosquitoes", "මැස්සන් හෝ මදුරුවන් ගොඩක්"),
}
SIGN_RE = {s: re.compile(v[0], re.I) for s, v in SIGNS.items()}

# How strongly each sign points to each disease. KEY signs (>= KEY) are the ones
# a vet looks for first; a disease is named only when one of them is confirmed.
WEIGHTS = {
    care_kb.FMD: {"mouth": 3.5, "feet": 3, "drool": 2, "lame": 1.5, "herd": 1.5, "fever": 1,
                  "milk_drop": 0.5, "appetite": 0.5},
    care_kb.LSD: {"lumps": 4, "fever": 1.5, "nasal": 1, "eye_water": 1, "flies": 1,
                  "milk_drop": 0.5, "appetite": 0.5, "herd": 0.5},
    care_kb.MAS: {"udder": 3.5, "milk_change": 3.5, "milk_drop": 1, "fever": 0.5,
                  "appetite": 0.5},
    care_kb.RW: {"patches": 4, "calf": 1, "itch": 0.5, "herd": 0.5},
    care_kb.DIA: {"diarrhoea": 4, "calf": 1.5, "weak": 1, "dung_blood": 1, "appetite": 0.5,
                  "down": 0.5},
    care_kb.BLO: {"bloat": 4, "lush": 2, "breath": 1.5, "appetite": 0.5},
    care_kb.PNE: {"cough": 3, "nasal": 2, "breath": 2, "fever": 1, "appetite": 0.5, "calf": 0.5},
    care_kb.TICK: {"red_urine": 3.5, "ticks": 2.5, "pale": 2, "fever": 1.5, "appetite": 0.5,
                   "milk_drop": 0.5},
    care_kb.WORM: {"thin": 3, "pale": 1.5, "diarrhoea": 1, "calf": 1},
    care_kb.EYE: {"eye_cloudy": 3.5, "eye_water": 2.5, "flies": 1},
    care_kb.FOOT: {"foot_smell": 4, "lame": 2.5, "feet": 1},
    care_kb.MF: {"calved": 3, "down": 3, "cold": 2, "weak": 1, "appetite": 0.5},
}
KEY = 3
NO_WEIGHT = 0.6        # a "no" counts against a disease at this share of the sign's weight
CONFIRM = 0.9          # a disease is named once the answers fit it this well
MAX_QUESTIONS = 8      # after this many, the best fit is named as "possible"
MIN_QUESTIONS = 3      # asked before a disease is named, even when it fits early
# Match %: the weight of the signs she has, against doubt from the signs she does
# not have, the signs not asked yet (or "not sure") and a rival disease.
# A "no" weighs more than an open sign, so it always lowers the %.
NO_DOUBT, OPEN_DOUBT = 0.6, 0.3
FIT_CAP = 0.95         # never 100%: only a vet can be sure
# The match % also grows with each question answered, so it climbs step by step
# (a vet is surer after a few questions) instead of jumping on the first answers.
RAMP = [0.6, 0.75, 0.86, 0.96, 1.0]
# Key signs of each body system, asked while no disease has a key sign yet.
SCREEN = ["mouth", "udder", "milk_change", "feet", "lumps", "diarrhoea", "cough", "patches",
          "bloat", "red_urine", "eye_cloudy", "foot_smell", "thin", "calved"]

# Signs worth starting the questions for (fever or "not eating" alone are not).
START_SIGNS = {s for w in WEIGHTS.values() for s, v in w.items() if v >= KEY}

NEG_BEFORE = re.compile(r"(\bno|\bnot|n'?t|never|without)\W+(\w+\W+){0,3}$", re.I)
NEG_AFTER = re.compile(r"\s*(?:[඀-෿‍]+\s+)?(නැහැ|නෑ|නැත|නැති|නෙවෙයි|නොවේ)" + NOT_SI_AFTER)

UNSURE = re.compile(r"not sure|don'?t know|dont know|no idea|maybe|unsure|දන්නේ නැ|දන්නෑ|"
                    r"විශ්වාස නැ|සමහර ?විට|හරියට දන්නෑ|danne na|dannea", re.I)
YES_START = re.compile(r"^\W*(yes|yeah|yep|yup|ya|ok|sure|correct|right|true|ow|ou|"
                       r"ඔව්|ඔව|එහෙමයි|එහෙම තමයි|හරි)(?![a-z඀-෿])", re.I)
NO_START = re.compile(r"^\W*(no|nope|nah|not really|never|naha|nehe|na|"
                      r"නැහැ|නෑ|නැත|නැ|එහෙම නැ|නෙවෙයි|නොවේ)(?![a-z඀-෿])", re.I)
YES_SHORT = re.compile(r"තියෙනවා|තියනවා|ඉන්නවා|වෙනවා|ඇත|ඇති|ගලනවා|කනවා", re.I)
NO_SHORT = re.compile(r"නැහැ|නෑ|නැත|නැති|\bnot\b|\bno\b", re.I)

TEXT = {
    "en": {
        "start": "I'm sorry your cow is unwell. To find out which disease this is, I'll ask a "
                 "few short questions. Please answer yes or no.",
        "noted": "Noted so far: {signs}.",
        "ack_no": "Okay, no {sign}. That makes some diseases less likely.",
        "ack_unsure": "No problem, I'll leave {sign} aside for now.",
        "question": "Question {n}:",
        "strong": "Based on your answers ({signs}), this most likely is {d} ({p}% match).",
        "possible": "Your answers ({signs}) point most to {d} ({p}% match), but I'm not "
                    "fully sure.",
        "early": "From your answers ({signs}), this may be a common, mild illness. But these "
                 "can also be the first signs of {d} ({p}% match), before the other signs "
                 "show. So please see a vet as soon as possible.",
        "confirm": "Only a vet can confirm this by examining her.",
        "unclear": "From your answers I can't tell which disease this is.",
        "offer": {
            "treatment": "Would you like to know how it is treated?",
            "care": "Would you like to know how to care for her at home?",
            "prevention": "Would you like to know how to stop it spreading or coming back?",
        },
        "vets": "Vet offices you can call:",
        "noted_reply": "Thank you. If you notice any other signs, tell me and I'll check again. "
                       "You can also ask about treatment, prevention or the nearest vet.",
    },
    "si": {
        "start": "ඔබේ ගවයා අසනීප වීම ගැන කනගාටුයි. මෙය කුමන රෝගයදැයි හරියටම හඳුනාගන්න, මම "
                 "කෙටි ප්‍රශ්න කීපයක් අහන්නම්. කරුණාකර ඔව් හෝ නැහැ කියලා උත්තර දෙන්න.",
        "noted": "මෙතෙක් සටහන් කළ ලක්ෂණ: {signs}.",
        "ack_no": "හරි, {sign} නැහැ කියලා සටහන් කළා. ඒ නිසා සමහර රෝග වීමේ ඉඩ අඩුයි.",
        "ack_unsure": "කමක් නැහැ, {sign} ගැන දැනට පසෙකින් තියමු.",
        "question": "ප්‍රශ්නය {n}:",
        "strong": "ඔබ දුන් පිළිතුරු අනුව ({signs}), මෙය බොහෝදුරට {d} විය හැක ({p}% ගැළපීම).",
        "possible": "ඔබේ පිළිතුරු ({signs}) වැඩිපුරම ගැළපෙන්නේ {d} වලටයි ({p}% ගැළපීම), නමුත් "
                    "මට සම්පූර්ණයෙන්ම විශ්වාස නැහැ.",
        "early": "ඔබේ පිළිතුරු අනුව ({signs}), මෙය සාමාන්‍ය ලෙඩක් විය හැක. නමුත් අනිත් ලක්ෂණ "
                 "පෙනෙන්න කලින්, මේවා {d} වල මුල් ලක්ෂණ වෙන්නත් පුළුවන් ({p}% ගැළපීම). ඒ "
                 "නිසා වහාම පශු වෛද්‍යවරයෙකු හමුවන්න.",
        "confirm": "මෙය තහවුරු කරන්න පුළුවන් ගවයාව පරීක්ෂා කරන පශු වෛද්‍යවරයෙකුට පමණයි.",
        "unclear": "ඔබේ පිළිතුරුවලින් මෙය කුමන රෝගයදැයි මට කියන්න බැහැ.",
        "offer": {
            "treatment": "මෙයට ප්‍රතිකාර කරන හැටි දැනගන්න ඕනද?",
            "care": "ගෙදරදී ගවයාව බලාගන්න හැටි දැනගන්න ඕනද?",
            "prevention": "මෙය පැතිරීම හෝ නැවත ඒම වළක්වන හැටි දැනගන්න ඕනද?",
        },
        "vets": "කතා කළ හැකි පශු වෛද්‍ය කාර්යාල:",
        "noted_reply": "ස්තූතියි. වෙනත් ලක්ෂණ දුටුවොත් මට කියන්න, මම ආයෙත් බලන්නම්. ප්‍රතිකාර, "
                       "වැළැක්වීම හෝ ළඟම පශු වෛද්‍යවරයා ගැනත් අහන්න පුළුවන්.",
    },
}


def new_state():
    return {"yes": [], "no": [], "unsure": [], "asked": [], "pending": None, "urgent": [],
            "done": None, "offer": None}


def pending_state(history):
    """The questions still running in this chat: the latest turn asked one."""
    last = history[-1] if isinstance(history, list) and history else None
    state = last.get("triage") if isinstance(last, dict) else None
    if not isinstance(state, dict) or not state.get("pending") or state.get("done"):
        return None
    state = dict(new_state(), **state)
    return state if all(isinstance(state[k], list) for k in ("yes", "no", "unsure", "asked")) \
        else None


# The disease's guide, a part at a time, each only if the farmer wants it.
OFFERS = ["treatment", "care", "prevention"]


def offer_state(history):
    """The disease named in this chat, when the latest turn offered the next part of
    its guide ("would you like to know how it is treated?")."""
    last = history[-1] if isinstance(history, list) and history else None
    state = last.get("triage") if isinstance(last, dict) else None
    if not isinstance(state, dict) or state.get("offer") not in OFFERS or not state.get("done"):
        return None
    return state


def answered(history):
    """Both labels of every sign the farmer answered in this chat's latest questions
    ("yes" alone does not say "milk"), so they are not asked again."""
    for turn in reversed(history if isinstance(history, list) else []):
        state = turn.get("triage") if isinstance(turn, dict) else None
        if isinstance(state, dict):
            signs = [s for k in ("yes", "no") for s in state.get(k) or [] if s in SIGNS]
            return [SIGNS[s][3] for s in signs] + [SIGNS[s][4] for s in signs]
    return []


def mentions(text):
    """{sign: True/False} for the signs the text names ("no fever" -> False), and the
    spans those words (with their "no") cover."""
    found, spans = {}, []
    for sign, rx in SIGN_RE.items():
        for m in rx.finditer(text):
            start, end = m.start(), m.end()
            before = NEG_BEFORE.search(text[max(0, start - 30):start])
            after = NEG_AFTER.match(text, end)
            negative = bool(before or after)
            if before:
                start -= len(before.group())
            if after:
                end = after.end()
            # One "yes" mention wins over a "no" for the same sign.
            found[sign] = found.get(sign, False) or not negative
            spans.append((start, end))
    return found, spans


def answer_kind(text, spans=()):
    """"yes", "no", "unsure" or None for a reply to the question asked."""
    rest = list(text)
    for s, e in spans:
        rest[s:e] = " " * (e - s)
    rest = "".join(rest).strip()
    if UNSURE.search(rest):
        return "unsure"
    if NO_START.search(rest):
        return "no"
    if YES_START.search(rest):
        return "yes"
    if not spans and len(rest.split()) <= 4:
        if NO_SHORT.search(rest):
            return "no"
        if YES_SHORT.search(rest):
            return "yes"
    return None


def bare_reply(text):
    """Just "yes", "no" or "not sure", with no sign named."""
    found, spans = mentions(text)
    return not found and len(text.split()) <= 3 and answer_kind(text, spans) is not None


def add(state, sign, value):
    for key in ("yes", "no", "unsure"):
        if sign in state[key]:
            state[key].remove(sign)
    state[value].append(sign)


def start(text, urgent=(), sick=False):
    """New questions from the first message, or None when it names no sign worth
    asking about. sick: the server read it as a sick cow (fever, limping ...), so
    any sign starts them."""
    found, _ = mentions(text)
    seen = {s for s, v in found.items() if v}
    if not (seen & START_SIGNS or urgent or (sick and seen)):
        return None
    state = new_state()
    for sign, value in found.items():
        add(state, sign, "yes" if value else "no")
    state["urgent"] = list(urgent)
    return state


def read_reply(text, state, urgent=()):
    """The farmer's reply to the question asked: updates and returns the state, or
    None when the message is not a reply (a new question)."""
    found, spans = mentions(text)
    kind = answer_kind(text, spans)
    pending = state["pending"]
    if kind is None and not found:
        return None
    state = dict(state, yes=list(state["yes"]), no=list(state["no"]),
                 unsure=list(state["unsure"]), asked=list(state["asked"]),
                 urgent=list(dict.fromkeys(list(state["urgent"]) + list(urgent))))
    if pending not in found:
        add(state, pending, kind or "unsure")
    for sign, value in found.items():
        add(state, sign, "yes" if value else "no")
    state["pending"] = None
    return state


def scores(state):
    out = {}
    for disease, weights in WEIGHTS.items():
        s = sum(weights.get(x, 0) for x in state["yes"])
        s -= NO_WEIGHT * sum(weights.get(x, 0) for x in state["no"])
        out[disease] = s
    return out


def has_key(disease, state):
    return any(WEIGHTS[disease].get(x, 0) >= KEY for x in state["yes"])


def ranked(state):
    sc = scores(state)
    return sorted(((sc[d], d) for d in sc if has_key(d, state)), reverse=True)


def fit_of(disease, state, rival=0):
    """How well the answers fit a disease, 0 to FIT_CAP. Each "yes" to its signs
    raises it; "no", unasked signs and a close rival hold it back."""
    if not has_key(disease, state):
        return 0.0
    w = WEIGHTS[disease]
    yes = sum(w.get(s, 0) for s in state["yes"])
    no = sum(w.get(s, 0) for s in state["no"])
    open_ = sum(v for s, v in w.items() if s not in state["yes"] and s not in state["no"])
    fit = min(FIT_CAP, yes / (yes + NO_DOUBT * no + OPEN_DOUBT * open_ + max(rival, 0)))
    # Nothing left to ask: one step further, as the answers are all there is.
    n = len(state["asked"]) + (0 if next_question(state) else 1)
    fit *= RAMP[min(n, len(RAMP) - 1)]
    # "No" or "not sure" to one of its signs never raises it.
    last = state["asked"][-1] if state["asked"] else None
    if last in w and last not in state["yes"]:
        before = dict(state, asked=state["asked"][:-1],
                      **{k: [x for x in state[k] if x != last] for k in ("no", "unsure")})
        fit = min(fit, fit_of(disease, before, rival))
    return fit


def fits(state):
    """[(fit, disease)] best first, for the diseases with a key sign."""
    top = ranked(state)
    return sorted(((fit_of(d, state, max((r for r, o in top if o != d), default=0)), d)
                   for _, d in top), reverse=True)


def next_question(state):
    """The sign to ask about next, or None when there is nothing useful left."""
    told = set(state["yes"]) | set(state["no"]) | set(state["unsure"]) | set(state["asked"])
    top = ranked(state)
    if not top:
        # No key sign yet: the key signs of the diseases the signs so far fit
        # ("limping": the feet first), then every body system in turn.
        sc = scores(state)
        for disease in sorted((d for d in sc if sc[d] > 0), key=lambda d: -sc[d]):
            keys = sorted((s for s, w in WEIGHTS[disease].items() if w >= KEY and s not in told),
                          key=lambda s: -WEIGHTS[disease][s])
            if keys:
                return keys[0]
        return next((s for s in SCREEN if s not in told), None)
    (s1, d1), rival = top[0], (top[1] if len(top) > 1 else None)
    open_signs = [s for s in SIGNS if s not in told]
    if rival and rival[0] >= 0.5 * s1:
        # Two diseases fit: ask what tells them apart.
        w1, w2 = WEIGHTS[d1], WEIGHTS[rival[1]]
        value = {s: abs(w1.get(s, 0) - w2.get(s, 0)) for s in open_signs}
        best = max(open_signs, key=lambda s: (value[s], WEIGHTS[d1].get(s, 0)), default=None)
        if best and value[best] >= 1:
            return best
    # One disease fits: ask its next most telling sign to confirm it.
    best = max(open_signs, key=lambda s: WEIGHTS[d1].get(s, 0), default=None)
    return best if best and WEIGHTS[d1].get(best, 0) > 0 else None


def verdict(state):
    """(disease or None, "strong" | "possible" | "early" | None) once the questions
    can stop, else None to keep asking. "early": the questions ended on a "no", so
    it may be a mild illness, or the first signs of the disease before the rest show."""
    top = fits(state)
    enough = len(state["asked"]) >= MIN_QUESTIONS or not next_question(state)
    if top and top[0][0] >= CONFIRM and enough:
        return top[0][1], "strong"
    if len(state["asked"]) < MAX_QUESTIONS and next_question(state):
        return None
    if not (top and top[0][0] > 0):
        return None, None
    last = state["asked"][-1] if state["asked"] else None
    return top[0][1], "early" if last in state["no"] else "possible"


def ask(state):
    """Pick the next question; returns the updated state, or None when done."""
    sign = next_question(state)
    if sign is None:
        return None
    return dict(state, pending=sign, asked=list(state["asked"]) + [sign])


def ack(state, lang):
    """A line on the farmer's last answer when it was "no" or "not sure", so the
    reply does not just move on as if they had said "yes"."""
    last = state["asked"][-1] if state["asked"] else None
    kind = "ack_no" if last in state["no"] else "ack_unsure" if last in state["unsure"] else None
    return TEXT[lang][kind].format(sign=labels([last], lang)) if kind else ""


def question_text(sign, lang):
    return SIGNS[sign][1 if lang == "en" else 2]


def labels(signs, lang):
    return ", ".join(SIGNS[s][3 if lang == "en" else 4] for s in signs)


def percent(disease, state):
    return round(100 * dict((d, f) for f, d in fits(state)).get(disease, 0))


def matches(state):
    """Diseases the answers fit, for the "signs match" box (not a diagnosis)."""
    sc = scores(state)
    return [{"disease": d, "share": round(f, 2), "score": round(sc[d], 1)}
            for f, d in fits(state)[:3] if f > 0]
