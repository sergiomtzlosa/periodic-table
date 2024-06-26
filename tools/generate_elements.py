#!/usr/bin/env python3
"""
generate_elements.py — source of truth for the PeriodicTable app's element data.

Emits PeriodicTable/Resources/elements.json.

Row format (pipe separated, 21 fields):

  n | sym | name | mass | category | group | period | fblock | config |
  en | radius(pm) | covalent(pm) | melt(K) | boil(K) | density | phase |
  year | discoverer | molecule | uses(; separated) | summary

'-' means "unknown" and becomes JSON null.  The script validates every row and
derives the electron-shell populations from the electron configuration string.
"""

import json
import os
import re
import sys

CATEGORIES = [
    "alkali-metal", "alkaline-earth-metal", "transition-metal",
    "post-transition-metal", "metalloid", "reactive-nonmetal", "halogen",
    "noble-gas", "lanthanide", "actinide", "unknown",
]

# number|symbol|name|mass|category|group|period|fblock|config|en|radius|cov|melt|boil|density|phase|year|who|molecule|uses|summary
ROWS = """
1|H|Hydrogen|1.008|reactive-nonmetal|1|1|0|1s1|2.20|53|31|13.99|20.271|0.00008988|Gas|1766|Henry Cavendish|water|Fuel;Rocket propellant;Ammonia synthesis|Lightest element and most abundant in the universe.
2|He|Helium|4.0026|noble-gas|18|1|0|1s2|-|31|28|0.95|4.222|0.0001785|Gas|1868|Janssen and Lockyer|neon|Cryogenics;Balloons;MRI cooling|Second most abundant element, entirely inert.
3|Li|Lithium|6.94|alkali-metal|1|2|0|1s2 2s1|0.98|167|128|453.65|1603|0.534|Solid|1817|Johan August Arfwedson|licl|Battery anodes;Mood stabiliser;Aluminium smelting|Lightest metal, used in rechargeable batteries.
4|Be|Beryllium|9.0122|alkaline-earth-metal|2|2|0|1s2 2s2|1.57|112|96|1560|2742|1.85|Solid|1798|Louis-Nicolas Vauquelin|becl2|Aerospace alloys;X-ray windows;Electron targets|Toxic light metal used in aerospace alloys.
5|B|Boron|10.81|metalloid|13|2|0|1s2 2s2 2p1|2.04|87|84|2349|4200|2.34|Solid|1808|Davy, Gay-Lussac and Thenard|bf3|Glass and ceramics;Neutron shielding;Semiconductors|Essential micronutrient for all plant life.
6|C|Carbon|12.011|reactive-nonmetal|14|2|0|1s2 2s2 2p2|2.55|67|76|3823|4098|2.267|Solid|Ancient|Known to the ancients|methane|Steelmaking;Diamond;Photosynthesis;Organic chemistry|Backbone of all organic chemistry.
7|N|Nitrogen|14.007|reactive-nonmetal|15|2|0|1s2 2s2 2p3|3.04|56|71|63.15|77.355|0.0012506|Gas|1772|Daniel Rutherford|ammonia|Fertiliser;Inert gas;Cryopreservation|78 percent of Earth's atmosphere by volume.
8|O|Oxygen|15.999|reactive-nonmetal|16|2|0|1s2 2s2 2p4|3.44|48|66|54.36|90.188|0.001429|Gas|1771|Carl Wilhelm Scheele|water|Respiration;Steelmaking;Medical oxygen|Essential to respiration and combustion.
9|F|Fluorine|18.998|halogen|17|2|0|1s2 2s2 2p5|3.98|42|57|53.48|85.03|0.001696|Gas|1886|Henri Moissan|bf3|Toothpaste;Fluorochemicals;Reactor uranium enrichment|Most electronegative and most reactive of all elements.
10|Ne|Neon|20.180|noble-gas|18|2|0|1s2 2s2 2p6|-|38|58|24.56|27.104|0.0008999|Gas|1898|Ramsay and Travers|neon|Neon signs;Cryogenics;Excited lamps|Inert gas that glows orange-red in discharge tubes.
11|Na|Sodium|22.990|alkali-metal|1|3|0|1s2 2s2 2p6 3s1|0.93|190|166|370.94|1156.09|0.968|Solid|1807|Humphry Davy|nacl|Table salt;Sodium vapour lamps;Heat transfer|Soft metal that reacts violently with water.
12|Mg|Magnesium|24.305|alkaline-earth-metal|2|3|0|1s2 2s2 2p6 3s2|1.31|145|141|923|1363|1.738|Solid|1755|Joseph Black|mgcl2|Light alloys;Flares;Antacids|Burns with a brilliant white flame.
13|Al|Aluminium|26.982|post-transition-metal|13|3|0|1s2 2s2 2p6 3s2 3p1|1.61|118|121|933.47|2743|2.70|Solid|1825|Hans Christian Orsted|alcl3|Cans;Aerospace;Heat exchangers|Light, corrosion-resistant and highly recyclable metal.
14|Si|Silicon|28.085|metalloid|14|3|0|1s2 2s2 2p6 3s2 3p2|1.90|111|111|1687|3538|2.3296|Solid|1824|Jons Jacob Berzelius|sio2|Semiconductors;Glass;Silicones|Foundation of the modern electronics industry.
15|P|Phosphorus|30.974|reactive-nonmetal|15|3|0|1s2 2s2 2p6 3s2 3p3|2.19|98|107|317.3|550|1.823|Solid|1669|Hennig Brand|p4|Fertiliser;Matches;Detergents|Essential for DNA, ATP and life itself.
16|S|Sulfur|32.06|reactive-nonmetal|16|3|0|1s2 2s2 2p6 3s2 3p4|2.58|88|105|388.36|717.8|2.07|Solid|Ancient|Known to the ancients|h2so4|Fertiliser;Sulphuric acid;Vulcanised rubber|Forms the yellow crystals of native sulphur.
17|Cl|Chlorine|35.45|halogen|17|3|0|1s2 2s2 2p6 3s2 3p5|3.16|79|102|171.6|239.11|0.003214|Gas|1774|Carl Wilhelm Scheele|nacl|Water treatment;PVC;Bleach|Green-yellow gas that disinfects drinking water.
18|Ar|Argon|39.948|noble-gas|18|3|0|1s2 2s2 2p6 3s2 3p6|-|71|106|83.81|87.302|0.001784|Gas|1894|Lord Rayleigh and Ramsay|argon|Shielding gas;Light bulbs;Welding|Cheapest of the noble gases, most used in industry.
19|K|Potassium|39.098|alkali-metal|1|4|0|1s2 2s2 2p6 3s2 3p6 4s1|0.82|243|203|336.53|1032|0.862|Solid|1807|Humphry Davy|kcl|Fertiliser;Soaps;Batteries|Soft metal with the lowest density of any metal.
20|Ca|Calcium|40.078|alkaline-earth-metal|2|4|0|1s2 2s2 2p6 3s2 3p6 4s2|1.00|194|176|1115|1757|1.55|Solid|1808|Humphry Davy|caco3|Limestone;Cement;Plaster|Structural metal of bones, teeth and limestone.
21|Sc|Scandium|44.956|transition-metal|3|4|0|1s2 2s2 2p6 3s2 3p6 3d1 4s2|1.36|184|170|1814|3109|2.985|Solid|1879|Lars Fredrik Nilson|sccl3|Aluminium alloys;Metal lamps;Scandium oxide|Scandium oxide gives street lamps a pure white light.
22|Ti|Titanium|47.867|transition-metal|4|4|0|1s2 2s2 2p6 3s2 3p6 3d2 4s2|1.54|176|160|1941|3560|4.506|Solid|1791|William Gregor|tio2|Aerospace;Implants;Pigment|Strong, light and biocompatible metal.
23|V|Vanadium|50.942|transition-metal|5|4|0|1s2 2s2 2p6 3s2 3p6 3d3 4s2|1.63|171|153|2183|3680|6.11|Solid|1801|Andres Manuel del Rio|v2o5|Steel alloying;Vanadium batteries|Catalyst for converting crude oil into petrol.
24|Cr|Chromium|51.996|transition-metal|6|4|0|1s2 2s2 2p6 3s2 3p6 3d5 4s1|1.66|166|139|2180|2944|7.15|Solid|1797|Louis-Nicolas Vauquelin|cr2o3|Stainless steel;Chrome plating;Pigment|Gives stainless steel its corrosion resistance.
25|Mn|Manganese|54.938|transition-metal|7|4|0|1s2 2s2 2p6 3s2 3p6 3d5 4s2|1.55|161|139|1519|2334|7.21|Solid|1774|Johan Gottlieb Gahn|kmno4|Steel making;Batteries;Pigments|Essible trace element needed for blood clotting.
26|Fe|Iron|55.845|transition-metal|8|4|0|1s2 2s2 2p6 3s2 3p6 3d6 4s2|1.83|156|132|1811|3134|7.874|Solid|Ancient|Known to the ancients|fe3o4|Steel;Magnets;Blood haemoglobin|Most-used metal on Earth, core of our planet.
27|Co|Cobalt|58.933|transition-metal|9|4|0|1s2 2s2 2p6 3s2 3p6 3d7 4s2|1.88|152|126|1768|3200|8.90|Solid|1735|Georg Brandt|cocl2|Battery electrodes;Catalysts;Blue pigments|Source of the deep blue used in ancient glass and pottery.
28|Ni|Nickel|58.693|transition-metal|10|4|0|1s2 2s2 2p6 3s2 3p6 3d8 4s2|1.91|149|124|1728|3003|8.908|Solid|1751|Axel Fredrik Cronstedt|nicl2|Stainless steel;Batteries;Electroplating|Coinage metal and catalyst for hydrogenation.
29|Cu|Copper|63.546|transition-metal|11|4|0|1s2 2s2 2p6 3s2 3p6 3d10 4s1|1.90|145|132|1357.77|2835|8.96|Solid|Ancient|Known to the ancients|cuso4|Electrical wiring;Plumbing;Antifouling paint|Second-most used metal, and an excellent conductor.
30|Zn|Zinc|65.38|transition-metal|12|4|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2|1.65|142|122|692.68|1180|7.14|Solid|1746|Andreas Sigismund Marggraf|zncl2|Galvanising;Brass;Sunscreen|Protects iron from rust as a sacrificial metal.
31|Ga|Gallium|69.723|post-transition-metal|13|4|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p1|1.81|136|122|302.9146|2673|5.91|Solid|1875|Paul-Emile Lecoq de Boisbaudran|gacl3|Semiconductors;LEDs;Thermometers|Melts in your hand and is used in gallium nitride LEDs.
32|Ge|Germanium|72.630|metalloid|14|4|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p2|2.01|125|120|1211.4|3106|5.323|Solid|1886|Clemens Winkler|geo2|Fibre-optic glass;Semiconductors;Infrared optics|Key semiconductor material for infrared optics.
33|As|Arsenic|74.922|metalloid|15|4|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p3|2.18|114|119|1090|887|5.727|Solid|1250|Albertus Magnus|as2o3|Pesticides;Semiconductors;Wood preservative|Toxic metalloid historically used as a poison and pigment.
34|Se|Selenium|78.971|reactive-nonmetal|16|4|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p4|2.55|103|120|494|958|4.81|Solid|1817|Jons Jacob Berzelius|seo2|Glass decolourising;Photocells;Antidandruff|Essential trace element; converts light to electricity.
35|Br|Bromine|79.904|halogen|17|4|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p5|2.96|94|120|265.8|332.0|3.1028|Liquid|1826|Antoine Jerome Balard|agbr|Flame retardants;Photography;Water treatment|The only non-metallic element liquid at room temperature.
36|Kr|Krypton|83.798|noble-gas|18|4|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6|-|88|116|115.79|119.93|0.003733|Gas|1898|Ramsay and Travers|krypton|High-speed photography;Insulating windows;Lighting|Used in some LED bulbs and high-speed flash lamps.
37|Rb|Rubidium|85.468|alkali-metal|1|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 5s1|0.82|265|220|312.46|961|1.532|Solid|1861|Bunsen and Kirchhoff|rbcl|Photocells;Lasers;Rubidium vapour clocks|Highly reactive metal used in atomic clocks.
38|Sr|Strontium|87.62|alkaline-earth-metal|2|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 5s2|0.95|219|195|1050|1655|2.64|Solid|1790|Adair Crawford|srcl2|Fireworks;Magnesium alloys;CRT glass|Gives fireworks their brilliant crimson colour.
39|Y|Yttrium|88.906|transition-metal|3|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d1 5s2|1.22|212|190|1799|3609|4.472|Solid|1794|Johan Gadolin|ycl3|Phosphors;Yttrium aluminium garnet lasers;Ceramic|Yttrium aluminium garnet makes solid-state lasers and white LEDs.
40|Zr|Zirconium|91.224|transition-metal|4|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d2 5s2|1.33|206|175|2128|4650|6.52|Solid|1789|Martin Heinrich Klaproth|zro2|Nuclear cladding;Ceramics;Precision parts|Highly resistant to corrosion, ideal for nuclear fuel cladding.
41|Nb|Niobium|92.906|transition-metal|5|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d4 5s1|1.60|198|164|2750|5017|8.57|Solid|1801|Charles Hatchett|nbcl5|Superalloys;Superconductors;Capacitors|Colours the golden sheen of niobium superconductors.
42|Mo|Molybdenum|95.95|transition-metal|6|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d5 5s1|2.16|190|154|2896|4912|10.28|Solid|1778|Carl Wilhelm Scheele|moo3|Lubricants;Steel alloys;Catalysts|Highest melting point of any pure metal.
43|Tc|Technetium|98|transition-metal|7|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d5 5s2|1.90|183|147|2430|4538|11.0|Solid|1937|Perrier and Segre|tc2o7|Nuclear medicine;Coral protection;Reactor alloy|First artificially produced element; used in medical imaging.
44|Ru|Ruthenium|101.07|transition-metal|8|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d7 5s1|2.20|178|146|2607|4423|12.45|Solid|1844|Karl Ernst Claus|ruo4|Catalysts;Electronics;Hardening platinum|Rare hard metal used in chip fabrication and hardeners.
45|Rh|Rhodium|102.91|transition-metal|9|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d8 5s1|2.28|173|142|2237|3968|12.41|Solid|1803|William Hyde Wollaston|rhcl3|Catalytic converters;Glass coatings;Reflectors|Most expensive precious metal; cleans car exhaust.
46|Pd|Palladium|106.42|transition-metal|10|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10|2.20|169|139|1828.05|3236|12.023|Solid|1802|William Hyde Wollaston|pdcl2|Catalysts;Hydrogen purification;Electronics|Absorbs 900 times its volume in hydrogen.
47|Ag|Silver|107.87|transition-metal|11|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s1|1.93|165|145|1234.93|2435|10.49|Solid|Ancient|Known to the ancients|agcl|Jewellery;Electronics;Antibacterial coatings|Best electrical and thermal conductor of all metals.
48|Cd|Cadmium|112.41|transition-metal|12|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2|1.69|161|144|594.22|1040|8.65|Solid|1817|Stromeyer and Hermann|cds|Pigments;Batteries;Reactor control rods|Toxic metal once widely used in yellow pigments.
49|In|Indium|114.82|post-transition-metal|13|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p1|1.78|156|142|429.7485|2345|7.31|Solid|1863|Reich and Richter|incl3|Indium tin oxide;Solders;Infrared detectors|Very soft metal used in the coating of touchscreen glass.
50|Sn|Tin|118.71|post-transition-metal|14|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p2|1.96|145|139|505.08|2875|7.265|Solid|Ancient|Known to the ancients|sncl4|Solder;Bronze;Tin plating|Alloyed with copper to make the alloy bronze.
51|Sb|Antimony|121.76|metalloid|15|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p3|2.05|133|139|903.78|1907|6.697|Solid|Ancient|Known to the ancients|sb2o3|Flame retardants;Lead alloys;Batteries|A metalloid used in ancient kohl and in flame retardants.
52|Te|Tellurium|127.60|metalloid|16|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p4|2.10|123|138|722.66|1261|6.24|Solid|1782|Franz-Joseph Muller von Reichenstein|teo2|Solar cell films;Anti-friction alloys;Thermoelectric|Used in thin-film photovoltaics and thermoelectric generators.
53|I|Iodine|126.90|halogen|17|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p5|2.66|115|139|386.85|457.4|4.933|Solid|1811|Bernard Courtois|ki|Thyroid medicine;Disinfectant;X-ray contrast|Sublimes to a violet vapour; essential for the thyroid.
54|Xe|Xenon|131.29|noble-gas|18|5|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6|2.60|108|140|161.4|165.051|0.005894|Gas|1898|Ramsay and Travers|xef4|Flash lamps;Arc lamps;Ion propulsion|Used in bright xenon arc lamps for cinema projection.
55|Cs|Caesium|132.91|alkali-metal|1|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 6s1|0.79|298|244|301.59|944|1.93|Solid|1860|Bunsen and Kirchhoff|cscl|Atomic clocks;Photoelectric cells|Caesium-133 defines the SI second.
56|Ba|Barium|137.33|alkaline-earth-metal|2|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 6s2|0.89|253|215|1000|2170|3.51|Solid|1808|Humphry Davy|baso4|Barium meals;Drilling fluids;Glass|Gives a pale green flame and is used in X-ray imaging.
57|La|Lanthanum|138.91|lanthanide|3|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 5d1 6s2|1.10|226|207|1193|3737|6.162|Solid|1839|Carl Gustaf Mosander|lacl3|Camera lenses;Batteries;Catalysts|Named for the hidden element, the lanthanides' namesake.
58|Ce|Cerium|140.12|lanthanide|4|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f1 5d1 6s2|1.12|210|204|1068|3716|6.770|Solid|1803|Berzelius, Hisinger and Klaproth|ceo2|Catalytic converters;Glass polishing;Lighter flints|Most abundant of the rare earth elements.
59|Pr|Praseodymium|140.91|lanthanide|5|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f3 6s2|1.13|247|203|1208|3793|6.77|Solid|1885|Carl Auer von Welsbach|prcl3|Welding goggles;Headlight glass;Magnets|Gives glass a distinctive yellow-green tint.
60|Nd|Neodymium|144.24|lanthanide|6|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f4 6s2|1.14|206|201|1297|3347|7.01|Solid|1885|Carl Auer von Welsbach|ndcl3|Strong permanent magnets;Headphones;Lasers|Makes the strongest neodymium iron boron magnets.
61|Pm|Promethium|145|lanthanide|7|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f5 6s2|1.13|205|199|1315|3273|7.26|Solid|1945|Marinsky, Glendenin and Coryell|pmcl3|Paint and glow-in-the-dark pigments|Only radioactive lanthanide with no stable isotopes.
62|Sm|Samarium|150.36|lanthanide|8|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f6 6s2|1.17|238|198|1345|2067|7.52|Solid|1879|Paul-Emile Lecoq de Boisbaudran|smcl3|Samarium-cobalt magnets;Nuclear control rods|Makes exceptionally strong, heat-resistant magnets.
63|Eu|Europium|151.96|lanthanide|9|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f7 6s2|1.20|231|198|1099|1802|5.264|Solid|1901|Eugene-Anatole Demarcay|eucl3|Euroluminescence;Euro banknotes;Lasers|Gives the red glow in euro banknote anti-counterfeit ink.
64|Gd|Gadolinium|157.25|lanthanide|10|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f7 5d1 6s2|1.20|233|196|1585|3546|7.90|Solid|1880|Jean Charles Galissard de Marignac|gdcl3|MRI contrast agent;Neutron shielding|Strongly paramagnetic, used to sharpen MRI images.
65|Tb|Terbium|158.93|lanthanide|11|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f9 6s2|1.10|225|194|1629|3503|8.23|Solid|1843|Carl Gustaf Mosander|tbcl3|Green phosphors;Solid-state devices;Magnets|Used in the green phosphors of fluorescent lighting.
66|Dy|Dysprosium|162.50|lanthanide|12|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f10 6s2|1.22|228|192|1680|2840|8.540|Solid|1886|Paul-Emile Lecoq de Boisbaudran|dycl3|High-strength magnets;Nuclear reactors|Dysprosium alloys make electric-vehicle motors.
67|Ho|Holmium|164.93|lanthanide|13|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f11 6s2|1.23|226|192|1734|2993|8.79|Solid|1878|Per Teodor Cleve|hocl3|Laser crystals;Magnetic flux concentrators|Has the highest magnetic moment of any element.
68|Er|Erbium|167.26|lanthanide|14|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f12 6s2|1.24|226|189|1802|3141|9.066|Solid|1843|Carl Gustaf Mosander|ercl3|Optical fibre amplifiers;Glass colouring|Amplifies light in erbium-doped optical fibres.
69|Tm|Thulium|168.93|lanthanide|15|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f13 6s2|1.25|222|190|1818|2223|9.32|Solid|1879|Per Teodor Cleve|tmcl3|X-ray sources;Portable power sources|Rarest of the stable lanthanides.
70|Yb|Ytterbium|173.05|lanthanide|16|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 6s2|1.10|222|187|1097|1469|6.90|Solid|1878|Jean Charles Galissard de Marignac|ybcl3|Yb lasers;Mechanical alloys;Pressure sensors|Its name comes from the Swedish village Ytterby.
71|Lu|Lutetium|174.97|lanthanide|17|6|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f15 6s2|1.27|217|187|1925|3675|9.841|Solid|1907|Georges Urbain|lucl3|PET scanners;Catalysts;Refractory alloys|Latest and hardest of the lanthanide metals.
72|Hf|Hafnium|178.49|transition-metal|4|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d2 6s2|1.30|208|175|2506|4876|13.31|Solid|1923|Coster and de Hevesy|hfo2|Plasma tool coatings;Nuclear control rods|Looks like zirconium but tolerates much higher temperatures.
73|Ta|Tantalum|180.95|transition-metal|5|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d3 6s2|1.50|200|170|3290|5731|16.69|Solid|1802|Anders Gustaf Ekeberg|tacl5|Capacitors;Surgical implants;Rocket parts|Almost immune to body fluids, used in medical implants.
74|W|Tungsten|183.84|transition-metal|6|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d4 6s2|2.36|193|162|3695|6203|19.25|Solid|1781|Carl Wilhelm Scheele|woo3|Filament bulbs;Cutting tools;Radiation shielding|Highest melting point of any metal.
75|Re|Rhenium|186.21|transition-metal|7|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d5 6s2|1.90|188|151|3459|5869|21.02|Solid|1925|Noddack, Tacke and Berg|re2o7|Jet engine superalloys;Thermocouples|One of the rarest elements in Earth's crust.
76|Os|Osmium|190.23|transition-metal|8|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d6 6s2|2.20|185|144|3306|5285|22.59|Solid|1803|Smithson Tennant|oso4|Pen nibs;Catalysts;Electrical contacts|Densest naturally occurring element.
77|Ir|Iridium|192.22|transition-metal|9|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d7 6s2|2.20|180|141|2719|4403|22.56|Solid|1803|Smithson Tennant|ircl3|Catalysts;Crucible alloys;Cancer drugs|Came from a thin iridium-rich clay layer marking the dinosaurs' extinction.
78|Pt|Platinum|195.08|transition-metal|10|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d9 6s1|2.28|177|136|2041.4|4098|21.45|Solid|1735|Antonio de Ulloa|ptcl4|Catalytic converters;Cancer drugs;Labware|Inert to corrosion, used in chemotherapy drug cisplatin.
79|Au|Gold|196.97|transition-metal|11|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s1|2.54|174|136|1337.33|3129|19.3|Solid|Ancient|Known to theancients|aucl3|Jewellery;Electronics;Money|The ultimate noble metal; chemically unreactive and lustrous.
80|Hg|Mercury|200.59|transition-metal|12|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2|2.00|171|132|234.32|629.88|13.534|Liquid|Ancient|Known to the ancients|hgcl2|Thermometers;Fluorescent lamps;Chemistry|The only metal liquid at room temperature.
81|Tl|Thallium|204.38|post-transition-metal|13|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p1|1.62|156|145|577|1746|11.85|Solid|1861|William Crookes|tlcl|Infrared optics;Rat poison;Scintillators|Highly toxic soft metal once used as rat poison.
82|Pb|Lead|207.2|post-transition-metal|14|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p2|2.33|154|146|600.61|2022|11.34|Solid|Ancient|Known to the ancients|pbcl2|Batteries;Radiation shielding;Solder|Dense, soft and famously toxic heavy metal.
83|Bi|Bismuth|208.98|post-transition-metal|15|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p3|2.02|143|148|544.7|1837|9.78|Solid|1753|Claude Francois Geoffroy|bi2o3|Paint and cosmetics;Pharmaceuticals;Low-melting alloys|Forms beautiful iridescent stair-step crystals.
84|Po|Polonium|209|post-transition-metal|16|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p4|2.00|135|140|527|1235|9.196|Solid|1898|Marie and Pierre Curie|pocl2|Static eliminators;Nuclear research|Discovered by the Curies and named after Poland.
85|At|Astatine|210|halogen|17|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p5|2.20|127|150|575|610|7|Solid|1940|Corson, MacKenzie and Segre|atcl|Nuclear research;Cancer therapy|Rarest naturally occurring element; about 25 grams on Earth.
86|Rn|Radon|222|noble-gas|18|6|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6|-|120|150|202|211.5|0.00973|Gas|1900|Friedrich Ernst Dorn|radon|Radon therapy;Earthquake prediction|Colourless radioactive gas seeping from granite.
87|Fr|Francium|223|alkali-metal|1|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 7s1|0.70|260|260|300|950|1.87|Solid|1939|Marguerite Perey|frcl|Nuclear research|Only about 30 grams exist in the Earth's crust at any time.
88|Ra|Radium|226|alkaline-earth-metal|2|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 7s2|0.90|221|215|973|2010|5.5|Solid|1898|Marie and Pierre Curie|racl2|Historical radiotherapy;Industrial radiography|Discovered by the Curies and named for its intense glow.
89|Ac|Actinium|227|actinide|3|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 6d1 7s2|1.10|215|195|1323|3471|10.07|Solid|1899|Andre-Louis Debierne|accl3|Nuclear research;Cancer therapy|Glows pale blue in the dark; namesake of the actinides.
90|Th|Thorium|232.04|actinide|4|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 6d2 7s2|1.30|206|180|2115|5061|11.7|Solid|1829|Jons Jacob Berzelius|tho2|Nuclear fuel;Welding electrodes;Incandescent mantles|Four times as abundant as uranium and a possible fuel of the future.
91|Pa|Protactinium|231.04|actinide|5|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f2 6d1 7s2|1.50|200|180|1841|4300|15.37|Solid|1913|Fajans and Gohring|pa2o5|Nuclear research;Weighing salts|Rarest naturally occurring actinide.
92|U|Uranium|238.03|actinide|6|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f3 6d1 7s2|1.38|196|175|1405.3|4404|19.1|Solid|1789|Martin Heinrich Klaproth|uo2|Nuclear fuel;Armour plating;Geological dating|Fissile U-235 fuels reactors and nuclear weapons.
93|Np|Neptunium|237|actinide|7|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f4 6d1 7s2|1.36|190|175|917|4273|20.45|Solid|1940|McMillan and Abelson|npo2|Nuclear reactors;Research;Neutron detectors|First transuranic element made; named for the planet after Uranus.
94|Pu|Plutonium|244|actinide|8|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f6 7s2|1.28|187|175|912.5|3505|19.816|Solid|1940|Seaborg, McMillan, Kennedy and Wahl|puo2|Nuclear fuel;Radioisotope batteries|Used in Voyager and Curiosity radioisotope thermoelectric generators.
95|Am|Americium|243|actinide|9|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f7 7s2|1.13|180|175|1449|2880|13.69|Solid|1944|Seaborg, James, Morgan and Ghiorso|amcl3|Smoke detectors;Moisture gauges|The element in household smoke detectors.
96|Cm|Curium|247|actinide|10|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f7 6d1 7s2|1.28|169|176|1613|3383|13.51|Solid|1944|Seaborg, James and Ghiorso|cmcl3|Alpha particle sources;Cancer research|Named for Marie and Pierre Curie.
97|Bk|Berkelium|247|actinide|11|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f9 7s2|1.30|168|168|1259|2900|14.78|Solid|1949|Thompson, Ghiorso and Seaborg|bkcl3|Nuclear research;Neutron sources|Produced in milligram quantities in Oak Ridge reactors.
98|Cf|Californium|251|actinide|12|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f10 7s2|1.30|168|168|1173|1743|15.1|Solid|1950|Thompson, Ghiorso and Seaborg|cfcl3|Neutron sources;Oil well logging;Cancer treatment|Produces neutrons used to start up reactors and find gold.
99|Es|Einsteinium|252|actinide|13|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f11 7s2|1.30|165|165|1133|1269|8.84|Solid|1952|Crane and colleagues|escl3|Nuclear research;Scientific studies|Discovered in the debris of the first hydrogen bomb test.
100|Fm|Fermium|257|actinide|14|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f12 7s2|-|167|167|1800|-|-|Solid|1952|Ghiorso and colleagues|fmcl3|Nuclear research|The heaviest element that can be formed by neutron bombardment.
101|Md|Mendelevium|258|actinide|15|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f13 7s2|-|173|173|1100|-|-|Solid|1955|Ghiorso, Harvey, Choppin, Thompson and Seaborg|mdcl3|Nuclear research|Named for Dmitri Mendeleev, father of the periodic table.
102|No|Nobelium|259|actinide|16|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 7s2|-|174|174|1100|-|-|Solid|1966|Dubna and colleagues|nocl3|Nuclear research|Named after Alfred Nobel, founder of the Nobel prizes.
103|Lr|Lawrencium|266|actinide|17|7|1|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 7s2 7d1|1.10|176|176|1900|-|-|Solid|1961|Ghiorso and colleagues|lrcl3|Nuclear research|The last actinide and the first to be found at a cyclotron.
104|Rf|Rutherfordium|267|transition-metal|4|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d2 7s2|-|-|157|-|-|-|Solid|1964|Joint Institute for Nuclear Research|rfcl4|Nuclear research;Superheavy chemistry|Named after Ernest Rutherford, discoverer of the nucleus.
105|Db|Dubnium|268|transition-metal|5|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d3 7s2|-|-|149|-|-|-|Solid|1967|Lawrence Berkeley Laboratory|dbcl5|Nuclear research;Superheavy chemistry|Named after Dubna, Russia, where it was created.
106|Sg|Seaborgium|269|transition-metal|6|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d4 7s2|-|-|143|-|-|-|Solid|1974|Lawrence Berkeley Laboratory|sgf6|Nuclear research;Superheavy chemistry|The first element named after a living person.
107|Bh|Bohrium|270|transition-metal|7|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d5 7s2|-|-|141|-|-|-|Solid|1981|GSI Helmholtz Centre|bhcl4|Nuclear research;Superheavy chemistry|Named after Niels Bohr.
108|Hs|Hassium|269|transition-metal|8|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d6 7s2|-|-|134|-|-|-|Solid|1984|GSI Helmholtz Centre|hscl4|Nuclear research;Superheavy chemistry|Named after the German state of Hesse.
109|Mt|Meitnerium|278|unknown|9|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d7 7s2|-|-|129|-|-|-|Solid|1982|GSI Helmholtz Centre|mtcl4|Nuclear research;Superheavy chemistry|Named after Lise Meitner, pioneer of nuclear fission.
110|Ds|Darmstadtium|281|unknown|10|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d9 7s1|-|-|128|-|-|-|Solid|1994|GSI Helmholtz Centre|dscl4|Nuclear research;Superheavy chemistry|Named after Darmstadt, the German research centre.
111|Rg|Roentgenium|282|unknown|11|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d10 7s1|-|-|121|-|-|-|Solid|1994|GSI Helmholtz Centre|rgcl4|Nuclear research;Superheavy chemistry|Named after Wilhelm Rontgen, pioneer of X-rays.
112|Cn|Copernicium|285|unknown|12|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d10 7s2|-|-|122|-|-|-|Solid|1996|GSI Helmholtz Centre|cn|Nuclear research;Heavy element chemistry|Named after Nicolaus Copernicus, father of heliocentrism.
113|Nh|Nihonium|286|unknown|13|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d10 7s2 7p1|-|-|136|-|-|-|Solid|2003|RIKEN|nhcl3|Nuclear research;Superheavy chemistry|First element discovered in Asia.
114|Fl|Flerovium|289|post-transition-metal|14|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d10 7s2 7p2|-|-|143|-|-|-|Solid|1998|JINR and LLNL|flcl4|Nuclear research;Superheavy chemistry|Named after the Flerov Laboratory, the Dubna institute.
115|Mc|Moscovium|290|post-transition-metal|15|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d10 7s2 7p3|-|-|162|-|-|-|Solid|2003|JINR and LLNL|mccl5|Nuclear research;Superheavy chemistry|Named after the Moscow region.
116|Lv|Livermorium|293|post-transition-metal|16|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d10 7s2 7p4|-|-|175|-|-|-|Solid|2000|JINR and LLNL|lvcl4|Nuclear research;Superheavy chemistry|Named after Lawrence Livermore National Laboratory.
117|Ts|Tennessine|294|unknown|17|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d10 7s2 7p5|-|-|165|-|-|-|Solid|2010|JINR, LLNL and ORNL|tscl4|Nuclear research;Superheavy chemistry|Named after Tennessee, home of ORNL.
118|Og|Oganesson|294|unknown|18|7|0|1s2 2s2 2p6 3s2 3p6 3d10 4s2 4p6 4d10 5s2 5p6 4f14 5d10 6s2 6p6 5f14 6d10 7s2 7p6|-|-|157|-|-|-|Unknown|2002|JINR and LLNL|og|Nuclear research;Superheavy chemistry|Heaviest and most recent element on the periodic table.
"""

