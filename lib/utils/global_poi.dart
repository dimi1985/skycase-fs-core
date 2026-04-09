import 'package:skycase/models/poi.dart';

const List<Poi> globalPoi = [
  ..._greecePoi,
  ..._europePoi,
  ..._middleEastAfricaPoi,
  ..._asiaPoi,
  ..._americasPoi,
  ..._oceaniaPoi,
  ..._weirdPoi,
];

const List<Poi> _greecePoi = [
  Poi(
    id: 'acropolis',
    name: 'Acropolis',
    lat: 37.9715,
    lng: 23.7257,
    type: 'historic',
    country: 'Greece',
    era: '5th century BC',
    shortDescription: 'Ancient hilltop citadel overlooking Athens.',
    description:
        'The Acropolis of Athens is one of the most important monuments of the ancient world. '
        'It was the religious and symbolic heart of classical Athens and is crowned by the Parthenon. '
        'It represents the peak of ancient Greek architecture, civic identity, and devotion to Athena.',
  ),
  Poi(
    id: 'meteora',
    name: 'Meteora',
    lat: 39.7217,
    lng: 21.6300,
    type: 'historic',
    country: 'Greece',
    era: '14th century monasteries',
    shortDescription: 'Monasteries suspended on towering rock pillars.',
    description:
        'Meteora is a dramatic rock formation in central Greece famous for its monasteries built high above the ground. '
        'The site became a major center of Orthodox monastic life and remains one of the most visually striking religious landscapes in the world.',
  ),
  Poi(
    id: 'mount_athos',
    name: 'Mount Athos',
    lat: 40.1587,
    lng: 24.3265,
    type: 'historic',
    country: 'Greece',
    era: 'Byzantine to present',
    shortDescription: 'Autonomous monastic peninsula and spiritual center.',
    description:
        'Mount Athos is a self-governed monastic peninsula in northern Greece and one of the most important centers of Orthodox Christianity. '
        'Its monasteries preserve centuries of spiritual, artistic, and manuscript tradition.',
  ),
  Poi(
    id: 'knossos',
    name: 'Knossos',
    lat: 35.2989,
    lng: 25.1632,
    type: 'historic',
    country: 'Greece',
    era: 'Bronze Age',
    shortDescription: 'Major center of the Minoan civilization in Crete.',
    description:
        'Knossos was one of the largest Bronze Age settlements in the Aegean and is strongly associated with the Minoan civilization. '
        'It is often linked with the legend of the Labyrinth and King Minos.',
  ),
  Poi(
    id: 'santorini_caldera',
    name: 'Santorini Caldera',
    lat: 36.3932,
    lng: 25.4615,
    type: 'natural',
    country: 'Greece',
    era: 'Volcanic formation',
    shortDescription: 'Volcanic caldera with steep cliffs and island villages.',
    description:
        'Santorini’s caldera was formed by one of the most famous volcanic eruptions in the ancient world. '
        'Its cliffs, sea-filled crater, and whitewashed settlements make it one of the most recognizable landscapes in the Mediterranean.',
  ),
  Poi(
    id: 'delphi',
    name: 'Delphi',
    lat: 38.4824,
    lng: 22.5010,
    type: 'historic',
    country: 'Greece',
    era: 'Ancient Greece',
    shortDescription: 'Sanctuary of Apollo and home of the famous oracle.',
    description:
        'Delphi was one of the most sacred places in the ancient Greek world. '
        'It was believed to be the center of the world and was renowned for the Oracle of Apollo, consulted by cities and rulers.',
  ),
  Poi(
    id: 'olympia',
    name: 'Olympia',
    lat: 37.6383,
    lng: 21.6300,
    type: 'historic',
    country: 'Greece',
    era: 'Ancient Greece',
    shortDescription: 'Birthplace of the ancient Olympic Games.',
    description:
        'Olympia was a major religious sanctuary dedicated to Zeus and the site of the ancient Olympic Games. '
        'Its stadium and temple ruins remain deeply tied to the history of athletics and Greek religion.',
  ),
];

