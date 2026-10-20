"""Extra MedFarm KB entries: more signs, treatment approach, home care, prevention
and emergencies. Same ID format as the original KB so citations work unchanged.

Written from the sources listed in SOURCES (checked 2026-10-20). No medicine names,
doses or withdrawal times: treatment entries describe what the vet does.
Sinhala text is a draft translation and needs native-speaker review.

kind: sign | treatment | care | prevention | urgent
"""

SOURCES = {
    "merck-fmd": "https://www.merckvetmanual.com/generalized-conditions/foot-and-mouth-disease/foot-and-mouth-disease-in-animals",
    "fmd-care": "https://www.gardenroute.gov.za/wp-content/uploads/2026/02/Treating-Clinical-Signs-and-Symptoms-of-Livestock-infected-by-FMD.pdf",
    "merck-lsd": "https://www.merckvetmanual.com/integumentary-system/pox-diseases/lumpy-skin-disease-in-cattle",
    "woah-lsd": "https://www.woah.org/en/disease/lumpy-skin-disease/",
    "merck-mastitis": "https://www.merckvetmanual.com/reproductive-system/mastitis-in-large-animals/mastitis-in-cattle",
    "merck-ringworm": "https://www.merckvetmanual.com/integumentary-system/dermatophytosis/dermatophytosis-in-cattle",
    "merck-anthrax": "https://www.merckvetmanual.com/generalized-conditions/anthrax/anthrax-in-animals",
}

FMD, LSD, MAS, RW, EM = ("Foot-and-Mouth Disease", "Lumpy Skin Disease", "Mastitis",
                         "Ringworm", "Emergency")