# Extra molecules that round out the library.  Same field layout as ROWS but
# without the element fields.
# id | display name | formula | geometry | atoms | bonds | details
MOLECULES = [
    ("h2so4",      "Sulphuric acid",              "H2SO4", "explicit",        "S,O,O,O,O,H,H",    "0-1,0-2,0-3,0-4,3-5,4-6", "Two hydroxyl groups and two double-bonded oxygens around sulphur."),
    ("cocl2",      "Cobalt(II) chloride",         "CoCl2", "linear",          "Co,Cl,Cl",         "0-1,0-2",        "A linear gas-phase transition-metal dihalide."),
    ("nicl2",      "Nickel(II) chloride",         "NiCl2", "linear",          "Ni,Cl,Cl",         "0-1,0-2",        "A linear gas-phase transition-metal dihalide."),
    ("zncl2",      "Zinc chloride",               "ZnCl2", "linear",          "Zn,Cl,Cl",         "0-1,0-2",        "A linear, electron-deficient zinc dihalide."),
    ("rhcl3",      "Rhodium(III) chloride",       "RhCl3", "pyramidal",       "Rh,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A square-planar rhodium(III) complex in the solid state."),
    ("ircl3",      "Iridium(III) chloride",       "IrCl3", "pyramidal",       "Ir,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A square-planar iridium complex used in catalysis."),
    ("water",       "Water",                        "H2O",   "bent",            "O,H,H",            "0-1,0-2",        "The bent geometry of water comes from two lone pairs on oxygen."),
    ("neon",       "Neon atom",                    "Ne",    "monatomic",       "Ne",               "",               "A single, fully inert noble gas atom."),
    ("argon",      "Argon atom",                   "Ar",    "monatomic",       "Ar",               "",               "A single, fully inert noble gas atom."),
    ("krypton",    "Krypton atom",                 "Kr",    "monatomic",       "Kr",               "",               "A single, fully inert noble gas atom."),
    ("radon",      "Radon atom",                   "Rn",    "monatomic",       "Rn",               "",               "A single, fully inert noble gas atom."),
    ("cn",         "Copernicium atom",             "Cn",    "monatomic",       "Cn",               "",               "A single superheavy atom."),
    ("og",         "Oganesson atom",               "Og",    "monatomic",       "Og",               "",               "A single superheavy atom."),
    ("licl",       "Lithium chloride",             "LiCl",  "diatomic",        "Li,Cl",            "0-1",            "An ionic salt; a simple two-atom lattice."),
    ("nacl",       "Sodium chloride",              "NaCl",  "cubic-na",        "Na,Cl",            "",               "The rock-salt lattice, the archetype of an ionic crystal."),
    ("kcl",        "Potassium chloride",           "KCl",   "cubic-na",        "K,Cl",             "",               "Also crystallises in the rock-salt structure."),
    ("rbcl",       "Rubidium chloride",            "RbCl",  "cubic-na",        "Rb,Cl",            "",               "An alkali halide with the rock-salt structure."),
    ("ki",         "Potassium iodide",             "KI",    "cubic-na",        "K,I",              "",               "Used in dietary supplements and infrared optics."),
    ("cscl",       "Caesium chloride",             "CsCl",  "cubic-cs",        "Cs,Cl",            "",               "The caesium-chloride lattice, coordination number eight."),
    ("agcl",       "Silver chloride",              "AgCl",  "diatomic",        "Ag,Cl",            "0-1",            "The light-sensitive salt at the heart of photographic film."),
    ("agbr",       "Silver bromide",               "AgBr",  "diatomic",        "Ag,Br",            "0-1",            "The most light-sensitive photographic emulsion."),
    ("cds",        "Cadmium sulfide",              "CdS",   "cubic-na",        "Cd,S",             "",               "A wide-bandgap semiconductor used in solar cells."),
    ("tlcl",       "Thallium chloride",            "TlCl",  "diatomic",        "Tl,Cl",            "0-1",            "A heavy, photosensitive thallium halide."),
    ("atcl",       "Astatine chloride",            "AtCl",  "diatomic",        "At,Cl",            "0-1",            "An extremely rare heavy halogen compound."),
    ("frcl",       "Francium chloride",            "FrCl",  "diatomic",        "Fr,Cl",            "0-1",            "The heaviest alkali metal halide."),
    ("becl2",      "Beryllium chloride",           "BeCl2", "linear",          "Be,Cl,Cl",         "0-1,0-2",        "A linear molecule with two electron-deficient bonds."),
    ("mgcl2",      "Magnesium chloride",           "MgCl2", "linear",          "Mg,Cl,Cl",         "0-1,0-2",        "An ionic salt with a linear gas-phase geometry."),
    ("srcl2",      "Strontium chloride",           "SrCl2", "linear",          "Sr,Cl,Cl",         "0-1,0-2",        "An alkaline-earth halide."),
    ("racl2",      "Radium chloride",              "RaCl2", "linear",          "Ra,Cl,Cl",         "0-1,0-2",        "A radium salt once used in luminous paint."),
    ("bf3",        "Boron trifluoride",            "BF3",   "planar-trigonal", "B,F,F,F",          "0-1,0-2,0-3",    "A flat, trigonal planar molecule with a boron deficiency."),
    ("alcl3",      "Aluminium chloride",           "AlCl3", "planar-trigonal", "Al,Cl,Cl,Cl",      "0-1,0-2,0-3",    "Dimeric in the solid state, planar as a gas."),
    ("gacl3",      "Gallium trichloride",          "GaCl3", "planar-trigonal", "Ga,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A group 13 trihalide with trigonal planar geometry."),
    ("aucl3",      "Gold(III) chloride",           "AuCl3", "planar-trigonal", "Au,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A square-planar gold complex in its active form."),
    ("sncl4",      "Tin tetrachloride",            "SnCl4", "tetrahedral",     "Sn,Cl,Cl,Cl,Cl",   "0-1,0-2,0-3,0-4","A classic tetrahedral group 14 tetrachloride."),
    ("ccl4",       "Carbon tetrachloride",         "CCl4",  "tetrahedral",     "C,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","Non-polar and formerly a ubiquitous solvent."),
    ("methane",    "Methane",                      "CH4",   "tetrahedral",     "C,H,H,H,H",        "0-1,0-2,0-3,0-4","The simplest alkane and the principal greenhouse gas."),
    ("si",         "Silicon dioxide tetrahedron",   "SiO4",  "tetrahedral",     "Si,O,O,O,O",       "0-1,0-2,0-3,0-4","The SiO4 tetrahedron at the heart of every silicate mineral."),
    ("sio2",       "Silicon dioxide",              "SiO2",  "tetrahedral",     "Si,O,O,O,O",       "0-1,0-2,0-3,0-4","The SiO4 tetrahedron at the heart of every silicate mineral."),
    ("geo2",       "Germanium dioxide",            "GeO2",  "tetrahedral",     "Ge,O,O,O,O",       "0-1,0-2,0-3,0-4","A tetrahedral network glass former."),
    ("zro2",       "Zirconium dioxide",            "ZrO2",  "tetrahedral",     "Zr,O,O,O,O",       "0-1,0-2,0-3,0-4","The tough ceramic used in cubic zirconia cutters."),
    ("hfo2",       "Hafnium dioxide",              "HfO2",  "tetrahedral",     "Hf,O,O,O,O",       "0-1,0-2,0-3,0-4","A high-k dielectric used in modern transistors."),
    ("rfcl4",      "Rutherfordium tetrachloride",  "RfCl4", "tetrahedral",     "Rf,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A predicted tetrachloride of a superheavy element."),
    ("bhcl4",      "Bohrium tetrachloride",        "BhCl4", "tetrahedral",     "Bh,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A predicted group 7 tetrachloride."),
    ("hscl4",      "Hassium tetrachloride",        "HsCl4", "tetrahedral",     "Hs,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A predicted group 8 tetrachloride."),
    ("mtcl4",      "Meitnerium tetrachloride",     "MtCl4", "tetrahedral",     "Mt,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A predicted group 9 tetrachloride."),
    ("dscl4",      "Darmstadtium tetrachloride",   "DsCl4", "tetrahedral",     "Ds,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A predicted group 10 tetrachloride."),
    ("rgcl4",      "Roentgenium tetrachloride",    "RgCl4", "tetrahedral",     "Rg,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A predicted group 11 tetrachloride."),
    ("flcl4",      "Flerovium tetrachloride",      "FlCl4", "tetrahedral",     "Fl,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A predicted group 14 tetrachloride."),
    ("lvcl4",      "Livermorium tetrachloride",    "LvCl4", "tetrahedral",     "Lv,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A predicted group 16 tetrachloride."),
    ("tscl4",      "Tennessine tetrachloride",     "TsCl4", "tetrahedral",     "Ts,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A predicted group 17 tetrachloride."),
    ("nhcl3",      "Nihonium trichloride",         "NhCl3", "pyramidal",       "Nh,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A predicted group 13 trichloride."),
    ("incl3",      "Indium trichloride",           "InCl3", "pyramidal",       "In,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A group 13 trichloride, pyramidal as a gas."),
    ("sccl3",      "Scandium trichloride",         "ScCl3", "pyramidal",       "Sc,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A rare-earth trichloride with trigonal pyramidal shape."),
    ("ycl3",       "Yttrium trichloride",          "YCl3",  "pyramidal",       "Y,Cl,Cl,Cl",       "0-1,0-2,0-3",    "A rare-earth trichloride."),
    ("lacl3",      "Lanthanum trichloride",        "LaCl3", "pyramidal",       "La,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A light lanthanide trichloride."),
    ("prcl3",      "Praseodymium trichloride",     "PrCl3", "pyramidal",       "Pr,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A lanthanide trichloride."),
    ("ndcl3",      "Neodymium trichloride",        "NdCl3", "pyramidal",       "Nd,Cl,Cl,Cl",      "0-1,0-2,0-3",    "The precursor to neodymium magnet alloys."),
    ("pmcl3",      "Promethium trichloride",       "PmCl3", "pyramidal",       "Pm,Cl,Cl,Cl",      "0-1,0-2,0-3",    "The only radioactive lanthanide chloride."),
    ("smcl3",      "Samarium trichloride",         "SmCl3", "pyramidal",       "Sm,Cl,Cl,Cl",      "0-1,0-2,0-3",    "Used in samarium-cobalt magnet production."),
    ("eucl3",      "Europium trichloride",         "EuCl3", "pyramidal",       "Eu,Cl,Cl,Cl",      "0-1,0-2,0-3",    "The precursor of europium phosphors."),
    ("gdcl3",      "Gadolinium trichloride",       "GdCl3", "pyramidal",       "Gd,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A paramagnetic MRI contrast salt."),
    ("tbcl3",      "Terbium trichloride",          "TbCl3", "pyramidal",       "Tb,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A green-emitting phosphor precursor."),
    ("dycl3",      "Dysprosium trichloride",       "DyCl3", "pyramidal",       "Dy,Cl,Cl,Cl",      "0-1,0-2,0-3",    "Strengthens high-performance permanent magnets."),
    ("hocl3",      "Holmium trichloride",          "HoCl3", "pyramidal",       "Ho,Cl,Cl,Cl",      "0-1,0-2,0-3",    "The source of the highest magnetic moment known."),
    ("ercl3",      "Erbium trichloride",           "ErCl3", "pyramidal",       "Er,Cl,Cl,Cl",      "0-1,0-2,0-3",    "The dopant in erbium optical amplifiers."),
    ("tmcl3",      "Thulium trichloride",          "TmCl3", "pyramidal",       "Tm,Cl,Cl,Cl",      "0-1,0-2,0-3",    "Used in portable X-ray sources."),
    ("ybcl3",      "Ytterbium trichloride",        "YbCl3", "pyramidal",       "Yb,Cl,Cl,Cl",      "0-1,0-2,0-3",    "The feedstock for ytterbium laser crystals."),
    ("lucl3",      "Lutetium trichloride",         "LuCl3", "pyramidal",       "Lu,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A PET-scanner detector salt."),
    ("accl3",      "Actinium trichloride",         "AcCl3", "pyramidal",       "Ac,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A highly radioactive actinide salt."),
    ("amcl3",      "Americium trichloride",        "AmCl3", "pyramidal",       "Am,Cl,Cl,Cl",      "0-1,0-2,0-3",    "An actinide salt used in alpha sources."),
    ("cmcl3",      "Curium trichloride",           "CmCl3", "pyramidal",       "Cm,Cl,Cl,Cl",      "0-1,0-2,0-3",    "The target material for curium alpha sources."),
    ("bkcl3",      "Berkelium trichloride",        "BkCl3", "pyramidal",       "Bk,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A rare transuranic chloride."),
    ("cfcl3",      "Californium trichloride",      "CfCl3", "pyramidal",       "Cf,Cl,Cl,Cl",      "0-1,0-2,0-3",    "The precursor of californium neutron sources."),
    ("escl3",      "Einsteinium trichloride",      "EsCl3", "pyramidal",       "Es,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A highly radioactive actinide salt."),
    ("fmcl3",      "Fermium trichloride",          "FmCl3", "pyramidal",       "Fm,Cl,Cl,Cl",      "0-1,0-2,0-3",    "Among the heaviest compounds ever synthesised."),
    ("mdcl3",      "Mendelevium trichloride",      "MdCl3", "pyramidal",       "Md,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A transuranic salt studied in trace amounts only."),
    ("nocl3",      "Nobelium trichloride",         "NoCl3", "pyramidal",       "No,Cl,Cl,Cl",      "0-1,0-2,0-3",    "Known only from tracer-level experiments."),
    ("lrcl3",      "Lawrencium trichloride",       "LrCl3", "pyramidal",       "Lr,Cl,Cl,Cl",      "0-1,0-2,0-3",    "A predicted actinide chloride."),
    ("ammonia",    "Ammonia",                      "NH3",   "pyramidal",       "N,H,H,H",          "0-1,0-2,0-3",    "A trigonal pyramid with a lone pair on nitrogen."),
    ("pcl3",       "Phosphorus trichloride",       "PCl3",  "pyramidal",       "P,Cl,Cl,Cl",       "0-1,0-2,0-3",    "A pyramidal molecule with three P-Cl bonds."),
    ("seo2",       "Selenium dioxide",             "SeO2",  "bent",            "Se,O,O",           "0-1,0-2",        "A bent, pyramidal molecule with a lone pair."),
    ("teo2",       "Tellurium dioxide",            "TeO2",  "bent",            "Te,O,O",           "0-1,0-2",        "A bent oxide of a heavy chalcogen."),
    ("pdcl2",      "Palladium(II) chloride",       "PdCl2", "bent",            "Pd,Cl,Cl",         "0-1,0-2",        "Square-planar in the solid, bent as a gas."),
    ("pbcl2",      "Lead(II) chloride",            "PbCl2", "bent",            "Pb,Cl,Cl",         "0-1,0-2",        "A bent heavy-metal dihalide."),
    ("pocl2",      "Polonium dichloride",          "PoCl2", "bent",            "Po,Cl,Cl",         "0-1,0-2",        "A rare, highly radioactive dihalide."),
    ("no2",        "Nitrogen dioxide",             "NO2",   "bent",            "N,O,O",            "0-1,0-2",        "A bent radical responsible for smog and acid rain."),
    ("o3",         "Ozone",                        "O3",    "bent",            "O,O,O",            "0-1,1-2",         "A bent allotrope that shields the Earth from ultraviolet light."),
    ("hgcl2",      "Mercury(II) chloride",         "HgCl2", "linear",          "Hg,Cl,Cl",         "0-1,0-2",        "A linear heavy-metal dihalide."),
    ("octahedral_sf6", "Sulfur hexafluoride",       "SF6",   "octahedral",      "S,F,F,F,F,F,F",    "0-1,0-2,0-3,0-4,0-5,0-6", "A perfect octahedron and a potent greenhouse gas."),
    ("sgf6",       "Seaborgium hexafluoride",       "SgF6",  "octahedral",      "Sg,F,F,F,F,F,F",    "0-1,0-2,0-3,0-4,0-5,0-6", "A predicted octahedral hexafluoride."),
    ("xef4",       "Xenon tetrafluoride",          "XeF4",  "square-planar",   "Xe,F,F,F,F",       "0-1,0-2,0-3,0-4","A square planar xenon compound with two lone pairs."),
    ("ptcl4",      "Platinum(IV) chloride",        "PtCl4", "square-planar",   "Pt,Cl,Cl,Cl,Cl",    "0-1,0-2,0-3,0-4","A square planar platinum complex."),
    ("tacl5",      "Tantalum pentachloride",       "TaCl5", "trigonal-bipyramidal", "Ta,Cl,Cl,Cl,Cl,Cl", "0-1,0-2,0-3,0-4,0-5", "A five-coordinate tantalum halide."),
    ("dbcl5",      "Dubnium pentachloride",        "DbCl5", "trigonal-bipyramidal", "Db,Cl,Cl,Cl,Cl,Cl", "0-1,0-2,0-3,0-4,0-5", "A predicted group 5 pentachloride."),
    ("mccl5",      "Moscovium pentachloride",      "McCl5", "trigonal-bipyramidal", "Mc,Cl,Cl,Cl,Cl,Cl", "0-1,0-2,0-3,0-4,0-5", "A predicted group 15 pentachloride."),
    ("nbcl5",      "Niobium pentachloride",        "NbCl5", "trigonal-bipyramidal", "Nb,Cl,Cl,Cl,Cl,Cl", "0-1,0-2,0-3,0-4,0-5", "A trigonal bipyramidal group 5 halide."),
    ("ruo4",       "Ruthenium tetroxide",          "RuO4",  "tetrahedral",     "Ru,O,O,O,O",       "0-1,0-2,0-3,0-4","A volatile, toxic tetrahedral oxide."),
    ("oso4",       "Osmium tetroxide",             "OsO4",  "tetrahedral",     "Os,O,O,O,O",       "0-1,0-2,0-3,0-4","A volatile tetrahedral oxide used in microscopy."),
    ("tio2",       "Titanium dioxide",             "TiO2",  "octahedral",      "Ti,O,O,O,O,O,O",   "0-1,0-2,0-3,0-4,0-5,0-6","The TiO6 octahedron of the rutile pigment."),
    ("p4",         "Phosphorus tetrahedron",       "P4",    "tetrahedron4",    "P,P,P,P",          "0-1,0-2,0-3,0-1,1-2,1-3,2-3", "White phosphorus is a P4 tetrahedron of strained bonds."),
    ("s8",         "Sulphur crown",                "S8",    "ring",            "S,S,S,S,S,S,S,S",  "0-1,1-2,2-3,3-4,4-5,5-6,6-7,7-0", "Orthorhombic sulphur is a puckered S8 crown."),
    ("benzene",    "Benzene",                      "C6H6",  "ring-with-h",    "C,C,C,C,C,C,H,H,H,H,H,H", "0-1,1-2,2-3,3-4,4-5,5-0,0-6,1-7,2-8,3-9,4-10,5-11", "A perfect hexagon of delocalised pi electrons."),
    ("h2",         "Hydrogen",                     "H2",    "diatomic",        "H,H",              "0-1",            "The simplest molecule, with a 436 kJ/mol bond."),
    ("o2",         "Oxygen",                       "O2",    "diatomic",        "O,O",              "0-1",            "The double-bonded molecule of the air."),
    ("n2",         "Nitrogen",                     "N2",    "diatomic",        "N,N",              "0-1",            "A triple bond that makes the atmosphere inert."),
    ("f2",         "Fluorine",                     "F2",    "diatomic",        "F,F",              "0-1",            "The most reactive diatomic molecule."),
    ("cl2",        "Chlorine",                     "Cl2",   "diatomic",        "Cl,Cl",            "0-1",            "A pale yellow diatomic gas."),
    ("hcl",        "Hydrogen chloride",            "HCl",   "diatomic",        "H,Cl",             "0-1",            "A diatomic acid that dissolves in water."),
    ("co2",        "Carbon dioxide",               "CO2",   "linear",          "C,O,O",            "0-1,0-2",        "A perfectly linear molecule that traps heat."),
    ("co",         "Carbon monoxide",              "CO",    "diatomic",        "C,O",              "0-1",            "A colourless, lethal gas with a triple bond."),
    ("hcn",        "Hydrogen cyanide",             "HCN",   "linear",          "H,C,N",            "0-1,1-2",        "A linear, volatile molecule of almond odour."),
    ("p4o10",      "Phosphorus pentoxide",         "P4O10", "tetrahedral",     "P,O,O,O,O",        "0-1,0-2,0-3,0-4","A tetrahedral phosphate cage in P4O10."),
    ("h2o2",       "Hydrogen peroxide",            "H2O2",  "explicit",        "O,O,H,H",          "0-1,0-2,1-3",    "A non-planar molecule with an O-O single bond."),
    ("naoh",       "Sodium hydroxide",             "NaOH",  "explicit",        "Na,O,H",           "1-2",            "An ionic hydroxide with a polar O-H bond."),
    ("hno3",       "Nitric acid",                  "HNO3",  "explicit",        "N,O,O,O,H",        "0-1,0-2,0-3,3-4","A planar nitrate group with a hydroxyl."),
    ("h3po4",      "Phosphoric acid",              "H3PO4", "explicit",        "P,O,O,O,O,H,H,H",  "0-1,0-2,0-3,0-4,1-5,2-6,3-7", "A tetrahedral phosphate with three acidic hydrogens."),
    ("ch3oh",      "Methanol",                     "CH3OH", "explicit",        "C,O,H,H,H,H",      "0-1,0-2,0-3,0-4,1-5", "A polar solvent with a hydrogen-bond donor."),
    ("ch2o",       "Formaldehyde",                 "CH2O",  "planar-trigonal", "C,H,H,O",          "0-1,0-2,0-3",    "A planar carbonyl compound, the simplest aldehyde."),
    ("c2h4",       "Ethene",                       "C2H4",  "explicit",        "C,C,H,H,H,H",      "0-1,0-2,0-3,1-4,1-5", "A planar double-bonded molecule."),
    ("c2h6",       "Ethane",                       "C2H6",  "explicit",        "C,C,H,H,H,H,H,H",  "0-1,0-2,0-3,0-4,1-5,1-6,1-7", "A saturated hydrocarbon with a free-rotating C-C bond."),
    ("caco3",      "Calcium carbonate",            "CaCO3", "explicit",        "Ca,C,O,O,O",       "1-2,1-3,1-4",    "A trigonal planar carbonate group with a calcium ion."),
    ("baso4",      "Barium sulphate",              "BaSO4", "explicit",        "Ba,S,O,O,O,O",     "1-2,1-3,1-4,1-5", "The 'barium meal' used for X-ray imaging."),
    ("kmno4",      "Potassium permanganate",       "KMnO4", "explicit",        "K,Mn,O,O,O,O",     "1-2,1-3,1-4,1-5", "A tetrahedral permanganate ion and a strong oxidiser."),
    ("cuso4",      "Copper(II) sulphate",          "CuSO4", "explicit",        "Cu,S,O,O,O,O",     "1-2,1-3,1-4,1-5", "Blue vitriol, with a distorted sulfate group."),
    ("feo",        "Iron(II) oxide",               "FeO",   "octahedral",      "Fe,O,O,O,O,O,O",   "0-1,0-2,0-3,0-4,0-5,0-6","A rock-salt coordination environment."),
    ("fe2o3",      "Iron(III) oxide",              "Fe2O3", "explicit",        "Fe,Fe,O,O,O",      "0-1,0-2,0-3,1-4", "Rust, with iron(III) centres in an oxygen lattice."),
    ("fe3o4",      "Iron(II,III) oxide",           "Fe3O4", "explicit",        "Fe,Fe,Fe,O,O,O,O", "0-1,0-2,0-3,1-4,1-5,2-6", "Magnetite, the spinel that is naturally magnetised."),
    ("as2o3",      "Arsenic(III) oxide",           "As2O3", "explicit",        "As,As,O,O,O",      "0-1,0-2,0-3,1-4", "A cage-like oxide used as a wood preservative."),
    ("sb2o3",      "Antimony(III) oxide",          "Sb2O3", "explicit",        "Sb,Sb,O,O,O",      "0-1,0-2,0-3,1-4", "A flame-retardant antimony oxide."),
    ("bi2o3",      "Bismuth(III) oxide",           "Bi2O3", "explicit",        "Bi,Bi,O,O,O",      "0-1,0-2,0-3,1-4", "A bismuth oxide used in pigments and ceramics."),
    ("v2o5",       "Vanadium pentoxide",           "V2O5",  "explicit",        "V,V,O,O,O,O,O",    "0-1,0-2,0-3,0-4,1-5,1-6", "The catalyst in the contact process for sulphuric acid."),
    ("cr2o3",      "Chromium(III) oxide",          "Cr2O3", "explicit",        "Cr,Cr,O,O,O",      "0-1,0-2,0-3,1-4", "The green pigment known as chrome green."),
    ("tc2o7",      "Technetium(VII) oxide",        "Tc2O7", "explicit",        "Tc,Tc,O,O,O,O,O,O", "0-1,0-2,0-3,0-4,0-5,1-6,1-7", "A volatile technetium oxide."),
    ("re2o7",      "Rhenium(VII) oxide",           "Re2O7", "explicit",        "Re,Re,O,O,O,O,O,O", "0-1,0-2,0-3,0-4,0-5,1-6,1-7", "The oxide used in rhenium-platinum reforming catalysts."),
    ("moo3",       "Molybdenum trioxide",          "MoO3",  "explicit",        "Mo,O,O,O",         "0-1,0-2,0-3",    "A layered oxide used in hydrodesulphurisation."),
    ("woo3",       "Tungsten trioxide",            "WO3",   "explicit",        "W,O,O,O",          "0-1,0-2,0-3",    "A yellow oxide that colours tungsten bronzes."),
    ("pa2o5",      "Protactinium(V) oxide",        "Pa2O5", "explicit",        "Pa,Pa,O,O,O,O,O",  "0-1,0-2,0-3,0-4,1-5,1-6", "A dense actinide oxide."),
    ("ceo2",       "Cerium dioxide",               "CeO2",  "explicit",        "Ce,O,O",           "0-1,0-2",        "The fluorite-structured catalyst ceramic."),
    ("tho2",       "Thorium dioxide",              "ThO2",  "explicit",        "Th,O,O",           "0-1,0-2",        "A refractory ceramic used in nuclear fuel pellets."),
    ("uo2",        "Uranium dioxide",              "UO2",   "explicit",        "U,O,O",            "0-1,0-2",        "The nuclear fuel ceramic of every reactor."),
    ("npo2",       "Neptunium dioxide",            "NpO2",  "explicit",        "Np,O,O",           "0-1,0-2",        "A neptunium ceramic studied for actinide waste forms."),
    ("puo2",       "Plutonium dioxide",            "PuO2",  "explicit",        "Pu,O,O",           "0-1,0-2",        "The most-studied plutonium fuel ceramic."),
    ("sb2o3_solid", "Antimony(III) oxide solid",   "Sb2O3", "explicit",        "Sb,Sb,O,O,O",      "0-1,0-2,0-3,1-4", "A flame-retardant antimony oxide."),
    ("p4_solid",   "Phosphorus tetrahedron solid", "P4",    "tetrahedron4",    "P,P,P,P",          "0-1,0-2,0-3,0-1,1-2,1-3,2-3", "White phosphorus is a P4 tetrahedron of strained bonds."),
]