const List<Poi> _europePoi = [
  Poi(
    id: 'colosseum',
    name: 'Colosseum',
    lat: 41.8902,
    lng: 12.4922,
    type: 'historic',
    country: 'Italy',
    era: '1st century AD',
    shortDescription: 'Massive Roman amphitheater in the heart of Rome.',
    description:
        'The Colosseum is the largest ancient amphitheater ever built and a symbol of imperial Rome. '
        'It hosted gladiatorial contests, spectacles, and public events for thousands of spectators.',
  ),
  Poi(
    id: 'venice',
    name: 'Venice',
    lat: 45.4408,
    lng: 12.3155,
    type: 'landmark',
    country: 'Italy',
    era: 'Medieval to modern',
    shortDescription: 'Canal city built across islands in a lagoon.',
    description:
        'Venice developed as a maritime republic and became one of the most distinctive urban landscapes in Europe. '
        'Its canals, bridges, and historic buildings make it world-famous.',
  ),
  Poi(
    id: 'leaning_tower_pisa',
    name: 'Leaning Tower of Pisa',
    lat: 43.7229,
    lng: 10.3966,
    type: 'landmark',
    country: 'Italy',
    era: 'Medieval',
    shortDescription: 'Famous bell tower known for its lean.',
    description:
        'The Leaning Tower of Pisa is one of the most recognizable architectural landmarks in Europe. '
        'Its unintended tilt turned it into a global icon.',
  ),
  Poi(
    id: 'eiffel_tower',
    name: 'Eiffel Tower',
    lat: 48.8584,
    lng: 2.2945,
    type: 'landmark',
    country: 'France',
    era: '1889',
    shortDescription: 'Iconic iron tower built for the Paris Exposition.',
    description:
        'The Eiffel Tower was constructed for the 1889 World’s Fair and became one of the most recognizable landmarks in the world. '
        'Originally controversial, it later became the defining symbol of Paris.',
  ),
  Poi(
    id: 'mont_saint_michel',
    name: 'Mont-Saint-Michel',
    lat: 48.6360,
    lng: -1.5115,
    type: 'historic',
    country: 'France',
    era: 'Medieval',
    shortDescription: 'Tidal island abbey rising above coastal flats.',
    description:
        'Mont-Saint-Michel is a fortified island commune crowned by a medieval abbey. '
        'Its striking silhouette and changing tides make it one of France’s most memorable historic sites.',
  ),
  Poi(
    id: 'neuschwanstein',
    name: 'Neuschwanstein Castle',
    lat: 47.5576,
    lng: 10.7498,
    type: 'landmark',
    country: 'Germany',
    era: '19th century',
    shortDescription: 'Romantic hilltop castle in Bavaria.',
    description:
        'Neuschwanstein Castle was commissioned by King Ludwig II of Bavaria and became one of the world’s best-known castle images. '
        'Its dramatic setting helped inspire later fantasy architecture.',
  ),
  Poi(
    id: 'brandenburg_gate',
    name: 'Brandenburg Gate',
    lat: 52.5163,
    lng: 13.3777,
    type: 'historic',
    country: 'Germany',
    era: '18th century',
    shortDescription: 'Monumental gate and symbol of Berlin.',
    description:
        'The Brandenburg Gate is one of Germany’s best-known national symbols. '
        'It has stood through monarchy, division, and reunification, becoming tied to modern European history.',
  ),
  Poi(
    id: 'stonehenge',
    name: 'Stonehenge',
    lat: 51.1789,
    lng: -1.8262,
    type: 'historic',
    country: 'United Kingdom',
    era: 'Prehistoric',
    shortDescription: 'Ancient stone circle on Salisbury Plain.',
    description:
        'Stonehenge is one of the most famous prehistoric monuments in the world. '
        'Its massive standing stones and uncertain original purpose continue to attract archaeological and public fascination.',
  ),
  Poi(
    id: 'tower_bridge',
    name: 'Tower Bridge',
    lat: 51.5055,
    lng: -0.0754,
    type: 'landmark',
    country: 'United Kingdom',
    era: '1894',
    shortDescription: 'Iconic bascule bridge over the Thames.',
    description:
        'Tower Bridge is one of London’s most recognizable structures. '
        'Its combined suspension and bascule design allowed river traffic and city traffic to coexist.',
  ),
  Poi(
    id: 'sagrada_familia',
    name: 'Sagrada Família',
    lat: 41.4036,
    lng: 2.1744,
    type: 'historic',
    country: 'Spain',
    era: '1882 to present',
    shortDescription: 'Monumental basilica associated with Antoni Gaudí.',
    description:
        'The Sagrada Família is one of the most famous churches in the world and one of Barcelona’s defining landmarks. '
        'Its complex facades and towers reflect Gaudí’s unique architectural imagination.',
  ),
  Poi(
    id: 'alhambra',
    name: 'Alhambra',
    lat: 37.1761,
    lng: -3.5881,
    type: 'historic',
    country: 'Spain',
    era: 'Medieval',
    shortDescription: 'Palace and fortress complex overlooking Granada.',
    description:
        'The Alhambra was the seat of Nasrid rulers in Granada and remains one of the finest surviving examples of Islamic architecture in Europe. '
        'Its courtyards, halls, and defensive walls dominate the city skyline.',
  ),
  Poi(
    id: 'matterhorn',
    name: 'Matterhorn',
    lat: 45.9763,
    lng: 7.6586,
    type: 'natural',
    country: 'Switzerland / Italy',
    era: 'Natural formation',
    shortDescription: 'Pyramidal alpine peak on the Swiss-Italian border.',
    description:
        'The Matterhorn is one of the most iconic mountains in the Alps. '
        'Its sharp profile has made it a symbol of alpine climbing and European mountain scenery.',
  ),
  Poi(
    id: 'hagia_sophia',
    name: 'Hagia Sophia',
    lat: 41.0086,
    lng: 28.9802,
    type: 'historic',
    country: 'Turkey',
    era: '6th century',
    shortDescription: 'Monumental domed structure of Byzantine origin.',
    description:
        'Hagia Sophia is one of the most influential buildings in architectural history. '
        'Originally built as a cathedral in Constantinople, it later served other roles while remaining a symbol of the city.',
  ),
  Poi(
    id: 'cappadocia',
    name: 'Cappadocia',
    lat: 38.6431,
    lng: 34.8270,
    type: 'natural',
    country: 'Turkey',
    era: 'Natural formation / ancient settlement',
    shortDescription: 'Rock valleys, cave dwellings, and fairy chimneys.',
    description:
        'Cappadocia is famous for its unusual volcanic rock formations and long history of cave habitation. '
        'Its valleys and carved churches create one of the most distinctive landscapes in the region.',
  ),
];

