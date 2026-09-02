import 'package:mp_core/mp_core.dart';

/// The reference brief this project was modelled on, expressed as a
/// [MissionSpec].
///
/// This is the compiler's acceptance fixture. If a spec of this shape does not
/// compile into a prompt carrying every section, the full rubric, the sixteen
/// numbered artifacts, the six critics and the failure list, then the compiler
/// is not reproducing the thing it exists to reproduce.
MissionSpec referenceSkylineSpec() {
  const List<String> zones = <String>[
    'Lift lobby and arrival',
    'Host station and waiting lounge',
    'Cocktail bar',
    'Lounge seating',
    'Main dining room',
    'Window dining',
    'Open kitchen and pass',
    'Private dining rooms',
    'Wine room',
    'Restrooms',
    'Back of house',
    'Facade and terrace edge',
  ];

  const List<String> zonePurposes = <String>[
    'Compressed, acoustically calm threshold with host signage, coat storage, and a framed first skyline glimpse.',
    'Reservation desk, queue position, soft seating, host storage, and direct control of dining circulation.',
    'Twenty-seat bar with backbar, bottle display, ice and wash stations, undercounter equipment, foot rail, and standing edge.',
    'Low seating clusters, small tables, acoustic canopy, art, and unobstructed service routes.',
    'Sixty to eighty covers in varied two-, four-, and six-seat arrangements with banquettes and generous aisles.',
    'Twenty to thirty premium seats oriented to the skyline without crowding glass maintenance zones.',
    'Visible hot line, plating pass, chef counter, heat lamps, screens, and controlled separation from guests.',
    'Two divisible private rooms with AV, pantry connection, operable partition, art, and acoustic treatment.',
    'Temperature-controlled glazed cellar, display racks, service staging, and a sommelier tasting table.',
    'Luxury washrooms, accessible room, vanity, cubicles, vestibules, and housekeeping storage.',
    'Prep, cold storage, dishwash, dry store, staff route, waste holding, and service elevator interface.',
    'Curtain-wall mullions, insulated glazing, slab edge, maintenance clearance, and reflected interior light.',
  ];

  const List<List<String>> artifacts = <List<String>>[
    <String>['01_lift_lobby_arrival.png', 'Lift lobby arrival', 'Compressed threshold, host cue, coat storage, and first skyline reveal.'],
    <String>['02_host_and_waiting_lounge.png', 'Host and waiting lounge', 'Arrival operation, material transition, and view toward bar.'],
    <String>['03_restaurant_hero.png', 'Restaurant hero', 'Wide view uniting bar, dining layers, open kitchen, windows, and city.'],
    <String>['04_cocktail_bar_front.png', 'Cocktail bar front', "Twenty-seat bar, backbar depth, equipment, patrons' edge, and lighting."],
    <String>['05_behind_bar_operation.png', 'Behind bar operation', 'Ice, sink, rails, refrigeration, glass storage, POS, and service logic.'],
    <String>['06_main_dining_room.png', 'Main dining room', 'Varied tables, banquettes, circulation, table lighting, and skyline depth.'],
    <String>['07_window_dining.png', 'Window dining', 'Premium seats with balanced interior/exterior exposure and facade detail.'],
    <String>['08_open_kitchen_and_pass.png', 'Open kitchen and pass', 'Hot line, ventilation, plating, chef counter, and guest boundary.'],
    <String>['09_private_dining_suite.png', 'Private dining suite', 'Operable division, pantry support, AV, art, and acoustic enclosure.'],
    <String>['10_wine_room.png', 'Wine room', 'Bottle density, cooling details, tasting table, and glass enclosure.'],
    <String>['11_restroom_vanity.png', 'Restroom vanity', 'Stone, mirror, fixtures, cubicle threshold, and accessible quality.'],
    <String>['12_back_of_house_route.png', 'Back of house route', 'Prep, storage, dishwash, service connection, and non-public completeness.'],
    <String>['13_sky_terrace.png', 'Sky terrace', 'Wind screens, seating, planters, guards, drainage, and skyline.'],
    <String>['14_table_setting_detail.png', 'Table setting detail', 'Cutlery, glass, porcelain, linen, menu, lamp, and food detail.'],
    <String>['15_bar_material_detail.png', 'Bar material detail', 'Stone edge, bronze trim, leather stool, foot rail, bottles, and reflections.'],
    <String>['16_ceiling_and_reverse_audit.png', 'Ceiling and reverse audit', 'Service stations, room backs, facade junctions, and ceiling coordination.'],
  ];

  return MissionSpec(
    id: 'ref-skyline',
    taskId: 'skyline-restaurant-bar',
    title: 'Skyline Restaurant and Cocktail Bar',
    presetId: 'scene_3d',
    missionStatement: const SpecField<String>(
      value:
          'Build a photorealistic, fully editable destination restaurant and '
          'cocktail bar on a high-rise sky floor — from art bible and renderable '
          'graybox, through an evidence-based render-review loop with six '
          'fresh-context critics, to a sixteen-camera final delivery governed by '
          'a 100-point rubric and cold-start validation.',
      resolution: FieldResolution.confirmed,
      provenance: FieldProvenance.user,
    ),
    definingStory: const SpecField<String>(
      value:
          'Guests progress from a compressed stone arrival through a glowing bar '
          'and layered dining room toward panoramic windows, while kitchen and '
          'service choreography remain visibly plausible.',
      resolution: FieldResolution.confirmed,
      provenance: FieldProvenance.user,
    ),
    scale: const SpecField<String>(
      value: 'Approximately 1,200 m² on a single high-rise floor. Blender units in metres.',
      resolution: FieldResolution.confirmed,
      provenance: FieldProvenance.user,
    ),
    audience: const SpecField<String>(
      value:
          'Judged as polished architectural visualisation with the density and '
          'environmental storytelling expected of a premium game environment.',
      resolution: FieldResolution.confirmed,
      provenance: FieldProvenance.user,
    ),
    runtime: const RuntimeProfile(
      compute: 'GPU render device; no display server.',
      primaryTool:
          'Blender via the command line. Write Blender Python and debug renders '
          'directly through the CLI. No MCP, no add-on assistants.',
      harness: 'Subagents required for the review loop (fresh-context critics).',
      startingAssets:
          'No pre-made scripts, plugins, MCP servers, or skills. Everything is '
          'generated from scratch.',
      tokenBudget: '100 million tokens',
      wallClock: 'Up to 12 hours',
      autonomy: 'Fully autonomous, zero human intervention.',
    ),
    regions: <ScopeRegion>[
      for (int i = 0; i < zones.length; i++)
        ScopeRegion(
          id: 'zone_${i + 1}',
          name: zones[i],
          purpose: zonePurposes[i],
        ),
    ],
    relationships: const <String>[
      'Host controls dining and lounge entry while a separate service route links kitchen, pass, private rooms, and bar.',
      'Open kitchen is visually prominent but odour, heat, waste, and dish circulation remain separated from guest paths.',
      'Restrooms are discreetly accessible without passing through service areas or becoming visible from dining tables.',
    ],
    families: const <ComponentFamily>[
      ComponentFamily(
        id: 'dining',
        name: 'Dining furniture',
        description: 'Tables, chairs and banquettes across the dining room.',
        minimumCount: 130,
        members: <String>[
          '30 two-top modules',
          '12 four-tops',
          '4 six-person arrangements',
          '6 banquette segments',
          '130 dining chairs',
        ],
        variationRule:
            'Vary silhouette, orientation, wear state, accessories, and table-setting state.',
      ),
      ComponentFamily(
        id: 'bar',
        name: 'Bar equipment',
        description: 'Working bar with real service depth.',
        members: <String>[
          'bottle shelves', 'glass racks', 'speed rails', 'sinks', 'ice wells',
          'taps', 'refrigeration', 'dishwasher', 'garnish trays', 'POS',
          'bar tools', 'foot rail', 'undercounter access',
        ],
      ),
      ComponentFamily(
        id: 'kitchen',
        name: 'Kitchen equipment',
        description: 'A functioning hot line and pass.',
        members: <String>[
          'ranges', 'plancha', 'ovens', 'refrigeration', 'stainless prep',
          'ventilation hood', 'salamander', 'heated pass', 'plate shelves',
          'chef screens', 'wash-up', 'safety clearances',
        ],
      ),
      ComponentFamily(
        id: 'wine',
        name: 'Wine display',
        description: 'Bottle positions using efficient instances.',
        minimumCount: 500,
        variationRule: 'Angled display, bulk racks, cooling grilles, inventory labels.',
      ),
      ComponentFamily(
        id: 'tabletop',
        name: 'Tabletop props',
        description: 'Table settings at believable states of use.',
        members: <String>[
          'plates', 'cutlery', 'stemware', 'water glasses', 'folded napkins',
          'lamps', 'menus', 'serving trays', 'carafes',
        ],
      ),
      ComponentFamily(
        id: 'skyline',
        name: 'City context',
        description: 'The world outside the glass.',
        members: <String>[
          'layered towers', 'rooftop plant', 'street grids', 'aircraft beacons',
          'distant water or haze', 'varied illuminated window patterns with parallax',
        ],
      ),
    ],
    evidence: <EvidenceArtifact>[
      for (int i = 0; i < artifacts.length; i++)
        EvidenceArtifact(
          ordinal: i + 1,
          fileName: artifacts[i][0],
          name: artifacts[i][1],
          proves: artifacts[i][2],
          minimumSpec: i == 2 ? '2560x1440' : '1920x1080',
          isHero: i == 2,
        ),
    ],
    quality: const QualityLanguage(
      palette: <String>[
        'book-matched dark stone at arrival and bar',
        'smoked oak wall and ceiling panels with fine shadow gaps',
        'deep oxblood or tobacco leather banquettes',
        'warm gray wool and bouclé lounge upholstery',
        'aged bronze or champagne-brass accents used sparingly',
        'dark terrazzo and oak dining floors with correct transitions',
        'stainless steel and heat-darkened metal in the kitchen',
        'low-iron facade glass and softly reflective skyline glazing',
      ],
      materials: <String>[
        'Physically plausible Principled BSDF response at real-world texture scale.',
        'Directional grain, brushed finishes, fabric weave and water streaking must follow construction and gravity.',
        'Distinguish materials through base colour, roughness, normal scale, metallic response and edge behaviour — not one repeated noise texture.',
      ],
      atmosphere:
          'Blue hour transitioning into night. A dense, layered skyline with '
          'neighbouring towers, streets far below, distant haze, and enough '
          'exposure detail to avoid a flat black backdrop. Warm 2400–3000 K '
          'table and cove practicals, bright neutral kitchen task light, '
          'restrained backbar glow. Use AgX for controlled highlight roll-off.',
      compositionRules: <String>[
        'Compose each principal view with foreground, midground and background structure.',
        'Avoid uniformly lit catalogue views, arbitrary Dutch angles, crushed blacks, blank white windows, or depth of field so shallow the scene cannot be evaluated.',
      ],
      detailStandard:
          'Each important asset must work at three reading distances: a '
          'recognisable macro silhouette, functional medium-scale construction, '
          'and close-range joins, hardware, fasteners, seams, gaskets and '
          'contact with adjacent surfaces. Thin boxes with textures are not '
          'acceptable substitutes for visible functional structure.',
      storytelling: <String>[
        'Partially occupied table settings, a decanted wine service, menus, and one recently cleared setting.',
        'Bartender mise en place, citrus, shakers, strainers, clean and used glass zones, and a ticket rail.',
        'Plating tweezers, towels, pans, ingredient containers, ticket screens, and organised kitchen activity.',
        'Coats at host storage, reservation materials, a discreet bag stool, and a waiting drink.',
        'Terrace condensation, wind-shifted cushions, wet drink rings, and carefully maintained planters.',
      ],
      avoid: <String>[
        'A generic hotel lounge',
        'A room filled with repeated tables',
        'Nightclub neon',
        'Gold-plated excess',
        'An unusable open kitchen',
        'Pure-black windows',
        'A single skyline-facing camera set',
      ],
    ),
    buildOrder: const <BuildStep>[
      BuildStep(
        ordinal: 1,
        name: 'Direction',
        instruction:
            'Convert the brief into an art bible, measured spatial plan, asset '
            'inventory, material language, fixed camera set, technical budget, '
            'and acceptance map.',
      ),
      BuildStep(
        ordinal: 2,
        name: 'Graybox',
        instruction:
            'Build a complete graybox covering the whole environment — including '
            'context, circulation, service zones, primary silhouettes, and all '
            'fixed cameras. Use real dimensions and human-scale proxies.',
      ),
      BuildStep(
        ordinal: 3,
        name: 'Cheap evidence',
        instruction:
            'Render inexpensive preview judgeset images immediately to expose '
            'layout, scale, adjacency, and camera failures.',
      ),
      BuildStep(
        ordinal: 4,
        name: 'Asset families',
        instruction:
            'Replace placeholders with coherent asset families: macro '
            'composition first, functional medium structure second, close '
            'manufacturing detail third. Keep the entire scene renderable after '
            'each asset-family pass.',
      ),
      BuildStep(
        ordinal: 5,
        name: 'Final dressing',
        instruction:
            'Establish final material separation, environmental context, '
            'lighting hierarchy, storytelling props, and camera composition. '
            'Reserve high samples and expensive effects for confirmed final views.',
      ),
    ],
    review: const ReviewLoopSpec(
      minimumCycles: 4,
      critics: <Critic>[
        Critic(id: 'c1', name: 'Circulation critic', judges: 'Guest arrival, cover count, table clearances, service paths, restroom access, and terrace safety.'),
        Critic(id: 'c2', name: 'Operations critic', judges: 'Bar, open kitchen, pass, storage, wash-up, wine service, and back-of-house plausibility.'),
        Critic(id: 'c3', name: 'Craft critic', judges: 'Material restraint, joinery, furniture hierarchy, acoustic comfort, and crafted detail.'),
        Critic(id: 'c4', name: 'Dressing critic', judges: 'Table settings, bar mise en place, kitchen props, scale, and believable use.'),
        Critic(id: 'c5', name: 'Lighting critic', judges: 'Interior/exterior exposure, practical pools, reflections, skyline depth, and focal hierarchy.'),
        Critic(id: 'c6', name: 'Technical critic', judges: 'Render stability, paths, organisation, instances, material links, and delivery.'),
      ],
    ),
    rubric: const Rubric(
      exitThreshold: 90,
      categories: <RubricCategory>[
        RubricCategory(id: 'r1', name: 'Circulation and capacity', weight: 15, minimum: 12.8, criteria: 'Arrival, covers, service routes, privacy, accessibility, terrace logic'),
        RubricCategory(id: 'r2', name: 'Operational credibility', weight: 20, minimum: 17.0, criteria: 'Kitchen, pass, bar equipment, storage, wine, wash-up, service detail'),
        RubricCategory(id: 'r3', name: 'Asset density and craft', weight: 15, minimum: 12.8, criteria: 'Quantity, variety, craft, and close-range credibility'),
        RubricCategory(id: 'r4', name: 'Architecture and construction', weight: 15, minimum: 12.8, criteria: 'Proportion, joinery, construction, acoustics, restrained finish quality'),
        RubricCategory(id: 'r5', name: 'Light and atmosphere', weight: 20, minimum: 17.0, criteria: 'Blue-hour balance, practical hierarchy, reflections, exposure, city depth'),
        RubricCategory(id: 'r6', name: 'Composition and storytelling', weight: 10, minimum: 8.5, criteria: 'Camera hierarchy, intimacy, movement, and lived-in storytelling'),
        RubricCategory(id: 'r7', name: 'Technical delivery', weight: 5, minimum: 4.3, criteria: 'Clean editable scene, performance, dependencies, and outputs'),
      ],
    ),
    validation: const ValidationPlan(
      coldStartProcedure:
          'Save all files, close the working scene, reopen '
          '`skyline_restaurant_bar_final.blend` from a clean Blender invocation, '
          'and re-render at least the hero camera through the documented command.',
      checks: <String>[
        'All dependencies resolve.',
        'No script or render error occurs.',
        'Output dimensions are correct.',
        'Every file in renders/final/ comes from the latest scene.',
        'The contact sheet and reports are refreshed.',
      ],
    ),
    deliverables: const DeliverablePlan(
      projectDirectory: 'skyline_restaurant_bar',
      tree: <String, String>{
        'skyline_restaurant_bar_final.blend': 'the final editable Blender scene',
        'README.md': 'structure, version, controls, deps, rerender',
        'scripts/': 'scene-generation and rerender utilities',
        'textures/': 'locally generated or baked textures, if used',
        'renders/final/': 'the complete numbered final image set 01-16',
        'renders/contact_sheet.jpg': 'readable overview of all final images',
      },
      namingRules: <String>[
        'Organise architecture, structural systems, context, furnishings, small props, lighting, cameras, and render helpers into clearly named collections.',
        'Use descriptive English object, material, image, node group, camera, and light names.',
        'Do not leave the final file dominated by Cube.001-style names.',
      ],
      portabilityRules: <String>[
        'All external files must use portable relative paths or be packed into the .blend.',
        'The delivered .blend must remain editable: preserve useful modifiers, instances, collections, camera names, and material structure rather than flattening the environment into an opaque mesh.',
      ],
    ),
    failureConditions: const <FailureCondition>[
      FailureCondition(text: 'Dining capacity is represented by rigid copied rows with no hierarchy or service clearances.'),
      FailureCondition(text: 'The bar lacks real equipment, bartender work depth, refrigeration, sinks, or storage.'),
      FailureCondition(text: 'Kitchen and guest circulation conflict, or the open kitchen is only a decorative backdrop.'),
      FailureCondition(text: 'The skyline is black, flat, repeated, overexposed, or visibly too close to the facade.'),
      FailureCondition(text: 'Luxury depends on excessive gold, glossy marble, and bloom rather than proportion, craft, and light.'),
      FailureCondition(text: 'Any required zone is missing, represented only by a sign, or built as a camera-facing shell.'),
      FailureCondition(text: 'Multiple final views reveal floating assets, severe intersections, incorrect scale, missing faces, broken normals, or default materials.'),
      FailureCondition(text: 'Darkness, fog, depth of field, cropping, reflections, or camera placement are used to conceal incomplete work.'),
      FailureCondition(text: 'Only one direction is finished, while reverse angles, circulation paths, ceilings, service edges, or exterior boundaries collapse under inspection.'),
      FailureCondition(text: 'renders/final/ is absent, contains viewport screenshots, or does not cover the required scene.'),
      FailureCondition(text: 'The final .blend cannot open and render with all required textures and linked resources available.'),
    ],
  );
}