# Bond orders keyed by molecule identifier, then by index into the bond list.
BOND_ORDERS = {
    "co2":    {0: 2, 1: 2},
    "co":     {0: 3},
    "o2":     {0: 2},
    "n2":     {0: 3},
    "ch2o":   {2: 2},
    "hno3":   {1: 2},
    "h3po4":  {1: 2},
    "h2so4":  {0: 2, 1: 2},
    "c2h4":   {0: 2},
    "benzene": {1: 2, 3: 2, 5: 2},
}

# Explicit coordinate molecules: id -> list of (x, y, z) in Angstrom.
EXPLICIT_COORDS = {
    "h2so4":      [(0.0, 0.0, 0.0), (1.43, 0.0, 0.0), (-0.48, 1.38, 0.0), (-0.48, -0.69, 1.19),
                   (-0.48, -0.69, -1.19), (-0.10, -1.30, 1.90), (-0.10, -1.30, -1.90)],
    "c2h4":       [(-0.67, 0.0, 0.0), (0.67, 0.0, 0.0), (-1.23, 0.92, 0.0), (-1.23, -0.92, 0.0),
                   (1.23, 0.92, 0.0), (1.23, -0.92, 0.0)],
    "h2o2":       [(-0.75, 0.0, 0.0), (0.75, 0.0, 0.0), (-1.35, -0.85, 0.0), (1.35, -0.85, 0.0)],
    "naoh":       [(0.0, 0.0, 0.0), (1.43, 0.0, 0.0), (2.39, 0.0, 0.0)],
    "hno3":       [(0.0, 0.0, 0.0), (-0.60, 1.04, 0.0), (-0.60, -0.52, 0.90), (1.20, 0.0, 0.0), (2.19, 0.0, 0.0)],
    "h3po4":      [(0.0, 0.0, 0.0), (1.43, 0.0, 0.0), (-0.72, 1.24, 0.0), (-0.72, -0.62, 1.07), (0.0, 0.0, -1.48),
                   (2.35, 0.0, 0.0), (-1.18, 2.04, 0.0), (-1.18, -1.02, 1.76)],
    "ch3oh":      [(0.0, 0.0, 0.0), (1.43, 0.0, 0.0), (0.0, 1.03, 0.0), (-0.51, -0.51, 0.89),
                   (-0.51, -0.51, -0.89), (2.39, 0.0, 0.0)],
    "c2h6":       [(0.0, 0.0, 0.0), (1.53, 0.0, 0.0), (-0.52, 1.02, 0.0), (-0.52, -0.51, 0.89),
                   (-0.52, -0.51, -0.89), (2.05, 0.52, 0.89), (2.05, -0.51, -0.89), (2.05, 0.51, -0.89)],
    "caco3":      [(0.0, 0.0, 1.80), (0.0, 0.0, 0.0), (0.0, 1.28, -0.55), (1.11, -0.64, -0.55), (-1.11, -0.64, -0.55)],
    "baso4":      [(0.0, 0.0, 2.10), (0.0, 0.0, 0.0), (0.0, 1.49, -0.35), (1.29, -0.74, -0.35), (-1.29, -0.74, -0.35),
                   (0.0, 0.0, -1.20)],
    "kmno4":      [(0.0, 0.0, 2.40), (0.0, 0.0, 0.0), (0.0, 1.50, 0.0), (1.30, -0.75, 0.0), (-1.30, -0.75, 0.0),
                   (0.0, 0.0, -1.50)],
    "cuso4":      [(0.0, 0.0, 2.40), (0.0, 0.0, 0.0), (0.0, 1.49, 0.0), (1.29, -0.74, 0.0), (-1.29, -0.74, 0.0),
                   (0.0, 0.0, -1.20)],
    "fe2o3":      [(-0.60, 0.0, 0.0), (0.60, 0.0, 0.0), (0.0, 1.40, 0.0), (0.0, -0.70, 1.21), (0.0, -0.70, -1.21)],
    "fe3o4":      [(-1.10, 0.0, 0.0), (0.55, 0.95, 0.0), (0.55, -0.48, 0.82), (0.0, 0.0, 1.45),
                   (0.0, 1.60, -0.70), (1.35, -0.80, 0.0), (-0.68, -1.00, 1.10)],
    "as2o3":      [(-0.70, 0.0, 0.0), (0.70, 0.0, 0.0), (0.0, 1.60, 0.0), (0.0, -0.80, 1.39), (0.0, -0.80, -1.39)],
    "sb2o3":      [(-0.75, 0.0, 0.0), (0.75, 0.0, 0.0), (0.0, 1.70, 0.0), (0.0, -0.85, 1.47), (0.0, -0.85, -1.47)],
    "bi2o3":      [(-0.80, 0.0, 0.0), (0.80, 0.0, 0.0), (0.0, 1.80, 0.0), (0.0, -0.90, 1.56), (0.0, -0.90, -1.56)],
    "v2o5":       [(-1.20, 0.0, 0.0), (1.20, 0.0, 0.0), (0.0, 1.60, 0.0), (-1.20, -0.80, 1.10),
                   (-1.20, -0.80, -1.10), (1.20, 0.80, 1.10), (1.20, 0.80, -1.10)],
    "cr2o3":      [(-0.80, 0.0, 0.0), (0.80, 0.0, 0.0), (0.0, 1.80, 0.0), (0.0, -0.90, 1.56), (0.0, -0.90, -1.56)],
    "tc2o7":      [(-1.20, 0.0, 0.0), (1.20, 0.0, 0.0), (-2.05, 0.85, 0.0), (-2.05, -0.85, 0.0),
                   (-0.35, 0.0, 1.10), (-0.35, 0.0, -1.10), (1.85, 0.80, 0.0), (1.85, -0.80, 0.0)],
    "re2o7":      [(-1.20, 0.0, 0.0), (1.20, 0.0, 0.0), (-2.05, 0.85, 0.0), (-2.05, -0.85, 0.0),
                   (-0.35, 0.0, 1.10), (-0.35, 0.0, -1.10), (1.85, 0.80, 0.0), (1.85, -0.80, 0.0)],
    "moo3":       [(0.0, 0.0, 0.0), (0.0, 1.80, 0.0), (1.56, -0.90, 0.0), (-1.56, -0.90, 0.0)],
    "woo3":       [(0.0, 0.0, 0.0), (0.0, 1.90, 0.0), (1.65, -0.95, 0.0), (-1.65, -0.95, 0.0)],
    "pa2o5":      [(-1.20, 0.0, 0.0), (1.20, 0.0, 0.0), (0.0, 1.60, 0.0), (-1.20, -0.80, 1.10),
                   (-1.20, -0.80, -1.10), (1.20, 0.80, 1.10), (1.20, 0.80, -1.10)],
    "ceo2":       [(0.0, 0.0, 0.0), (0.0, 1.90, 0.0), (0.0, -0.60, 1.74)],
    "tho2":       [(0.0, 0.0, 0.0), (0.0, 2.00, 0.0), (0.0, -0.60, 1.83)],
    "uo2":        [(0.0, 0.0, 0.0), (0.0, 2.05, 0.0), (0.0, -0.60, 1.87)],
    "npo2":       [(0.0, 0.0, 0.0), (0.0, 2.02, 0.0), (0.0, -0.60, 1.85)],
    "puo2":       [(0.0, 0.0, 0.0), (0.0, 2.02, 0.0), (0.0, -0.60, 1.85)],
}