const List<Poi> _middleEastAfricaPoi = [
  Poi(
    id: 'pyramids_giza',
    name: 'Pyramids of Giza',
    lat: 29.9792,
    lng: 31.1342,
    type: 'historic',
    country: 'Egypt',
    era: 'Old Kingdom',
    shortDescription: 'Ancient royal tombs on the Giza Plateau.',
    description:
        'The Pyramids of Giza are among the oldest and most astonishing surviving monuments of the ancient world. '
        'Built as monumental tombs for pharaohs, they remain a symbol of ancient Egyptian engineering and state power.',
  ),
  Poi(
    id: 'abu_simbel',
    name: 'Abu Simbel',
    lat: 22.3372,
    lng: 31.6258,
    type: 'historic',
    country: 'Egypt',
    era: '13th century BC',
    shortDescription: 'Rock temples associated with Ramesses II.',
    description:
        'Abu Simbel is famous for its colossal statues and temple facades cut into rock. '
        'It is also notable for its modern relocation to protect it from flooding.',
  ),
  Poi(
    id: 'petra',
    name: 'Petra',
    lat: 30.3285,
    lng: 35.4444,
    type: 'historic',
    country: 'Jordan',
    era: 'Nabataean',
    shortDescription: 'Rock-cut city hidden in desert canyons.',
    description:
        'Petra was the capital of the Nabataean Kingdom and is famous for its rock-cut architecture and water engineering. '
        'Its treasury facade and canyon entrances make it one of the most dramatic archaeological sites in the world.',
  ),
  Poi(
    id: 'jerusalem_old_city',
    name: 'Old City of Jerusalem',
    lat: 31.7767,
    lng: 35.2345,
    type: 'historic',
    country: 'Israel / Palestine',
    era: 'Ancient to present',
    shortDescription: 'Historic walled city of immense religious significance.',
    description:
        'The Old City of Jerusalem contains sacred sites central to Judaism, Christianity, and Islam. '
        'Its dense concentration of history, devotion, and conflict makes it one of the world’s most important urban sacred landscapes.',
  ),
  Poi(
    id: 'mecca',
    name: 'Mecca',
    lat: 21.4225,
    lng: 39.8262,
    type: 'historic',
    country: 'Saudi Arabia',
    era: 'Ancient to present',
    shortDescription: 'Sacred city at the heart of Islamic pilgrimage.',
    description:
        'Mecca is the holiest city in Islam and the destination of the Hajj pilgrimage. '
        'It has held central religious significance for centuries.',
  ),
  Poi(
    id: 'mount_sinai',
    name: 'Mount Sinai',
    lat: 28.5394,
    lng: 33.9750,
    type: 'historic',
    country: 'Egypt',
    era: 'Biblical tradition',
    shortDescription: 'Mountain associated with biblical tradition.',
    description:
        'Mount Sinai is traditionally associated with the biblical account of Moses receiving the Law. '
        'Its religious importance has made it a place of pilgrimage for centuries.',
  ),
  Poi(
    id: 'lalibela',
    name: 'Lalibela',
    lat: 12.0317,
    lng: 39.0476,
    type: 'historic',
    country: 'Ethiopia',
    era: 'Medieval',
    shortDescription: 'Rock-hewn churches of the Ethiopian highlands.',
    description:
        'Lalibela is famous for its monolithic churches carved directly into rock. '
        'It remains one of the most important Christian pilgrimage centers in Africa.',
  ),
  Poi(
    id: 'table_mountain',
    name: 'Table Mountain',
    lat: -33.9628,
    lng: 18.4098,
    type: 'natural',
    country: 'South Africa',
    era: 'Natural formation',
    shortDescription: 'Flat-topped mountain dominating Cape Town.',
    description:
        'Table Mountain is one of South Africa’s most recognizable natural landmarks. '
        'Its broad summit and dramatic rise above the city and coast make it visually distinctive.',
  ),
  Poi(
    id: 'victoria_falls',
    name: 'Victoria Falls',
    lat: -17.9243,
    lng: 25.8560,
    type: 'natural',
    country: 'Zambia / Zimbabwe',
    era: 'Natural formation',
    shortDescription: 'Immense waterfall on the Zambezi River.',
    description:
        'Victoria Falls is one of the largest and most spectacular waterfalls in the world. '
        'Its immense width and spray have made it a major landmark of southern Africa.',
  ),
  Poi(
    id: 'kilimanjaro',
    name: 'Mount Kilimanjaro',
    lat: -3.0674,
    lng: 37.3556,
    type: 'natural',
    country: 'Tanzania',
    era: 'Natural formation',
    shortDescription: 'Africa’s highest mountain and volcanic massif.',
    description:
        'Mount Kilimanjaro rises prominently above the East African plains and is the continent’s highest peak. '
        'Its snow-capped summit became one of Africa’s most iconic natural images.',
  ),
  Poi(
    id: 'sahara_erg',
    name: 'Sahara Dunes',
    lat: 23.4162,
    lng: 25.6628,
    type: 'natural',
    country: 'North Africa',
    era: 'Natural formation',
    shortDescription: 'Vast desert dune fields of the Sahara.',
    description:
        'The Sahara is the largest hot desert in the world and one of the defining landscapes of Africa. '
        'Its dune seas, plateaus, and harsh conditions have shaped trade routes and imagination alike.',
  ),
];