CARE = [
    # ---- Foot-and-Mouth Disease ----
    ("KB-201", FMD, "sign", "merck-fmd",
     "Cattle with FMD often drool a lot and make smacking sounds with their lips.",
     "FMD ඇති ගවයන්ගේ කටින් බොහෝ කෙළ හැලෙන අතර තොල් සපමින් ශබ්ද කරන්න පුළුවන්."),
    ("KB-202", FMD, "sign", "merck-fmd",
     "Blisters on the feet can cause lameness; affected cattle stamp their feet and prefer to lie down.",
     "පාදවල බිබිලි නිසා ගවයා කොර ගසන්න, පාද ගසන්න සහ වැඩිපුර වැතිරී සිටින්න පුළුවන්."),
    ("KB-203", FMD, "sign", "merck-fmd",
     "FMD often starts with a fever of about 40°C, and the cow's milk yield usually drops.",
     "FMD බොහෝවිට 40°C පමණ උණකින් ආරම්භ වන අතර ගවයාගේ කිරි ප්‍රමාණය අඩු වේ."),
    ("KB-204", FMD, "sign", "merck-fmd",
     "Young calves can sometimes die suddenly from FMD because the virus damages the heart.",
     "FMD වෛරසය හෘදයට හානි කරන නිසා කුඩා වසු පැටවුන් සමහරවිට හදිසියේ මිය යා හැක."),
    ("KB-205", FMD, "treatment", "merck-fmd,fmd-care",
     "No medicine kills the FMD virus. A vet gives supportive care to reduce pain and fever and to stop the sores from getting infected.",
     "FMD වෛරසය නැති කරන බෙහෙතක් නැත. වේදනාව හා උණ අඩු කිරීමටත්, තුවාලවලට ආසාදන ඇතිවීම වැළැක්වීමටත් පශු වෛද්‍යවරයා සහාය ප්‍රතිකාර ලබා දෙයි."),
    ("KB-206", FMD, "care", "fmd-care",
     "Give soft feed and plenty of clean water, keep the mouth and foot sores clean, and keep the animal on dry ground.",
     "මෘදු ආහාර සහ පිරිසිදු වතුර බහුලව දෙන්න; කටේ හා පාදවල තුවාල පිරිසිදුව තබා, සතාව වියළි බිමක තබන්න."),
    ("KB-207", FMD, "care", "merck-fmd",
     "Keep sick animals away from the rest of the herd, and do not move or sell animals during an outbreak.",
     "රෝගී සතුන් රංචුවෙන් වෙන් කර තබන්න; රෝගය පැතිරෙන කාලයේ සතුන් ගෙන යාම හෝ විකිණීම නොකරන්න."),
    ("KB-208", FMD, "prevention", "merck-fmd",
     "FMD vaccines protect for only about 4–6 months against matching virus types, so keep up with the government vaccination programme.",
     "FMD එන්නත් ආරක්ෂාව ලබා දෙන්නේ මාස 4–6ක් පමණ කාලයකට පමණක් බැවින් රජයේ එන්නත් වැඩසටහන නොකඩවා අනුගමනය කරන්න."),
    ("KB-209", FMD, "prevention", "merck-fmd",
     "Report suspected FMD quickly to the government veterinary surgeon; fast reporting is key to stopping an outbreak.",
     "FMD යැයි සැක නම් ඉක්මනින් රජයේ පශු වෛද්‍ය නිලධාරියාට දන්වන්න; ඉක්මන් දැනුම් දීම රෝගය පැතිරීම නැවැත්වීමට වැදගත්ය."),

    # ---- Lumpy Skin Disease ----
    ("KB-211", LSD, "sign", "merck-lsd",
     "Early LSD signs include fever, watery eyes, nasal discharge and drooling, before the skin lumps appear.",
     "සමේ ගැටිති පෙනීමට පෙර උණ, ඇස්වලින් කඳුළු, නාසයෙන් දියර සහ කෙළ හැලීම LSD හි මුල් ලක්ෂණ වේ."),
    ("KB-212", LSD, "sign", "merck-lsd",
     "LSD lumps are round, firm and painful; the cow may eat less and give less milk.",
     "LSD ගැටිති වටකුරු, තද සහ වේදනාකාරී වේ; ගවයා අඩුවෙන් කන්නත්, කිරි අඩුවෙන් දෙන්නත් පුළුවන්."),
    ("KB-213", LSD, "sign", "woah-lsd,merck-lsd",
     "LSD spreads mainly through biting flies, mosquitoes and ticks, and also through contaminated equipment and moving animals.",
     "LSD ප්‍රධාන වශයෙන් පැතිරෙන්නේ ලේ උරා බොන මැස්සන්, මදුරුවන් සහ කිනිතුල්ලන් මගිනි; අපිරිසිදු උපකරණ හා සතුන් ගෙනයාම මගින්ද පැතිරේ."),
    ("KB-214", LSD, "treatment", "merck-lsd",
     "No medicine kills the LSD virus. A vet treats the symptoms and prevents infection of the skin sores, which often makes the disease worse.",
     "LSD වෛරසය නැති කරන බෙහෙතක් නැත. පශු වෛද්‍යවරයා රෝග ලක්ෂණවලට ප්‍රතිකාර කර, බොහෝවිට රෝගය උග්‍ර කරන සමේ තුවාලවල ආසාදන වළක්වයි."),
    ("KB-215", LSD, "care", "merck-lsd,woah-lsd",
     "Keep the sick cow apart from the herd, give feed and clean water, and keep open sores clean and protected from flies.",
     "රෝගී ගවයා රංචුවෙන් වෙන් කර, ආහාර සහ පිරිසිදු වතුර දෙන්න; විවෘත තුවාල පිරිසිදුව තබා මැස්සන්ගෙන් ආරක්ෂා කරන්න."),
    ("KB-216", LSD, "prevention", "woah-lsd",
     "Vaccination is one of the most effective ways to control LSD; ask your government vet about the LSD vaccine.",
     "LSD පාලනයට වඩාත්ම ඵලදායී ක්‍රමයක් එන්නත් කිරීමයි; LSD එන්නත ගැන රජයේ පශු වෛද්‍යවරයාගෙන් විමසන්න."),
    ("KB-217", LSD, "prevention", "woah-lsd",
     "Reduce flies, mosquitoes and ticks around your cattle, and do not bring in animals from affected areas.",
     "ගවයන් අවට මැස්සන්, මදුරුවන් සහ කිනිතුල්ලන් අඩු කරන්න; රෝගය ඇති ප්‍රදේශවලින් සතුන් ගෙන නොඑන්න."),
    ("KB-218", LSD, "prevention", "woah-lsd",
     "Report suspected LSD to the government veterinary office; early detection and movement control are key to stopping it.",
     "LSD යැයි සැක නම් රජයේ පශු වෛද්‍ය කාර්යාලයට දන්වන්න; ඉක්මනින් හඳුනාගැනීම සහ සතුන් ගෙනයාම පාලනය රෝගය නැවැත්වීමට වැදගත්ය."),

    # ---- Mastitis ----
    ("KB-221", MAS, "sign", "merck-mastitis",
     "Severe mastitis can make the whole cow sick, with fever and loss of appetite, not just udder changes.",
     "උග්‍ර Mastitis වලදී බුරුල්ලේ වෙනස්කම් පමණක් නොව, ගවයාට උණ සහ ආහාර අරුචිය ද ඇති විය හැක."),
    ("KB-228", MAS, "sign", "merck-mastitis",
     "Mastitis lowers milk production, even in subclinical cases where the milk and udder look normal.",
     "බුරුලු ප්‍රදාහය නිසා කිරි ප්‍රමාණය අඩු වේ; කිරි හා බුරුල්ල සාමාන්‍ය ලෙස පෙනුණත් ගවයා කිරි අඩුවෙන් දෙන්න පුළුවන්."),
    ("KB-222", MAS, "treatment", "merck-mastitis",
     "A vet can test the milk (for example with the California Mastitis Test or a milk culture) to find the cause and choose the right treatment.",
     "පශු වෛද්‍යවරයාට කිරි පරීක්ෂා කර (උදා: California Mastitis Test හෝ කිරි culture පරීක්ෂාව) හේතුව සොයා නිවැරදි ප්‍රතිකාරය තෝරා ගත හැක."),
    ("KB-223", MAS, "treatment", "merck-mastitis",
     "Mastitis medicine must be prescribed by a vet; milk and meat from a treated cow must not be used until the waiting period the vet gives is over.",
     "Mastitis බෙහෙත් පශු වෛද්‍යවරයෙකු විසින් නියම කළ යුතුය; ප්‍රතිකාර ලබන ගවයාගේ කිරි හා මස් වෛද්‍යවරයා කියන කාලය අවසන් වන තුරු භාවිත නොකළ යුතුය."),
    ("KB-224", MAS, "treatment", "merck-mastitis",
     "If the cow has fever, stops eating or is weak, call a vet urgently; supportive care such as fluids is often the most important part of treatment.",
     "ගවයාට උණ, ආහාර නොගැනීම හෝ දුර්වලතාවය ඇත්නම් වහාම පශු වෛද්‍යවරයාට කතා කරන්න; දියර ලබා දීම වැනි සහාය ප්‍රතිකාර බොහෝවිට වැදගත්ම කොටසයි."),
    ("KB-225", MAS, "prevention", "merck-mastitis",
     "Dipping the teats in a germicide after every milking is the most important way to stop mastitis spreading between cows.",
     "සෑම කිරි දෙවීමකටම පසු තන පුඩු විෂබීජනාශක දියරයක ගිල්වීම ගවයන් අතර Mastitis පැතිරීම නැවැත්වීමට වැදගත්ම ක්‍රමයයි."),
    ("KB-226", MAS, "prevention", "merck-mastitis",
     "Use a separate clean towel for each cow, clean the milking equipment after milking an infected cow, and give cows clean, dry bedding.",
     "එක් එක් ගවයාට වෙනම පිරිසිදු තුවායක් භාවිත කරන්න, ආසාදිත ගවයෙකුට පසු කිරි දොවන උපකරණ පිරිසිදු කරන්න, සහ ගවයන්ට පිරිසිදු වියළි ඇතිරිලි දෙන්න."),
    ("KB-227", MAS, "prevention", "merck-mastitis",
     "Ask your vet about dry cow therapy at the end of lactation; a quarter that keeps getting mastitis may need to be dried off.",
     "කිරි දෙන කාලය අවසානයේ dry cow therapy ගැන පශු වෛද්‍යවරයාගෙන් විමසන්න; නැවත නැවත Mastitis ඇතිවන බුරුල්ලේ කොටසක් වියළීමට සිදු විය හැක."),

    # ---- Ringworm ----
    ("KB-231", RW, "sign", "merck-ringworm",
     "In cows ringworm usually appears on the chest and legs, and in bulls on the dewlap; patches can become thick and crusted.",
     "එළදෙනුන්ට Ringworm බොහෝවිට පපුවේ සහ කකුල්වල ද, ගොනුන්ට ගෙල යට සමේ ද ඇතිවේ; පැල්ලම් ඝන පොතු බවට පත් විය හැක."),
    ("KB-232", RW, "treatment", "merck-ringworm",
     "Ringworm in cattle usually heals by itself with time; a vet may recommend a skin wash, used until the patches heal and no new ones appear.",
     "ගවයන්ගේ Ringworm බොහෝවිට කාලයත් සමඟ ඉබේම සුව වේ; පැල්ලම් සුව වී අලුත් ඒවා ඇති නොවන තුරු භාවිත කිරීමට සමේ සේදුමක් පශු වෛද්‍යවරයා නිර්දේශ කළ හැක."),
    ("KB-233", RW, "care", "merck-ringworm",
     "Brush off crusts carefully, then throw away the brush and burn the crusts, because they spread the fungus. Do not use bleach on the skin.",
     "පොතු ප්‍රවේශමෙන් බුරුසුවකින් ඉවත් කර, බුරුසුව ඉවත දමා පොතු පුළුස්සන්න, මන්ද ඒවා දිලීරය පතුරුවයි. සමට bleach භාවිත නොකරන්න."),
    ("KB-234", RW, "prevention", "merck-ringworm",
     "Avoid overcrowding your animals, because crowding makes ringworm spread more.",
     "සතුන් තදබදයෙන් තැබීම වළක්වන්න, මන්ද තදබදය Ringworm පැතිරීම වැඩි කරයි."),
    ("KB-235", RW, "care", "merck-ringworm",
     "Wear gloves when handling affected animals and wash your hands afterwards, because ringworm can infect people.",
     "Ringworm මිනිසුන්ටත් බෝවිය හැකි නිසා ආසාදිත සතුන් අල්ලන විට අත්වැසුම් පැළඳ, පසුව අත් සෝදන්න."),

    # ---- Emergencies (any cause) ----
    ("KB-241", EM, "urgent", "merck-anthrax",
     "Bleeding from the mouth, nose or other body openings can be a sign of a serious illness such as anthrax. Call a vet immediately.",
     "කටින්, නාසයෙන් හෝ ශරීරයේ වෙනත් විවරවලින් ලේ ඒම anthrax වැනි බරපතල රෝගයක ලක්ෂණයක් විය හැක. වහාම පශු වෛද්‍යවරයෙකුට කතා කරන්න."),
    ("KB-242", EM, "urgent", "merck-anthrax",
     "If a cow dies suddenly, especially with dark blood from the mouth, nose or anus, do not cut the body open. Keep people and animals away and tell the government vet at once; it could be anthrax, which also infects people.",
     "ගවයෙක් හදිසියේ මිය ගියොත්, විශේෂයෙන් කට, නාසය හෝ ගුද මාර්ගයෙන් තද පැහැ ලේ එනවා නම්, මළ සිරුර කපා විවෘත නොකරන්න. මිනිසුන් හා සතුන් ඈත් කර වහාම රජයේ පශු වෛද්‍යවරයාට දන්වන්න; එය මිනිසුන්ටත් බෝවන anthrax විය හැක."),
    ("KB-243", EM, "urgent", "merck-anthrax",
     "A cow that cannot stand, is struggling to breathe, is trembling or collapses needs a vet immediately.",
     "නැගිටින්න බැරි, හුස්ම ගැනීමට අපහසු, වෙව්ලන හෝ ඇද වැටෙන ගවයෙකුට වහාම පශු වෛද්‍ය ප්‍රතිකාර අවශ්‍යයි."),
]


def entries():
    return [{"id": i, "topic": t, "kind": k, "en": en, "si": si, "aspect": "",
             "sources": [SOURCES[s] for s in src.split(",")]}
            for i, t, k, src, en, si in CARE]