# Fallback covalent radii (pm) used when the element table has none.
DEFAULT_COV = {
    "H": 31, "He": 28,
}

SUBSHELL_RE = re.compile(r"([1-7])([spdfg])([0-9]+)")


def shells_from_config(config):
    """Return the population of each principal shell, e.g. 1s2 2s2 2p6 -> [2, 8]."""
    shells = {}
    for n_str, _, count_str in SUBSHELL_RE.findall(config):
        n = int(n_str)
        shells[n] = shells.get(n, 0) + int(count_str)
    return [shells[k] for k in sorted(shells)]


def parse_rows():
    elements = []
    seen = set()
    for raw in ROWS.strip().splitlines():
        raw = raw.strip()
        if not raw:
            continue
        f = raw.split("|")
        if len(f) != 21:
            raise SystemExit("Bad field count (%d) in row: %s" % (len(f), raw[:60]))

        def num(value):
            if value == "-":
                return None
            try:
                return float(value)
            except ValueError:
                raise SystemExit("Bad number %r in row: %s" % (value, raw[:60]))

        def integer(value):
            if value == "-":
                return None
            return int(value)

        n = int(f[0])
        if n in seen:
            raise SystemExit("Duplicate atomic number %d" % n)
        seen.add(n)
        if f[4] not in CATEGORIES:
            raise SystemExit("Unknown category %r for element %d" % (f[4], n))

        element = {
            "number": n,
            "symbol": f[1],
            "name": f[2],
            "mass": float(f[3]),
            "category": f[4],
            "group": int(f[5]),
            "period": int(f[6]),
            "fBlock": int(f[7]),
            "configuration": f[8],
            "electronegativity": num(f[9]),
            "atomicRadius": num(f[10]),
            "covalentRadius": num(f[11]),
            "meltingPoint": num(f[12]),
            "boilingPoint": num(f[13]),
            "density": num(f[14]),
            "phase": f[15],
            "discoveryYear": f[16],
            "discoverer": f[17],
            "molecule": f[18],
            "uses": [u for u in f[19].split(";") if u],
            "summary": f[20],
            "shells": shells_from_config(f[8]),
        }
        total = sum(element["shells"])
        if total != n:
            raise SystemExit("Shell populations for %s sum to %d, expected %d"
                             % (f[1], total, n))
        elements.append(element)

    elements.sort(key=lambda e: e["number"])
    if len(elements) != 118:
        raise SystemExit("Expected 118 elements, got %d" % len(elements))
    return elements


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.dirname(here)
    out_path = os.path.join(root, "PeriodicTable", "Resources", "elements.json")

    elements = parse_rows()

    molecules = []
    for mid, name, formula, geometry, atoms, bonds, details in MOLECULES:
        molecules.append({
            "identifier": mid,
            "bondOrders": {str(k): v for k, v in BOND_ORDERS.get(mid, {}).items()},
            "name": name,
            "formula": formula,
            "geometry": geometry,
            "atoms": [a for a in atoms.split(",") if a],
            "bonds": [b for b in bonds.split(",") if b],
            "details": details,
        })

    payload = {
        "generated": "tools/generate_elements.py",
        "categories": CATEGORIES,
        "elements": elements,
        "molecules": molecules,
        "explicitCoordinates": EXPLICIT_COORDS,
        "defaultCovalentRadii": DEFAULT_COV,
    }

    with open(out_path, "w") as handle:
        json.dump(payload, handle, indent=1, sort_keys=False)
        handle.write("\n")

    print("wrote %s" % out_path)
    print("  elements : %d" % len(elements))
    print("  molecules: %d" % len(molecules))
    counts = {}
    for e in elements:
        counts[e["category"]] = counts.get(e["category"], 0) + 1
    for cat in CATEGORIES:
        if cat in counts:
            print("  %-24s %d" % (cat, counts[cat]))


if __name__ == "__main__":
    main()