const List<Poi> _asiaPoi = [
  Poi(
    id: 'great_wall',
    name: 'Great Wall of China',
    lat: 40.4319,
    lng: 116.5704,
    type: 'historic',
    country: 'China',
    era: 'Ancient / Imperial periods',
    shortDescription: 'Fortified wall system stretching across northern China.',
    description:
        'The Great Wall is a vast system of fortifications built and rebuilt across centuries to defend northern Chinese states and empires. '
        'It stands as one of the largest construction efforts in human history.',
  ),
  Poi(
    id: 'forbidden_city',
    name: 'Forbidden City',
    lat: 39.9163,
    lng: 116.3972,
    type: 'historic',
    country: 'China',
    era: 'Ming and Qing dynasties',
    shortDescription: 'Imperial palace complex in central Beijing.',
    description:
        'The Forbidden City served as the ceremonial and political heart of imperial China for centuries. '
        'Its scale, symmetry, and preservation make it one of the world’s great palace complexes.',
  ),
  Poi(
    id: 'taj_mahal',
    name: 'Taj Mahal',
    lat: 27.1751,
    lng: 78.0421,
    type: 'historic',
    country: 'India',
    era: '17th century',
    shortDescription: 'Marble mausoleum built on the Yamuna River.',
    description:
        'The Taj Mahal is one of the world’s most famous architectural monuments. '
        'It is celebrated for its symmetry, white marble surfaces, and enduring association with remembrance and imperial artistry.',
  ),
  Poi(
    id: 'varanasi',
    name: 'Varanasi',
    lat: 25.3176,
    lng: 82.9739,
    type: 'historic',
    country: 'India',
    era: 'Ancient to present',
    shortDescription: 'Ancient sacred city on the Ganges.',
    description:
        'Varanasi is one of the oldest continuously inhabited cities in the world and one of Hinduism’s most sacred centers. '
        'Its ghats, temples, and riverfront rituals give it a unique spiritual identity.',
  ),
  Poi(
    id: 'mount_fuji',
    name: 'Mount Fuji',
    lat: 35.3606,
    lng: 138.7274,
    type: 'natural',
    country: 'Japan',
    era: 'Natural formation',
    shortDescription: 'Japan’s iconic volcanic peak.',
    description:
        'Mount Fuji is Japan’s highest mountain and one of the country’s most important cultural and visual symbols. '
        'Its symmetrical form has inspired art, devotion, and travel for centuries.',
  ),
  Poi(
    id: 'fushimi_inari',
    name: 'Fushimi Inari Shrine',
    lat: 34.9671,
    lng: 135.7727,
    type: 'historic',
    country: 'Japan',
    era: 'Ancient to present',
    shortDescription: 'Shrine famous for tunnels of red torii gates.',
    description:
        'Fushimi Inari is one of Kyoto’s most famous sacred sites. '
        'Its long paths lined with torii gates create one of Japan’s most recognizable religious landscapes.',
  ),
  Poi(
    id: 'angkor_wat',
    name: 'Angkor Wat',
    lat: 13.4125,
    lng: 103.8670,
    type: 'historic',
    country: 'Cambodia',
    era: '12th century',
    shortDescription: 'Monumental temple complex of the Khmer Empire.',
    description:
        'Angkor Wat is one of the largest religious monuments in the world. '
        'Its towers, galleries, and bas-reliefs make it the defining masterpiece of Khmer architecture.',
  ),
  Poi(
    id: 'ha_long_bay',
    name: 'Hạ Long Bay',
    lat: 20.9101,
    lng: 107.1839,
    type: 'natural',
    country: 'Vietnam',
    era: 'Natural formation',
    shortDescription: 'Bay scattered with limestone islands and pillars.',
    description:
        'Hạ Long Bay is renowned for its dense concentration of limestone karsts rising from the sea. '
        'Its scenery has made it one of Southeast Asia’s most famous natural destinations.',
  ),
  Poi(
    id: 'borobudur',
    name: 'Borobudur',
    lat: -7.6079,
    lng: 110.2038,
    type: 'historic',
    country: 'Indonesia',
    era: '8th–9th century',
    shortDescription: 'Massive Buddhist monument of layered terraces.',
    description:
        'Borobudur is one of the greatest Buddhist monuments in the world. '
        'Its sculpted galleries and rising terraces form a monumental sacred mountain in stone.',
  ),
  Poi(
    id: 'mount_everest',
    name: 'Mount Everest',
    lat: 27.9881,
    lng: 86.9250,
    type: 'natural',
    country: 'Nepal / China',
    era: 'Natural formation',
    shortDescription: 'Highest mountain on Earth above sea level.',
    description:
        'Mount Everest is the highest peak on Earth and a global symbol of extreme altitude and mountaineering challenge. '
        'It dominates the Himalayas and has drawn climbers, explorers, and scientists for generations.',
  ),
  Poi(
    id: 'dead_sea',
    name: 'Dead Sea',
    lat: 31.5590,
    lng: 35.4732,
    type: 'natural',
    country: 'Jordan / Israel / Palestine',
    era: 'Natural formation',
    shortDescription: 'Salt lake famous for extreme salinity.',
    description:
        'The Dead Sea is one of the saltiest bodies of water on Earth and lies in a deep tectonic depression. '
        'Its mineral-rich waters and unique buoyancy made it globally famous.',
  ),
];

const List<Poi> _americasPoi = [
  Poi(
    id: 'statue_liberty',
    name: 'Statue of Liberty',
    lat: 40.6892,
    lng: -74.0445,
    type: 'landmark',
    country: 'United States',
    era: '1886',
    shortDescription: 'Colossal statue symbolizing liberty and arrival.',
    description:
        'The Statue of Liberty was a gift from France and became a defining symbol of freedom, immigration, and New York Harbor. '
        'For many arrivals by sea, it was their first great sight of America.',
  ),
  Poi(
    id: 'grand_canyon',
    name: 'Grand Canyon',
    lat: 36.1069,
    lng: -112.1129,
    type: 'natural',
    country: 'United States',
    era: 'Natural formation',
    shortDescription: 'Immense canyon carved by the Colorado River.',
    description:
        'The Grand Canyon is one of the world’s most famous geological landscapes. '
        'Its vast scale and exposed rock layers reveal a remarkable cross-section of Earth’s history.',
  ),
  Poi(
    id: 'yellowstone',
    name: 'Yellowstone',
    lat: 44.4280,
    lng: -110.5885,
    type: 'natural',
    country: 'United States',
    era: 'Natural formation',
    shortDescription: 'Geothermal park of geysers and volcanic features.',
    description:
        'Yellowstone is famous for its geysers, hot springs, wildlife, and underlying volcanic system. '
        'It helped define the modern idea of a national park.',
  ),
  Poi(
    id: 'mount_rushmore',
    name: 'Mount Rushmore',
    lat: 43.8791,
    lng: -103.4591,
    type: 'landmark',
    country: 'United States',
    era: '20th century',
    shortDescription: 'Mountain sculpture of four U.S. presidents.',
    description:
        'Mount Rushmore is one of the most recognizable monumental sculptures in the United States. '
        'Its carved presidential faces made it a powerful national symbol.',
  ),
  Poi(
    id: 'machu_picchu',
    name: 'Machu Picchu',
    lat: -13.1631,
    lng: -72.5450,
    type: 'historic',
    country: 'Peru',
    era: '15th century',
    shortDescription: 'Inca mountaintop citadel above the Urubamba Valley.',
    description:
        'Machu Picchu is a remarkably preserved Inca site built high in the Andes. '
        'Its terraces, stonework, and dramatic setting have made it one of the most celebrated archaeological destinations on Earth.',
  ),
  Poi(
    id: 'christ_redeemer',
    name: 'Christ the Redeemer',
    lat: -22.9519,
    lng: -43.2105,
    type: 'landmark',
    country: 'Brazil',
    era: '1931',
    shortDescription: 'Monumental statue overlooking Rio de Janeiro.',
    description:
        'Christ the Redeemer stands atop Corcovado Mountain and is one of the most recognized landmarks in South America. '
        'Its elevated setting gives it a commanding presence over Rio.',
  ),
  Poi(
    id: 'iguazu_falls',
    name: 'Iguazu Falls',
    lat: -25.6953,
    lng: -54.4367,
    type: 'natural',
    country: 'Argentina / Brazil',
    era: 'Natural formation',
    shortDescription: 'Massive waterfall system in subtropical forest.',
    description:
        'Iguazu Falls consists of hundreds of cascades spread across a wide frontier zone. '
        'Its size, roar, and surrounding forest make it one of the great waterfall landscapes of the world.',
  ),
  Poi(
    id: 'chichen_itza',
    name: 'Chichén Itzá',
    lat: 20.6843,
    lng: -88.5678,
    type: 'historic',
    country: 'Mexico',
    era: 'Maya civilization',
    shortDescription: 'Major Maya city with iconic stepped pyramid.',
    description:
        'Chichén Itzá was a major political and ceremonial center of the Maya world. '
        'Its pyramid, observatory, and ball court made it one of Mesoamerica’s best-known archaeological sites.',
  ),
  Poi(
    id: 'teotihuacan',
    name: 'Teotihuacán',
    lat: 19.6925,
    lng: -98.8439,
    type: 'historic',
    country: 'Mexico',
    era: 'Ancient Mesoamerica',
    shortDescription: 'Ancient city of monumental avenues and pyramids.',
    description:
        'Teotihuacán was one of the largest cities of the ancient world. '
        'Its Pyramid of the Sun, Pyramid of the Moon, and broad ceremonial avenues remain deeply impressive.',
  ),
  Poi(
    id: 'banff',
    name: 'Banff National Park',
    lat: 51.4968,
    lng: -115.9281,
    type: 'natural',
    country: 'Canada',
    era: 'Natural formation',
    shortDescription: 'Rocky Mountain park of peaks, forests, and lakes.',
    description:
        'Banff National Park is one of Canada’s most celebrated mountain landscapes. '
        'It is known for glacier-fed lakes, dramatic peaks, and alpine scenery.',
  ),
  Poi(
    id: 'niagara_falls',
    name: 'Niagara Falls',
    lat: 43.0896,
    lng: -79.0849,
    type: 'natural',
    country: 'Canada / United States',
    era: 'Natural formation',
    shortDescription: 'Powerful falls on the Niagara River.',
    description:
        'Niagara Falls is one of the most famous waterfall systems in the world. '
        'Its power, visibility, and border location helped make it a major landmark in North America.',
  ),
  Poi(
    id: 'uyuni',
    name: 'Salar de Uyuni',
    lat: -20.1338,
    lng: -67.4891,
    type: 'natural',
    country: 'Bolivia',
    era: 'Natural formation',
    shortDescription: 'Immense salt flat known for mirror-like reflections.',
    description:
        'Salar de Uyuni is the world’s largest salt flat and one of South America’s most surreal landscapes. '
        'When covered by shallow water, it creates enormous sky reflections.',
  ),
];

const List<Poi> _oceaniaPoi = [
  Poi(
    id: 'uluru',
    name: 'Uluru',
    lat: -25.3444,
    lng: 131.0369,
    type: 'natural',
    country: 'Australia',
    era: 'Natural formation',
    shortDescription: 'Massive sandstone monolith rising from the desert.',
    description:
        'Uluru is one of Australia’s most iconic natural landmarks. '
        'It is notable for its scale, changing colors in different light, and deep cultural significance to the local Anangu people.',
  ),
  Poi(
    id: 'great_barrier_reef',
    name: 'Great Barrier Reef',
    lat: -18.2871,
    lng: 147.6992,
    type: 'natural',
    country: 'Australia',
    era: 'Natural formation',
    shortDescription: 'World-famous coral reef system off Queensland.',
    description:
        'The Great Barrier Reef is the largest coral reef system on Earth. '
        'Its scale, biodiversity, and visibility from space make it one of the planet’s great natural features.',
  ),
  Poi(
    id: 'sydney_opera_house',
    name: 'Sydney Opera House',
    lat: -33.8568,
    lng: 151.2153,
    type: 'landmark',
    country: 'Australia',
    era: '1973',
    shortDescription: 'Harbourfront performing arts landmark with sail-like roofs.',
    description:
        'The Sydney Opera House is one of the most recognizable modern buildings in the world. '
        'Its setting on Sydney Harbour and bold roof forms made it a defining Australian icon.',
  ),
  Poi(
    id: 'milford_sound',
    name: 'Milford Sound',
    lat: -44.6718,
    lng: 167.9256,
    type: 'natural',
    country: 'New Zealand',
    era: 'Natural formation',
    shortDescription: 'Dramatic fiord surrounded by steep cliffs and rainforests.',
    description:
        'Milford Sound is one of New Zealand’s most celebrated landscapes. '
        'Its dark waters, waterfalls, and towering cliffs create a powerful fiord environment.',
  ),
  Poi(
    id: 'aoraki',
    name: 'Aoraki / Mount Cook',
    lat: -43.5950,
    lng: 170.1418,
    type: 'natural',
    country: 'New Zealand',
    era: 'Natural formation',
    shortDescription: 'Highest mountain in New Zealand.',
    description:
        'Aoraki / Mount Cook is the highest peak in New Zealand and a central landmark of the Southern Alps. '
        'It has long been associated with alpine climbing and national identity.',
  ),
];

const List<Poi> _weirdPoi = [
  Poi(
    id: 'bermuda_triangle',
    name: 'Bermuda Triangle',
    lat: 25.0000,
    lng: -71.0000,
    type: 'weird',
    country: 'Atlantic Ocean',
    era: 'Modern legend',
    shortDescription: 'Region associated with maritime mystery folklore.',
    description:
        'The Bermuda Triangle is a popularly named region in the western North Atlantic associated with legends about disappearances of ships and aircraft. '
        'Its fame comes more from modern myth, speculation, and pop culture than from a single historical event.',
  ),
  Poi(
    id: 'point_nemo',
    name: 'Point Nemo',
    lat: -48.8767,
    lng: -123.3933,
    type: 'weird',
    country: 'South Pacific Ocean',
    era: 'Geographic designation',
    shortDescription: 'Most remote point in the ocean from any landmass.',
    description:
        'Point Nemo is the oceanic pole of inaccessibility, the location in the sea farthest from any land. '
        'It is known for its isolation and has even been used as a remote spacecraft cemetery zone nearby.',
  ),
  Poi(
    id: 'devils_sea',
    name: 'Devil’s Sea',
    lat: 35.0000,
    lng: 145.0000,
    type: 'weird',
    country: 'Pacific Ocean',
    era: 'Modern legend',
    shortDescription: 'Pacific region associated with nautical mystery stories.',
    description:
        'The Devil’s Sea is a loosely described region near Japan that appears in stories about strange disappearances and maritime anomalies. '
        'Like similar mystery zones, its fame owes much to modern legend and speculation.',
  ),
  Poi(
    id: 'nazca_lines',
    name: 'Nazca Lines',
    lat: -14.7390,
    lng: -75.1300,
    type: 'weird',
    country: 'Peru',
    era: 'Ancient',
    shortDescription: 'Giant geoglyphs etched into the desert floor.',
    description:
        'The Nazca Lines are enormous ground drawings in southern Peru depicting geometric forms, animals, and plants. '
        'Their scale and visibility from the air have fueled both archaeological interest and public mystery.',
  ),
  Poi(
    id: 'easter_island',
    name: 'Easter Island',
    lat: -27.1127,
    lng: -109.3497,
    type: 'weird',
    country: 'Chile',
    era: 'Polynesian settlement',
    shortDescription: 'Remote Pacific island known for moai statues.',
    description:
        'Easter Island is one of the most isolated inhabited islands in the world and is famous for its monumental moai statues. '
        'Its remoteness and archaeological legacy give it an enduring aura of mystery.',
  ),
];