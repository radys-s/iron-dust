const TILE = { VOID: 0, PRAIRIE: 1, OWNED: 2, RAILWAY: 3, TOWN: 4, DESERT: 5, RIVER: 6, MOUNTAIN: 7, MINE: 8, FOG: 9, ENEMY: 10 };

const BIOME_BASE_COLORS = {
    [TILE.PRAIRIE]: '#6db33f',
    [TILE.OWNED]: '#4a8f2a',
    [TILE.RAILWAY]: '#7a6e50',
    [TILE.TOWN]: '#c4a84a',
    [TILE.DESERT]: '#e8b84a',
    [TILE.RIVER]: '#2878b8',
    [TILE.MOUNTAIN]: '#7a8a70',
    [TILE.MINE]: '#8a6a48',
    [TILE.FOG]: '#283040',
    [TILE.ENEMY]: '#6a1010'
};

const RESOURCE_META = [
    { key: 'gold', label: 'Zlato', icon: '🪙', labelCase: 'zlata', costClass: 'cost-gold' },
    { key: 'food', label: 'Jídlo', icon: '🌾', labelCase: 'jídla', costClass: 'cost-food' },
    { key: 'iron', label: 'Železo', icon: '⚙', labelCase: 'železa', costClass: 'cost-iron' },
    { key: 'wood', label: 'Dřevo', icon: '🪵', labelCase: 'dřeva', costClass: 'cost-wood' },
    { key: 'coal', label: 'Uhlí', icon: '⬛', labelCase: 'uhlí', costClass: 'cost-coal' },
    { key: 'salt', label: 'Sůl', icon: '🧂', labelCase: 'soli', costClass: 'cost-salt' }
];

const RESOURCE_META_MAP = Object.fromEntries(RESOURCE_META.map((resource) => [resource.key, resource]));
const RESOURCE_KEYS = RESOURCE_META.map((resource) => resource.key);

const TILE_NAMES = {
    [TILE.PRAIRIE]: 'Prérie',
    [TILE.OWNED]: 'Vlastněné území',
    [TILE.RAILWAY]: 'Železnice',
    [TILE.TOWN]: 'Dustfall',
    [TILE.DESERT]: 'Poušť',
    [TILE.RIVER]: 'Řeka Colorado',
    [TILE.MOUNTAIN]: 'Pohoří',
    [TILE.MINE]: 'Důl',
    [TILE.FOG]: 'Neznámé území',
    [TILE.ENEMY]: 'Harlan-Voss území'
};

const TILE_DESCRIPTIONS = {
    [TILE.PRAIRIE]: 'Úrodná půda vhodná pro osídlení a zemědělství.',
    [TILE.OWNED]: 'Vaše území. Zde můžete stavět a rozvíjet infrastrukturu.',
    [TILE.RAILWAY]: 'Klíčová tepna regionu. Umožňuje rychlý transport a obchod.',
    [TILE.TOWN]: 'Srdce vašeho impéria. Zde se kříží cesty a osudy.',
    [TILE.DESERT]: 'Vyprahlá země skrývající ložiska soli a vzácné oázy.',
    [TILE.RIVER]: 'Zdroj vody a obživy. Možnost rybolovu a rýžování zlata.',
    [TILE.MOUNTAIN]: 'Těžko prostupný terén bohatý na rudu a strategické body.',
    [TILE.MINE]: 'Průmyslový uzel pro těžbu uhlí a železa.',
    [TILE.FOG]: 'Zahalené tajemstvím. Vyšlete průzkumníka k odhalení.',
    [TILE.ENEMY]: 'Kontrolováno korporací Harlan-Voss. Vstup na vlastní nebezpečí.'
};

const TILE_RESOURCE_HINTS = {
    [TILE.PRAIRIE]: 'Jídlo',
    [TILE.OWNED]: 'Jídlo a dřevo',
    [TILE.RAILWAY]: 'Zlato',
    [TILE.TOWN]: 'Zlato',
    [TILE.DESERT]: 'Sůl',
    [TILE.RIVER]: 'Jídlo',
    [TILE.MOUNTAIN]: 'Ruda',
    [TILE.MINE]: 'Železo a uhlí',
    [TILE.FOG]: '',
    [TILE.ENEMY]: 'Nebezpečí'
};

const TILE_ACTIONS = {
    [TILE.PRAIRIE]: ['Vyslat průzkumníka', 'Postavit osadu', 'Hledat suroviny'],
    [TILE.OWNED]: ['Stavět budovu', 'Vylepšit cestu', 'Přidat farmu', 'Přesunout karavanu'],
    [TILE.RAILWAY]: ['Opravit koleje', 'Přidat zastávku', 'Zablokovat trasu'],
    [TILE.TOWN]: ['Správa města', 'Obchodovat', 'Stavba budov', 'Nábor žoldáků'],
    [TILE.DESERT]: ['Průzkum oázy', 'Karavana pouští', 'Těžit sůl'],
    [TILE.RIVER]: ['Postavit přívoz', 'Rybolov', 'Hledat zlato (vzácné)'],
    [TILE.MOUNTAIN]: ['Průzkum průsmyku', 'Těžit rudu', 'Postavit strážní věž'],
    [TILE.MINE]: ['Těžit stříbro', 'Těžit uhlí', 'Vylepšit důl', 'Přidat lékaře'],
    [TILE.FOG]: ['Prozkoumat oblast'],
    [TILE.ENEMY]: ['Zaútočit']
};

const TECH_NODES = [
    { id: 'forge', branch: 'industry', tier: 1, name: 'Kovárna', cost: 1, desc: '+2 tech body každé 3 tahy navíc.', requires: [] },
    { id: 'steel', branch: 'industry', tier: 2, name: 'Ocel', cost: 2, desc: '+10% zlato z železnice a města.', requires: ['forge'] },
    { id: 'steam', branch: 'industry', tier: 3, name: 'Parní stroj', cost: 3, desc: '+50% produkce budov.', requires: ['steel'] },
    { id: 'coach', branch: 'transport', tier: 1, name: 'Dostavník', cost: 1, desc: 'Dostavník přijíždí častěji.', requires: [] },
    { id: 'telegraph', branch: 'transport', tier: 2, name: 'Telegraf', cost: 2, desc: 'Průzkum levnější a odhalí sousedy.', requires: ['coach'] },
    { id: 'express', branch: 'transport', tier: 2, name: 'Expresní linka', cost: 2, desc: '+10% zlato z železnice a města.', requires: ['coach'] },
    { id: 'militia', branch: 'war', tier: 1, name: 'Milice', cost: 1, desc: '+síla při útoku na H-V území.', requires: [] },
    { id: 'escort', branch: 'war', tier: 2, name: 'Eskorta', cost: 2, desc: 'Karavana méně riskuje.', requires: ['militia'] },
    { id: 'council', branch: 'politics', tier: 1, name: 'Městská rada', cost: 1, desc: '+reputace osadníků (malý bonus).', requires: [] },
    { id: 'federal', branch: 'politics', tier: 2, name: 'Federální kontakty', cost: 2, desc: '+reputace obchodníků (malý bonus).', requires: ['council'] }
];

const TILE_YIELDS = {
    [TILE.PRAIRIE]: { food: 3 },
    [TILE.OWNED]: { food: 2, wood: 1 },
    [TILE.MINE]: { iron: 8, coal: 5 },
    [TILE.RIVER]: { food: 2 },
    [TILE.TOWN]: { gold: 15 },
    [TILE.RAILWAY]: { gold: 5 }
};

const BUILDABLES = [
    {
        name: 'Poštovní stanice',
        costs: { gold: 150, wood: 20 },
        effect: '+dostavník frekvence, +8 zlata/tah',
        production: { gold: 8 },
        icon: '✉'
    },
    {
        name: 'Farma',
        costs: { gold: 80, wood: 30 },
        effect: '+12 jídla za tah',
        production: { food: 12 },
        icon: '⚒'
    },
    {
        name: 'Kovárna',
        costs: { gold: 200, iron: 15, coal: 10 },
        effect: '+15 železa/tah, odemyká zbraně',
        production: { iron: 15 },
        icon: '⚒'
    },
    {
        name: 'Sklad',
        costs: { gold: 120, wood: 40, iron: 5 },
        effect: '+80 kapacity surovin',
        production: {},
        icon: '🏚'
    },
    {
        name: 'Strážní věž',
        costs: { gold: 150, wood: 25, iron: 10 },
        effect: '+obrana, -riziko přepadení',
        production: {},
        icon: '🗼'
    },
    {
        name: 'Lékárna',
        costs: { gold: 180, iron: 8, salt: 15 },
        effect: '+spokojenost osadníků, léčí zranění',
        production: {},
        icon: '+'
    },
    {
        name: 'Solárna',
        costs: { gold: 100, wood: 10 },
        effect: '+10 soli/tah',
        production: { salt: 10 },
        icon: 'S'
    },
    {
        name: 'Mlýn',
        costs: { gold: 90, wood: 35 },
        effect: '+8 jídla, +5 zlata/tah',
        production: { food: 8, gold: 5 },
        icon: 'M'
    }
];

const MAP_DATA = [
    [0, 0, 0, 0, 0, 2, 2, 2, 9, 9, 9, 9, 0, 0, 0, 0],
    [0, 0, 0, 0, 2, 2, 2, 2, 2, 9, 9, 9, 9, 0, 0, 0],
    [0, 0, 0, 2, 2, 2, 1, 1, 2, 2, 9, 9, 9, 0, 0, 0],
    [0, 0, 2, 2, 2, 1, 1, 1, 1, 2, 2, 9, 9, 9, 0, 0],
    [0, 2, 2, 2, 1, 1, 3, 1, 1, 6, 2, 2, 9, 9, 0, 0],
    [0, 2, 5, 5, 1, 2, 2, 4, 6, 6, 2, 2, 2, 9, 0, 0],
    [0, 3, 3, 3, 3, 3, 4, 4, 4, 3, 3, 3, 3, 9, 0, 0],
    [0, 5, 5, 8, 1, 2, 4, 4, 6, 6, 7, 7, 2, 9, 0, 0],
    [0, 0, 5, 8, 8, 1, 4, 6, 6, 2, 7, 7, 2, 0, 0, 0],
    [0, 0, 5, 5, 8, 10, 10, 10, 2, 2, 2, 7, 0, 0, 0, 0],
    [0, 0, 0, 5, 10, 10, 10, 10, 10, 2, 2, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 10, 10, 10, 10, 2, 2, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 10, 10, 2, 0, 0, 0, 0, 0, 0, 0, 0]
];

const BASE_STORAGE_CAPACITY = 600;
const BUILD_UPKEEP_GOLD = 5;
const SOLDIER_UPKEEP_GOLD = 20;
const VALID_BUILD_TILE_TYPES = new Set([TILE.OWNED, TILE.TOWN]);

function createEmptyResources() {
    return { gold: 0, food: 0, iron: 0, wood: 0, coal: 0, salt: 0 };
}

function createResourceChangeBuckets() {
    return {
        gold: [],
        food: [],
        iron: [],
        wood: [],
        coal: [],
        salt: []
    };
}

function addResources(target, source = {}) {
    RESOURCE_KEYS.forEach((key) => {
        target[key] += source[key] || 0;
    });
    return target;
}

function clamp(value, min, max) {
    return Math.min(Math.max(value, min), max);
}

function hasTech(gameState, techId) {
    return !!gameState?.techTree?.researched?.includes(techId);
}

function getExploreCost(gameState) {
    return hasTech(gameState, 'telegraph') ? 35 : 50;
}

function revealAdjacentFog(row, col) {
    const neighbors = [
        [row - 1, col],
        [row + 1, col],
        [row, col - 1],
        [row, col + 1]
    ];
    neighbors.forEach(([neighborRow, neighborCol]) => {
        if (neighborRow < 0 || neighborRow >= MAP_DATA.length || neighborCol < 0 || neighborCol >= MAP_DATA[0].length) {
            return;
        }
        if (MAP_DATA[neighborRow][neighborCol] === TILE.FOG) {
            MAP_DATA[neighborRow][neighborCol] = TILE.PRAIRIE;
        }
    });
}

function hexToRgb(hex) {
    const normalized = hex.replace('#', '');
    return {
        r: parseInt(normalized.slice(0, 2), 16),
        g: parseInt(normalized.slice(2, 4), 16),
        b: parseInt(normalized.slice(4, 6), 16)
    };
}

function rgbToHex({ r, g, b }) {
    return `#${[r, g, b].map((value) => clamp(Math.round(value), 0, 255).toString(16).padStart(2, '0')).join('')}`;
}

function blendHex(colorA, colorB, ratio = 0.5) {
    const a = hexToRgb(colorA);
    const b = hexToRgb(colorB);
    return rgbToHex({
        r: a.r * ratio + b.r * (1 - ratio),
        g: a.g * ratio + b.g * (1 - ratio),
        b: a.b * ratio + b.b * (1 - ratio)
    });
}

function multiplyHex(hex, multiplier) {
    const rgb = hexToRgb(hex);
    return rgbToHex({
        r: rgb.r * multiplier,
        g: rgb.g * multiplier,
        b: rgb.b * multiplier
    });
}

function averageHex(colors) {
    if (!colors.length) {
        return '#000000';
    }
    const total = colors.reduce((accumulator, color) => {
        const rgb = hexToRgb(color);
        accumulator.r += rgb.r;
        accumulator.g += rgb.g;
        accumulator.b += rgb.b;
        return accumulator;
    }, { r: 0, g: 0, b: 0 });

    return rgbToHex({
        r: total.r / colors.length,
        g: total.g / colors.length,
        b: total.b / colors.length
    });
}

function getTileBaseColor(type) {
    return BIOME_BASE_COLORS[type] || '#000000';
}

function getNeighborTypes(col, row) {
    const positions = [
        [row - 1, col],
        [row + 1, col],
        [row, col - 1],
        [row, col + 1]
    ];

    return positions.map(([neighborRow, neighborCol]) => {
        if (neighborRow < 0 || neighborRow >= MAP_DATA.length || neighborCol < 0 || neighborCol >= MAP_DATA[0].length) {
            return TILE.VOID;
        }
        return MAP_DATA[neighborRow][neighborCol];
    });
}

function getBlendedTopColor(col, row, type) {
    const ownColor = getTileBaseColor(type);
    const neighbors = getNeighborTypes(col, row);
    const allSameOrVoid = neighbors.every((neighborType) => neighborType === type || neighborType === TILE.VOID);
    if (allSameOrVoid) {
        return ownColor;
    }

    const neighborColors = neighbors
        .filter((neighborType) => neighborType !== type && neighborType !== TILE.VOID)
        .map((neighborType) => getTileBaseColor(neighborType));

    if (!neighborColors.length) {
        return ownColor;
    }

    return blendHex(ownColor, averageHex(neighborColors), 0.7);
}

function getTileName(type) {
    return TILE_NAMES[type] || 'Pustina';
}

function getTileDescription(type) {
    return TILE_DESCRIPTIONS[type] || '';
}

function getTileResourceHint(type) {
    return TILE_RESOURCE_HINTS[type] || '';
}

function getBuildingAt(col, row) {
    return window.GAME?.buildings.find((building) => building.col === col && building.row === row) || null;
}

function isTownRailTile(col, row, type) {
    return type === TILE.TOWN && row === 6 && col >= 6 && col <= 8;
}

function canBuildOnTile(type) {
    return VALID_BUILD_TILE_TYPES.has(type);
}

function getLocationLabel(col, row, type) {
    if (type === TILE.TOWN) {
        return 'Dustfall';
    }
    return `sektor ${col + 1}:${row + 1}`;
}

function calculateEconomyState(gameState = window.GAME) {
    const tileProduction = createEmptyResources();
    const buildingProduction = createEmptyResources();
    const gross = createEmptyResources();
    const counts = {};
    const buildings = gameState?.buildings || [];
    const soldiersReputation = gameState?.reputation?.soldiers || 0;
    const population = gameState?.population || 0;
    const transitMultiplier = 1 + (hasTech(gameState, 'express') ? 0.1 : 0) + (hasTech(gameState, 'steel') ? 0.1 : 0);

    MAP_DATA.forEach((row) => {
        row.forEach((type) => {
            if (!TILE_YIELDS[type]) {
                return;
            }
            counts[type] = (counts[type] || 0) + 1;
            const baseYield = TILE_YIELDS[type];
            const perTile = { ...baseYield };
            if (perTile.gold && (type === TILE.RAILWAY || type === TILE.TOWN)) {
                perTile.gold = Math.round(perTile.gold * transitMultiplier);
            }
            addResources(tileProduction, perTile);
        });
    });

    buildings.forEach((building) => {
        addResources(buildingProduction, building.production || {});
    });

    if (hasTech(gameState, 'steam')) {
        RESOURCE_KEYS.forEach((key) => {
            buildingProduction[key] = Math.round(buildingProduction[key] * 1.5);
        });
    }

    addResources(gross, tileProduction);
    addResources(gross, buildingProduction);

    const storageCapacity = BASE_STORAGE_CAPACITY + buildings.filter((building) => building.name === 'Sklad').length * 80;
    const consumption = createEmptyResources();
    consumption.food = Math.floor(population / 50);
    consumption.gold = buildings.length * BUILD_UPKEEP_GOLD + (soldiersReputation > 60 ? SOLDIER_UPKEEP_GOLD : 0);

    const net = createEmptyResources();
    RESOURCE_KEYS.forEach((key) => {
        net[key] = gross[key] - consumption[key];
    });

    return {
        counts,
        tileProduction,
        buildingProduction,
        gross,
        consumption,
        net,
        storageCapacity
    };
}

function refreshProduction() {
    if (!window.GAME) {
        return;
    }
    window.GAME.production = calculateEconomyState(window.GAME);
}

function showResourceIndicator(resourceKey, delta) {
    if (!window.GAME || !delta) {
        return;
    }

    const bucket = window.GAME.resourceChanges[resourceKey];
    if (!bucket) {
        return;
    }

    const indicatorId = Date.now() + Math.random();
    bucket.push({
        id: indicatorId,
        text: `${delta > 0 ? '+' : ''}${delta}`,
        className: delta > 0 ? 'resource-change-positive' : 'resource-change-negative'
    });

    setTimeout(() => {
        window.GAME.resourceChanges[resourceKey] = window.GAME.resourceChanges[resourceKey].filter((item) => item.id !== indicatorId);
    }, 1200);
}

function applyResourceDelta(resourceKey, delta, options = {}) {
    if (!window.GAME || !delta) {
        return 0;
    }

    const currentValue = window.GAME.resources[resourceKey] || 0;
    let nextValue = currentValue + delta;

    if (resourceKey === 'gold') {
        nextValue = Math.max(0, nextValue);
    } else {
        const capacity = window.GAME.production?.storageCapacity || BASE_STORAGE_CAPACITY;
        nextValue = clamp(nextValue, 0, capacity);
    }

    const appliedDelta = nextValue - currentValue;
    if (!appliedDelta) {
        return 0;
    }

    window.GAME.resources[resourceKey] = nextValue;
    if (options.showIndicator !== false) {
        showResourceIndicator(resourceKey, appliedDelta);
    }
    return appliedDelta;
}

function applyResourceBundle(bundle = {}, factor = 1, options = {}) {
    const result = createEmptyResources();
    RESOURCE_KEYS.forEach((key) => {
        result[key] = applyResourceDelta(key, (bundle[key] || 0) * factor, options);
    });
    return result;
}

function getMissingCosts(costs, gameState = window.GAME) {
    return Object.entries(costs || {})
        .filter(([resourceKey, amount]) => (gameState?.resources?.[resourceKey] || 0) < amount)
        .map(([resourceKey, amount]) => ({
            key: resourceKey,
            amount,
            missing: amount - (gameState?.resources?.[resourceKey] || 0),
            meta: RESOURCE_META_MAP[resourceKey]
        }));
}

function canAffordCosts(costs, gameState = window.GAME) {
    return getMissingCosts(costs, gameState).length === 0;
}

function formatProductionLine(production = {}) {
    const parts = Object.entries(production)
        .filter(([, amount]) => amount)
        .map(([resourceKey, amount]) => `+${amount} ${RESOURCE_META_MAP[resourceKey]?.icon || ''}`);
    return parts.length ? parts.join(' ') : 'Bez produkce';
}

function addStoryEntry(text) {
    if (!window.GAME) {
        return;
    }
    window.GAME.storyLog.push({
        year: window.GAME.year,
        season: window.GAME.season,
        turnCount: window.GAME.turnCount,
        text
    });
}

function requestSceneRefresh() {
    window.dispatchEvent(new CustomEvent('mapNeedsRender'));
}

function notify(text, type = 'info') {
    if (!window.GAME) {
        return;
    }

    const id = Date.now() + Math.random();
    if (window.GAME.notifications.length >= 4) {
        window.GAME.notifications.shift();
    }

    const notification = { id, text, type, stateClass: 'notif-enter' };
    window.GAME.notifications.push(notification);

    requestAnimationFrame(() => {
        const found = window.GAME.notifications.find((item) => item.id === id);
        if (found) {
            found.stateClass = 'notif-active';
        }
    });

    setTimeout(() => {
        const found = window.GAME.notifications.find((item) => item.id === id);
        if (found) {
            found.stateClass = 'notif-exit';
        }
    }, 4600);

    setTimeout(() => {
        window.GAME.notifications = window.GAME.notifications.filter((item) => item.id !== id);
    }, 5000);
}

function runTurnEconomy() {
    const economy = calculateEconomyState(window.GAME);
    applyResourceBundle(economy.gross);
    applyResourceDelta('gold', -economy.consumption.gold);
    const projectedFood = (window.GAME.resources.food || 0) - economy.consumption.food;
    applyResourceDelta('food', -economy.consumption.food);

    if (projectedFood < 0) {
        window.GAME.population = Math.max(0, window.GAME.population - 10);
        notify('Nedostatek jídla! Populace klesá o 10.', 'warning');
    }

    refreshProduction();
    return economy;
}

function gameUI() {
    return {
        get GAME() {
            return window.GAME;
        },
        resourceMeta: RESOURCE_META,
        buildables: BUILDABLES,
        techBranches: ['industry', 'transport', 'politics', 'war'],
        showMainMenu: true,
        showStory: false,
        storyTab: 'pribeh',
        selectedCaravanDest: null,
        shakeBuilding: null,
        init() {
            window.__IRON_DUST_UI = this;
            refreshProduction();
            this.handleShortcutBound = (event) => this.handleShortcut(event);
            window.addEventListener('keydown', this.handleShortcutBound);
            setTimeout(() => {
                const input = document.getElementById('player-name-input');
                if (input) {
                    input.focus();
                }
            }, 0);
        },
        branchLabel(branch) {
            return {
                industry: 'Průmysl',
                transport: 'Doprava',
                politics: 'Politika',
                war: 'Válka'
            }[branch] || branch;
        },
        techNodesByBranch(branch) {
            return TECH_NODES
                .filter((node) => node.branch === branch)
                .slice()
                .sort((a, b) => (a.tier - b.tier) || (a.cost - b.cost));
        },
        hasSave(slot) {
            return !!localStorage.getItem(`irondust_slot_${slot}`);
        },
        saveGame(slot, options = {}) {
            try {
                const data = {
                    version: 1,
                    savedAt: new Date().toLocaleString(),
                    playerName: this.GAME.playerName,
                    year: this.GAME.year,
                    season: this.GAME.season,
                    turnCount: this.GAME.turnCount,
                    resources: { ...this.GAME.resources },
                    reputation: { ...this.GAME.reputation },
                    population: this.GAME.population,
                    dostavnikIn: this.GAME.dostavnikIn,
                    buildings: this.GAME.buildings.map((b) => ({ ...b, production: { ...b.production } })),
                    techTree: {
                        researched: [...this.GAME.techTree.researched],
                        points: this.GAME.techTree.points,
                        totalEarned: this.GAME.techTree.totalEarned
                    },
                    storyLog: this.GAME.storyLog.slice(-60),
                    mapData: MAP_DATA.map((row) => row.slice())
                };
                localStorage.setItem(`irondust_slot_${slot}`, JSON.stringify(data));
                if (!options.silent) {
                    notify(`Uloženo do slotu ${slot}`, 'success');
                }
            } catch (error) {
                if (!options.silent) {
                    notify('Uložení selhalo.', 'warning');
                }
            }
        },
        loadGame(slot) {
            const raw = localStorage.getItem(`irondust_slot_${slot}`);
            if (!raw) {
                notify('V tomto slotu není uložená hra.', 'warning');
                return;
            }
            try {
                const data = JSON.parse(raw);
                this.GAME.playerName = data.playerName || 'Hráč';
                this.GAME.year = data.year || 1872;
                this.GAME.season = data.season || 'Jaro';
                this.GAME.turnCount = data.turnCount || 0;
                this.GAME.population = data.population || 1240;
                this.GAME.dostavnikIn = data.dostavnikIn || 3;
                Object.assign(this.GAME.resources, data.resources || {});
                Object.assign(this.GAME.reputation, data.reputation || {});
                this.GAME.buildings = (data.buildings || []).map((b) => ({ ...b, production: { ...(b.production || {}) } }));
                this.GAME.techTree.researched = data.techTree?.researched || [];
                this.GAME.techTree.points = data.techTree?.points || 0;
                this.GAME.techTree.totalEarned = data.techTree?.totalEarned || 0;
                this.GAME.storyLog = data.storyLog || this.GAME.storyLog;
                if (Array.isArray(data.mapData)) {
                    data.mapData.forEach((row, r) => row.forEach((value, c) => {
                        if (r < MAP_DATA.length && c < MAP_DATA[0].length) {
                            MAP_DATA[r][c] = value;
                        }
                    }));
                }
                this.GAME.mode = 'normal';
                this.GAME.selectedTile = null;
                this.GAME.selectedBuilding = null;
                refreshProduction();
                window.dispatchEvent(new CustomEvent('mapNeedsRender'));
                window.dispatchEvent(new CustomEvent('turnAdvanced'));
                this.showMainMenu = false;
                notify(`Načteno ze slotu ${slot}`, 'success');
            } catch (error) {
                notify('Načtení selhalo.', 'warning');
            }
        },
        startNewGame() {
            const input = document.getElementById('player-name-input');
            this.GAME.playerName = (input?.value || '').trim() || 'Hráč';
            this.GAME.mode = 'normal';
            this.GAME.selectedTile = null;
            this.GAME.selectedBuilding = null;
            this.showMainMenu = false;
            this.saveGame(1, { silent: true });
            notify(`Vítej v Dustfall, ${this.GAME.playerName}.`, 'success');
        },
        canResearch(nodeId) {
            const node = TECH_NODES.find((candidate) => candidate.id === nodeId);
            if (!node) {
                return false;
            }
            if (this.GAME.techTree.researched.includes(nodeId)) {
                return false;
            }
            if (this.GAME.techTree.points < node.cost) {
                return false;
            }
            return (node.requires || []).every((required) => this.GAME.techTree.researched.includes(required));
        },
        researchNode(nodeId) {
            if (!this.canResearch(nodeId)) {
                return;
            }
            const node = TECH_NODES.find((candidate) => candidate.id === nodeId);
            this.GAME.techTree.points -= node.cost;
            this.GAME.techTree.researched.push(nodeId);
            if (nodeId === 'council') {
                this.GAME.reputation.settlers += 10;
            }
            if (nodeId === 'federal') {
                this.GAME.reputation.merchants += 8;
            }
            refreshProduction();
            notify(`Výzkum dokončen: ${node.name}`, 'success');
            addStoryEntry(`Výzkum dokončen: ${node.name}.`);
        },
        getTileName,
        getTileDescription,
        getTileResourceHint,
        selectedBuildingAt(col, row) {
            if (typeof col !== 'number' || typeof row !== 'number') {
                return null;
            }
            return getBuildingAt(col, row);
        },
        getTileActions(type) {
            return TILE_ACTIONS[type] || [];
        },
        handleAction(type, index) {
            const actionName = this.getTileActions(type)[index];
            notify(`Akce: ${actionName}`, 'info');

            if (type === TILE.TOWN && actionName === 'Stavba budov') {
                this.setMode('build');
            }

            if (type === TILE.FOG && actionName === 'Prozkoumat oblast' && this.GAME.selectedTile) {
                const cost = getExploreCost(this.GAME);
                if ((this.GAME.resources.gold || 0) < cost) {
                    notify('Nedostatek zlata pro průzkum!', 'warning');
                    return;
                }
                applyResourceDelta('gold', -cost);
                MAP_DATA[this.GAME.selectedTile.row][this.GAME.selectedTile.col] = TILE.PRAIRIE;
                if (hasTech(this.GAME, 'telegraph')) {
                    revealAdjacentFog(this.GAME.selectedTile.row, this.GAME.selectedTile.col);
                }
                refreshProduction();
                notify('Oblast prozkoumána!', 'success');
                addStoryEntry(`Průzkumník prozkoumal sektor ${this.GAME.selectedTile.col + 1}:${this.GAME.selectedTile.row + 1}.`);
                requestSceneRefresh();
                window.dispatchEvent(new CustomEvent('turnAdvanced'));
            }

            if (type === TILE.ENEMY && actionName === 'Zaútočit' && this.GAME.selectedTile) {
                const attackCost = 40;
                if ((this.GAME.resources.gold || 0) < attackCost) {
                    notify('Nedostatek zlata pro útok!', 'warning');
                    return;
                }
                applyResourceDelta('gold', -attackCost);
                const basePower = Math.floor((this.GAME.reputation.soldiers || 0) / 8);
                const techPower = (hasTech(this.GAME, 'militia') ? 6 : 0) + (hasTech(this.GAME, 'escort') ? 2 : 0);
                const playerPower = basePower + techPower + Math.random() * 6;
                const enemyPower = 12 + Math.random() * 6;
                if (playerPower >= enemyPower) {
                    MAP_DATA[this.GAME.selectedTile.row][this.GAME.selectedTile.col] = TILE.OWNED;
                    refreshProduction();
                    notify('Vítězství! Území je vaše.', 'success');
                    addStoryEntry('Vítězství v potyčce proti Harlan-Voss.');
                    requestSceneRefresh();
                    window.dispatchEvent(new CustomEvent('turnAdvanced'));
                } else {
                    notify('Porážka! H-V se ubránil.', 'warning');
                    addStoryEntry('Neúspěšný útok na Harlan-Voss.');
                }
            }
        },
        setMode(mode) {
            if (this.GAME.pendingEndTurn) {
                this.cancelAdvanceTurn();
            }

            if (mode === 'normal' || this.GAME.mode === mode) {
                this.GAME.mode = 'normal';
                this.GAME.selectedBuilding = null;
                if (mode !== 'caravan') {
                    this.selectedCaravanDest = null;
                }
                return;
            }

            this.GAME.mode = mode;
            if (mode !== 'build') {
                this.GAME.selectedBuilding = null;
            }
            if (mode !== 'caravan') {
                this.selectedCaravanDest = null;
            }
        },
        cancelCurrentMode() {
            this.GAME.mode = 'normal';
            this.GAME.selectedBuilding = null;
            this.GAME.selectedTile = null;
            this.GAME.hoverTooltip.visible = false;
            this.selectedCaravanDest = null;
            this.showStory = false;
            this.cancelAdvanceTurn();
            requestSceneRefresh();
        },
        actionButtonClass(mode) {
            return `action-btn ${this.GAME.mode === mode ? 'action-btn-active' : ''}`;
        },
        perTurnToken(resourceKey) {
            const value = this.GAME.production?.net?.[resourceKey] || 0;
            const meta = RESOURCE_META_MAP[resourceKey];
            return `${value >= 0 ? '+' : ''}${value} ${meta.icon}`;
        },
        formatCosts(costs) {
            return Object.entries(costs || {}).map(([resourceKey, amount]) => ({
                key: resourceKey,
                amount,
                icon: RESOURCE_META_MAP[resourceKey]?.icon || '',
                className: RESOURCE_META_MAP[resourceKey]?.costClass || ''
            }));
        },
        formatProductionLine,
        canAffordBuilding(building) {
            return canAffordCosts(building.costs, this.GAME);
        },
        getMissingText(building) {
            const missing = getMissingCosts(building.costs, this.GAME);
            return missing.map((item) => `${item.missing} ${item.meta.labelCase}`).join(', ');
        },
        triggerBuildShake(name) {
            this.shakeBuilding = name;
            setTimeout(() => {
                if (this.shakeBuilding === name) {
                    this.shakeBuilding = null;
                }
            }, 360);
        },
        selectBuilding(building) {
            if (!this.canAffordBuilding(building)) {
                this.triggerBuildShake(building.name);
                notify(`Chybí: ${this.getMissingText(building)}`, 'warning');
                return;
            }

            this.GAME.selectedBuilding = {
                name: building.name,
                costs: { ...building.costs },
                effect: building.effect,
                production: { ...building.production },
                icon: building.icon
            };
            this.GAME.mode = 'build';
            notify(`Vybráno: ${building.name}. Klikněte na vlastněné území nebo město.`, 'info');
        },
        placeBuildingAt(col, row, type) {
            if (!this.GAME.selectedBuilding) {
                return false;
            }
            if (!canBuildOnTile(type)) {
                notify('Sem nelze stavět. Vyberte vlastněné území nebo město.', 'warning');
                return false;
            }
            if (getBuildingAt(col, row)) {
                notify('Na této dlaždici už stojí budova.', 'warning');
                return false;
            }
            if (!canAffordCosts(this.GAME.selectedBuilding.costs, this.GAME)) {
                this.triggerBuildShake(this.GAME.selectedBuilding.name);
                notify(`Chybí: ${this.getMissingText(this.GAME.selectedBuilding)}`, 'warning');
                return false;
            }

            applyResourceBundle(this.GAME.selectedBuilding.costs, -1);

            const buildingRecord = {
                id: Date.now() + Math.random(),
                name: this.GAME.selectedBuilding.name,
                col,
                row,
                production: { ...this.GAME.selectedBuilding.production },
                upkeep: BUILD_UPKEEP_GOLD,
                icon: this.GAME.selectedBuilding.icon
            };

            this.GAME.buildings.push(buildingRecord);
            refreshProduction();

            const location = getLocationLabel(col, row, type);
            notify(`Postaveno: ${buildingRecord.name} na ${location}`, 'success');
            addStoryEntry(`Postavena ${buildingRecord.name} na ${location}.`);
            this.GAME.selectedTile = { col, row, type };
            this.GAME.selectedBuilding = null;
            this.GAME.mode = 'normal';
            requestSceneRefresh();
            return true;
        },
        setCaravanDestination(col, row, type) {
            if (this.GAME.mode !== 'caravan' || !(type === TILE.TOWN || type === TILE.OWNED)) {
                return;
            }
            const distance = Math.max(1, Math.round((Math.abs(col - 6) + Math.abs(row - 6)) / 3));
            this.selectedCaravanDest = {
                name: getLocationLabel(col, row, type),
                dist: distance
            };
            notify(`Cíl karavany: ${this.selectedCaravanDest.name}`, 'info');
        },
        sendCaravan(withSupplies) {
            if (!this.selectedCaravanDest) {
                return;
            }
            if (withSupplies) {
                applyResourceDelta('food', -25);
                notify(`Karavana vyrazila do ${this.selectedCaravanDest.name} se zásobami.`, 'success');
                addStoryEntry(`Karavana byla vyslána do ${this.selectedCaravanDest.name} se zásobami.`);
            } else {
                notify(`Karavana vyslána do ${this.selectedCaravanDest.name}`, 'success');
                addStoryEntry(`Karavana byla vyslána do ${this.selectedCaravanDest.name}.`);
            }
            refreshProduction();
            this.GAME.mode = 'normal';
            this.selectedCaravanDest = null;
        },
        requestAdvanceTurn() {
            if (this.GAME.pendingEndTurn) {
                return;
            }
            this.GAME.pendingEndTurn = true;
            this.GAME.pendingEndTurnTimer = setTimeout(() => {
                this.GAME.pendingEndTurn = false;
                this.GAME.pendingEndTurnTimer = null;
            }, 3000);
        },
        cancelAdvanceTurn() {
            if (this.GAME.pendingEndTurnTimer) {
                clearTimeout(this.GAME.pendingEndTurnTimer);
            }
            this.GAME.pendingEndTurnTimer = null;
            this.GAME.pendingEndTurn = false;
        },
        confirmAdvanceTurn() {
            this.cancelAdvanceTurn();
            this.advanceTurn();
        },
        advanceTurn() {
            const seasons = ['Jaro', 'Léto', 'Podzim', 'Zima'];
            let seasonIndex = seasons.indexOf(this.GAME.season);
            seasonIndex += 1;
            if (seasonIndex >= seasons.length) {
                seasonIndex = 0;
                this.GAME.year += 1;
                addStoryEntry(`Začal nový rok ${this.GAME.year}.`);
            }
            this.GAME.season = seasons[seasonIndex];
            this.GAME.turnCount += 1;

            const economy = runTurnEconomy();
            notify(`Produkce: +${economy.gross.gold} zlata, +${economy.gross.food} jídla, +${economy.gross.iron} železa`, 'production');

            if (this.GAME.turnCount % 3 === 0) {
                let points = 2;
                if (hasTech(this.GAME, 'forge')) {
                    points += 2;
                }
                this.GAME.techTree.points += points;
                this.GAME.techTree.totalEarned += points;
                notify(`Technologické body: +${points}`, 'info');
                addStoryEntry(`Získány technologické body: +${points}.`);
            }

            this.GAME.dostavnikIn -= 1;
            if (this.GAME.dostavnikIn <= 0) {
                this.triggerDostavnik();
                const min = hasTech(this.GAME, 'coach') ? 1 : 2;
                this.GAME.dostavnikIn = Math.floor(Math.random() * 3) + min;
            }

            this.triggerRandomEvent();
            refreshProduction();
            notify(`Tah dokončen. Nyní je ${this.GAME.season} ${this.GAME.year}.`, 'info');
            window.dispatchEvent(new CustomEvent('turnAdvanced'));

            if (!this.showMainMenu) {
                this.saveGame(1, { silent: true });
            }
        },
        triggerDostavnik() {
            applyResourceDelta('gold', 100);
            this.GAME.population += 5;
            refreshProduction();
            notify('Dostavník dorazil! +100 zlata, +5 populace', 'success');
            addStoryEntry('Dostavník dorazil do Dustfallu s novými osadníky a hotovostí.');
        },
        triggerRandomEvent() {
            const events = [
                {
                    text: 'Dostavník ze severu přivezl zásoby.',
                    type: 'success',
                    effect: () => applyResourceDelta('food', 50)
                },
                {
                    text: 'Agent Harlan-Voss viděn v okolí Dustfallu.',
                    type: 'warning',
                    effect: () => { this.GAME.reputation.merchants -= 5; }
                },
                {
                    text: 'Nová rodina se usadila. Populace roste.',
                    type: 'info',
                    effect: () => { this.GAME.population += 10; }
                },
                {
                    text: 'Sucho zasáhlo pláně. Úroda slabá.',
                    type: 'warning',
                    effect: () => applyResourceDelta('food', -30)
                },
                {
                    text: 'Zlatý prach nalezen v řece Colorado.',
                    type: 'success',
                    effect: () => applyResourceDelta('gold', 120)
                },
                {
                    text: 'Správce skladu hlásí nesrovnalosti.',
                    type: 'warning',
                    effect: () => applyResourceDelta('gold', -80)
                },
                {
                    text: 'Kupci z východu nabízejí kontrakt.',
                    type: 'info',
                    effect: () => { this.GAME.reputation.merchants += 8; }
                },
                {
                    text: 'Kmen Tonáhve poslal posly. Opatrnost.',
                    type: 'warning',
                    effect: () => { this.GAME.reputation.tribes -= 5; }
                }
            ];
            const event = events[Math.floor(Math.random() * events.length)];
            event.effect();
            refreshProduction();
            notify(event.text, event.type);
            addStoryEntry(event.text);
        },
        handleShortcut(event) {
            const activeTag = document.activeElement?.tagName;
            if (activeTag === 'INPUT' || activeTag === 'TEXTAREA') {
                return;
            }

            const key = event.key.toLowerCase();
            if (this.showMainMenu) {
                if (key === 'escape') {
                    this.showMainMenu = false;
                }
                return;
            }
            if (key === 'e') {
                this.setMode('explore');
            } else if (key === 'k') {
                this.setMode('caravan');
            } else if (key === 'b') {
                this.setMode('build');
            } else if (key === 't') {
                this.setMode('tech');
            } else if (key === 'o') {
                this.setMode('trade');
            } else if (event.code === 'Space') {
                event.preventDefault();
                this.requestAdvanceTurn();
            } else if (key === 'escape') {
                this.cancelCurrentMode();
            }
        },
        showModeBadge() {
            return ['explore', 'caravan', 'build'].includes(this.GAME.mode);
        },
        modeBadgeText() {
            if (this.GAME.mode === 'explore') {
                return 'PRŮZKUMNÍK MODE — ESC pro zrušení';
            }
            if (this.GAME.mode === 'caravan') {
                return 'KARAVANA MODE — ESC pro zrušení';
            }
            if (this.GAME.mode === 'build') {
                return 'STAVBA MODE — ESC pro zrušení';
            }
            return '';
        },
        modeBadgeClass() {
            if (this.GAME.mode === 'explore') {
                return 'mode-badge-explore';
            }
            if (this.GAME.mode === 'caravan') {
                return 'mode-badge-caravan';
            }
            if (this.GAME.mode === 'build') {
                return 'mode-badge-build';
            }
            return '';
        },
        tooltipStyle() {
            return `left:${this.GAME.hoverTooltip.x}px; top:${this.GAME.hoverTooltip.y}px;`;
        },
        notifDotClass(type) {
            return {
                info: 'bg-yellow-500',
                success: 'bg-green-500',
                warning: 'bg-red-500',
                production: 'bg-sky-400'
            }[type] || 'bg-yellow-500';
        }
    };
}

document.addEventListener('alpine:init', () => {
    const initialState = {
        playerName: 'Hráč',
        techTree: { researched: [], points: 0, totalEarned: 0 },
        year: 1872,
        season: 'Jaro',
        turnCount: 0,
        resources: { gold: 2340, food: 480, iron: 210, wood: 95, coal: 140, salt: 62 },
        reputation: { settlers: 68, merchants: 54, soldiers: 72, tribes: 45 },
        population: 1240,
        mode: 'normal',
        dostavnikIn: 3,
        notifications: [],
        storyLog: [
            { year: 1872, season: 'Jaro', turnCount: 0, text: 'Příjezd do Dustfall. Otevřena dopravní stanice.' }
        ],
        managers: {},
        units: [],
        selectedTile: null,
        selectedBuilding: null,
        buildings: [],
        hoverTooltip: {
            visible: false,
            x: 0,
            y: 0,
            title: '',
            resource: ''
        },
        resourceChanges: createResourceChangeBuckets(),
        production: calculateEconomyState({ buildings: [], population: 1240, reputation: { soldiers: 72 } }),
        pendingEndTurn: false,
        pendingEndTurnTimer: null
    };

    window.GAME = Alpine.reactive(initialState);
});

class MapScene extends Phaser.Scene {
    constructor() {
        super('MapScene');
        this.tileW = 64;
        this.tileH = 32;
        this.mapRows = MAP_DATA.length;
        this.mapCols = MAP_DATA[0].length;
        this.isDragging = false;
        this.dragThreshold = 5;
        this.dragDistance = 0;
    }

    create() {
        this.graphics = this.add.graphics();
        this.decorGraphics = this.add.graphics();
        this.uiGraphics = this.add.graphics();
        this.textLayer = this.add.container(0, 0);

        this.mapContainer = this.add.container(this.cameras.main.centerX, 100);
        this.mapContainer.add([this.graphics, this.decorGraphics, this.uiGraphics, this.textLayer]);

        this.renderMap();
        this.setupInteractivity();
        this.setupCamera();
        this.createMinimap();

        window.addEventListener('turnAdvanced', () => this.updateMinimap());
        window.addEventListener('mapNeedsRender', () => {
            this.renderMap();
            this.updateMinimap();
        });
    }

    isoX(col, row) {
        return (col - row) * (this.tileW / 2);
    }

    isoY(col, row) {
        return (col + row) * (this.tileH / 2);
    }

    screenToGrid(pointer) {
        const localX = (pointer.x - this.mapContainer.x) / this.cameras.main.zoom;
        const localY = (pointer.y - this.mapContainer.y) / this.cameras.main.zoom;
        const col = Math.round((localX / (this.tileW / 2) + localY / (this.tileH / 2)) / 2);
        const row = Math.round((localY / (this.tileH / 2) - localX / (this.tileW / 2)) / 2);
        return { col, row };
    }

    localToGrid(x, y) {
        return {
            col: (x / (this.tileW / 2) + y / (this.tileH / 2)) / 2,
            row: (y / (this.tileH / 2) - x / (this.tileW / 2)) / 2
        };
    }

    clearTextLayer() {
        this.textLayer.removeAll(true);
    }

    renderMap() {
        this.graphics.clear();
        this.decorGraphics.clear();
        this.uiGraphics.clear();
        this.clearTextLayer();

        for (let row = 0; row < this.mapRows; row += 1) {
            for (let col = 0; col < this.mapCols; col += 1) {
                const type = MAP_DATA[row][col];
                if (type === TILE.VOID) {
                    continue;
                }
                this.drawTile(col, row, type);
                this.drawDecorations(col, row, type);
            }
        }

        this.drawPlacedBuildings();
        if (window.GAME?.selectedTile) {
            this.drawSelection(window.GAME.selectedTile.col, window.GAME.selectedTile.row);
        }
    }

    drawTile(col, row, type) {
        const x = this.isoX(col, row);
        const y = this.isoY(col, row);
        const topColor = Phaser.Display.Color.HexStringToColor(getBlendedTopColor(col, row, type)).color;
        const leftColor = Phaser.Display.Color.HexStringToColor(multiplyHex(getTileBaseColor(type), 0.75)).color;
        const rightColor = Phaser.Display.Color.HexStringToColor(multiplyHex(getTileBaseColor(type), 0.60)).color;
        const depth = 4;

        this.graphics.fillStyle(leftColor);
        this.graphics.fillPoints([
            { x: x - this.tileW / 2, y },
            { x, y: y + this.tileH / 2 },
            { x, y: y + this.tileH / 2 + depth },
            { x: x - this.tileW / 2, y: y + depth }
        ]);

        this.graphics.fillStyle(rightColor);
        this.graphics.fillPoints([
            { x: x + this.tileW / 2, y },
            { x, y: y + this.tileH / 2 },
            { x, y: y + this.tileH / 2 + depth },
            { x: x + this.tileW / 2, y: y + depth }
        ]);

        this.graphics.fillStyle(topColor);
        this.graphics.fillPoints([
            { x, y: y - this.tileH / 2 },
            { x: x + this.tileW / 2, y },
            { x, y: y + this.tileH / 2 },
            { x: x - this.tileW / 2, y }
        ]);
    }

    drawDecorations(col, row, type) {
        const x = this.isoX(col, row);
        const y = this.isoY(col, row);
        const seed = col * 31 + row * 17;
        const graphics = this.decorGraphics;

        if (type === TILE.PRAIRIE || type === TILE.OWNED) {
            const variant = seed % 6;
            if (variant < 2) {
                graphics.fillStyle(0x5d4037);
                graphics.fillRect(x - 1.5, y - 12, 3, 12);
                graphics.fillStyle(0x2e7d32);
                graphics.fillTriangle(x - 8, y - 10, x + 8, y - 10, x, y - 20);
                graphics.fillTriangle(x - 6, y - 16, x + 6, y - 16, x, y - 24);
            } else if (variant === 2) {
                graphics.lineStyle(1, 0x4e342e);
                for (let i = -10; i <= 10; i += 6) {
                    graphics.lineBetween(x + i, y - 2, x + i, y - 8);
                }
                graphics.lineBetween(x - 10, y - 4, x + 10, y - 4);
                graphics.lineBetween(x - 10, y - 7, x + 10, y - 7);
            } else if (variant === 3) {
                graphics.fillStyle(0xc0ca33);
                for (let i = -8; i <= 8; i += 6) {
                    for (let j = -2; j <= 2; j += 4) {
                        graphics.fillRect(x + i, y + j - 4, 4, 2);
                    }
                }
            } else if (variant === 4) {
                graphics.fillStyle(0x795548);
                graphics.fillEllipse(x, y - 4, 14, 8);
                graphics.fillEllipse(x + 6, y - 8, 6, 6);
            } else {
                graphics.lineStyle(1, 0x1b5e20);
                graphics.lineBetween(x - 4, y, x - 2, y - 4);
                graphics.lineBetween(x, y, x + 2, y - 4);
                graphics.lineBetween(x + 4, y, x + 6, y - 4);
            }
        } else if (type === TILE.DESERT) {
            const variant = seed % 4;
            if (variant === 0) {
                graphics.fillStyle(0x1b5e20);
                graphics.fillEllipse(x, y, 20, 10);
                graphics.fillStyle(0x0288d1);
                graphics.fillEllipse(x, y, 12, 6);
            } else if (variant === 1) {
                graphics.fillStyle(0x2e7d32);
                graphics.fillRect(x - 2, y - 12, 4, 12);
                graphics.fillRect(x - 6, y - 8, 4, 2);
                graphics.fillRect(x - 6, y - 12, 2, 4);
                graphics.fillRect(x + 2, y - 10, 4, 2);
                graphics.fillRect(x + 4, y - 14, 2, 4);
            } else if (variant === 2) {
                graphics.lineStyle(1, 0xffe082, 0.5);
                for (let i = 0; i < 3; i += 1) {
                    graphics.strokePoints([{ x: x - 10, y: y - 2 + i * 2 }, { x, y: y + i * 2 }, { x: x + 10, y: y - 2 + i * 2 }]);
                }
            } else {
                graphics.fillStyle(0x757575);
                graphics.fillPoints([{ x: x - 8, y }, { x: x - 4, y: y - 6 }, { x: x + 4, y: y - 4 }, { x: x + 8, y }]);
            }
        } else if (type === TILE.MOUNTAIN) {
            graphics.fillStyle(0x616161);
            graphics.fillTriangle(x - 20, y + 4, x + 20, y + 4, x, y - 36);
            graphics.fillStyle(0x757575);
            graphics.fillTriangle(x - 10, y + 4, x + 25, y + 4, x + 10, y - 20);
            graphics.fillStyle(0xffffff);
            graphics.fillTriangle(x - 3, y - 30, x + 3, y - 30, x, y - 36);
        } else if (type === TILE.RIVER) {
            graphics.lineStyle(4, 0x0288d1);
            graphics.beginPath();
            graphics.moveTo(x - this.tileW / 2, y);
            graphics.lineTo(x + this.tileW / 2, y);
            graphics.strokePath();
            if (seed % 3 === 0) {
                graphics.fillStyle(0xffffff, 0.35);
                graphics.fillEllipse(x, y, 6, 3);
            }
        } else if (type === TILE.MINE) {
            graphics.fillStyle(0x4e342e);
            graphics.fillRect(x - 6, y - 12, 12, 12);
            graphics.fillStyle(0x212121);
            graphics.fillTriangle(x - 8, y - 12, x + 8, y - 12, x, y - 18);
            graphics.fillStyle(0x000000);
            graphics.fillRect(x - 2, y - 6, 4, 6);
            for (let i = 0; i < 3; i += 1) {
                graphics.fillStyle(0x9e9e9e, 0.8 - i * 0.2);
                graphics.fillCircle(x, y - 20 - i * 6, 4 - i);
            }
        } else if (type === TILE.TOWN) {
            graphics.fillStyle(0x8d6e63);
            graphics.fillRect(x - 14, y - 18, 10, 18);
            graphics.fillStyle(0xffeb3b);
            graphics.fillRect(x - 12, y - 14, 2, 2);
            graphics.fillRect(x - 8, y - 14, 2, 2);
            graphics.fillStyle(0xb0a060);
            graphics.fillRect(x - 4, y - 24, 12, 24);
            graphics.fillStyle(0xffeb3b);
            graphics.fillRect(x - 2, y - 20, 2, 3);
            graphics.fillRect(x + 4, y - 20, 2, 3);
            graphics.fillStyle(0xd7ccc8);
            graphics.fillRect(x + 10, y - 12, 8, 12);
            graphics.lineStyle(1, 0x212121);
            graphics.lineBetween(x + 18, y, x + 18, y - 28);
            graphics.fillStyle(0xd32f2f);
            graphics.fillTriangle(x + 18, y - 28, x + 18, y - 20, x + 28, y - 24);
            if (isTownRailTile(col, row, type)) {
                this.drawRailwayTracks(col, row);
            }
        } else if (type === TILE.RAILWAY) {
            this.drawRailwayTracks(col, row);
        } else if (type === TILE.FOG) {
            const text = this.add.text(x, y - 4, '?', { fontSize: '16px', color: '#5c6bc0', fontStyle: 'bold' }).setOrigin(0.5);
            this.textLayer.add(text);
        } else if (type === TILE.ENEMY) {
            const text = this.add.text(x, y - 4, 'H-V', { fontSize: '10px', color: '#b71c1c', fontStyle: 'bold' }).setOrigin(0.5);
            this.textLayer.add(text);
            graphics.lineStyle(1, 0xb71c1c);
            graphics.strokePoints([{ x, y: y - this.tileH / 2 }, { x: x + this.tileW / 2, y }, { x, y: y + this.tileH / 2 }, { x: x - this.tileW / 2, y }], true);
        }
    }

    drawRailwayTracks(col, row) {
        const x = this.isoX(col, row);
        const y = this.isoY(col, row);
        const graphics = this.decorGraphics;
        graphics.lineStyle(2, 0x33251c);
        graphics.lineBetween(x - this.tileW / 2 + 4, y - 2, x + this.tileW / 2 - 4, y - 2);
        graphics.lineBetween(x - this.tileW / 2 + 4, y + 2, x + this.tileW / 2 - 4, y + 2);
        graphics.lineStyle(1, 0x4a3a2d);
        for (let i = -20; i <= 20; i += 10) {
            graphics.lineBetween(x + i, y - 6, x + i, y + 6);
        }
    }

    drawPlacedBuildings() {
        if (!window.GAME?.buildings?.length) {
            return;
        }

        window.GAME.buildings.forEach((building) => {
            const x = this.isoX(building.col, building.row);
            const y = this.isoY(building.col, building.row) - 14;
            const badge = this.add.text(x, y, building.icon, {
                fontSize: '15px',
                color: '#f7f3dd',
                stroke: '#1a1a1a',
                strokeThickness: 2
            }).setOrigin(0.5);
            this.textLayer.add(badge);
        });
    }

    setupInteractivity() {
        this.input.on('pointerdown', () => {
            this.isDragging = true;
            this.dragDistance = 0;
        });

        this.input.on('pointerup', (pointer) => {
            const wasDragging = this.dragDistance > this.dragThreshold;
            this.isDragging = false;
            if (!wasDragging) {
                const grid = this.screenToGrid(pointer);
                this.handlePointerSelection(grid.col, grid.row);
            }
        });

        this.input.on('pointermove', (pointer) => {
            if (this.isDragging && pointer.isDown) {
                this.dragDistance += Math.abs(pointer.velocity.x) + Math.abs(pointer.velocity.y);
                this.mapContainer.x += pointer.velocity.x * 0.1;
                this.mapContainer.y += pointer.velocity.y * 0.1;
                this.updateMinimap();
            }

            const grid = this.screenToGrid(pointer);
            this.uiGraphics.clear();
            if (this.isValidGrid(grid.col, grid.row)) {
                const type = MAP_DATA[grid.row][grid.col];
                if (type !== TILE.VOID) {
                    this.drawHighlight(grid.col, grid.row);
                    this.updateHoverTooltip(pointer, grid.col, grid.row, type);
                } else {
                    this.hideHoverTooltip();
                }
            } else {
                this.hideHoverTooltip();
            }

            if (window.GAME?.selectedTile) {
                this.drawSelection(window.GAME.selectedTile.col, window.GAME.selectedTile.row);
            }
        });

        this.input.on('gameout', () => {
            this.hideHoverTooltip();
            this.uiGraphics.clear();
            if (window.GAME?.selectedTile) {
                this.drawSelection(window.GAME.selectedTile.col, window.GAME.selectedTile.row);
            }
        });
    }

    isValidGrid(col, row) {
        return row >= 0 && row < this.mapRows && col >= 0 && col < this.mapCols;
    }

    updateHoverTooltip(pointer, col, row, type) {
        if (!window.GAME) {
            return;
        }
        window.GAME.hoverTooltip.visible = true;
        window.GAME.hoverTooltip.x = pointer.x + 12;
        window.GAME.hoverTooltip.y = pointer.y - 12;
        window.GAME.hoverTooltip.title = getTileName(type);
        window.GAME.hoverTooltip.resource = getTileResourceHint(type);
        this.updateMinimap();
    }

    hideHoverTooltip() {
        if (!window.GAME) {
            return;
        }
        window.GAME.hoverTooltip.visible = false;
    }

    handlePointerSelection(col, row) {
        if (!this.isValidGrid(col, row)) {
            return;
        }
        const type = MAP_DATA[row][col];
        if (type === TILE.VOID) {
            return;
        }
        this.selectTile(col, row, type);
    }

    selectTile(col, row, type) {
        const ui = window.__IRON_DUST_UI;
        if (!window.GAME) {
            return;
        }

        if (window.GAME.mode === 'explore' && type === TILE.FOG) {
            const cost = getExploreCost(window.GAME);
            if ((window.GAME.resources.gold || 0) >= cost) {
                applyResourceDelta('gold', -cost);
                MAP_DATA[row][col] = TILE.PRAIRIE;
                if (hasTech(window.GAME, 'telegraph')) {
                    revealAdjacentFog(row, col);
                }
                refreshProduction();
                notify('Oblast prozkoumána! Nalezena prérie.', 'success');
                addStoryEntry(`Průzkumník odhalil nový sektor ${col + 1}:${row + 1}.`);
                window.GAME.mode = 'normal';
                this.renderMap();
                this.updateMinimap();
            } else {
                notify('Nedostatek zlata pro průzkum!', 'warning');
            }
            return;
        }

        if (window.GAME.mode === 'build' && window.GAME.selectedBuilding) {
            if (ui?.placeBuildingAt(col, row, type)) {
                this.renderMap();
                this.updateMinimap();
            }
            return;
        }

        if (window.GAME.mode === 'caravan') {
            ui?.setCaravanDestination(col, row, type);
            return;
        }

        window.GAME.selectedTile = { col, row, type };
        if (type === TILE.FOG) {
            notify('Neobjevená oblast — vyšli průzkumníka', 'info');
        }
        if (type === TILE.ENEMY) {
            notify('Nepřátelské území Harlan-Voss. Nutná armáda.', 'warning');
        }

        this.drawSelection(col, row);
        this.updateMinimap();
    }

    drawHighlight(col, row) {
        const x = this.isoX(col, row);
        const y = this.isoY(col, row);
        this.uiGraphics.lineStyle(2, 0xffdc3c, 0.5);
        this.uiGraphics.strokePoints([
            { x, y: y - this.tileH / 2 },
            { x: x + this.tileW / 2, y },
            { x, y: y + this.tileH / 2 },
            { x: x - this.tileW / 2, y }
        ], true);
    }

    drawSelection(col, row) {
        const x = this.isoX(col, row);
        const y = this.isoY(col, row);
        const points = [
            { x, y: y - this.tileH / 2 },
            { x: x + this.tileW / 2, y },
            { x, y: y + this.tileH / 2 },
            { x: x - this.tileW / 2, y }
        ];
        this.uiGraphics.lineStyle(3, 0xffeb3b, 1);
        this.uiGraphics.fillStyle(0xffeb3b, 0.2);
        this.uiGraphics.strokePoints(points, true);
        this.uiGraphics.fillPoints(points, true);
    }

    setupCamera() {
        this.cameras.main.setBackgroundColor('#1a1a1a');

        this.input.on('wheel', (pointer, gameObjects, deltaX, deltaY) => {
            const newZoom = this.cameras.main.zoom - deltaY * 0.001;
            this.cameras.main.zoom = Phaser.Math.Clamp(newZoom, 0.7, 1.5);
            this.updateMinimap();
        });
    }

    createMinimap() {
        this.minimap = this.add.renderTexture(0, 0, 120, 88).setScrollFactor(0);
        this.minimapLabel = this.add.text(0, 0, 'MAPA', {
            fontSize: '8px',
            color: '#9f8a54'
        }).setScrollFactor(0);
        this.positionMinimap();
        this.updateMinimap();
    }

    positionMinimap() {
        const minimapX = this.cameras.main.width - 128;
        const minimapY = this.cameras.main.height - 160;
        if (this.minimap) {
            this.minimap.setPosition(minimapX, minimapY);
        }
        if (this.minimapLabel) {
            this.minimapLabel.setPosition(minimapX + 2, minimapY - 12);
        }
    }

    updateMinimap() {
        if (!this.minimap) {
            return;
        }

        this.positionMinimap();
        this.minimap.clear();
        const graphics = this.add.graphics();
        const originX = 7;
        const originY = 10;
        const tileWidth = 6;
        const tileHeight = 5;
        const gap = 0.5;
        const stepX = tileWidth + gap;
        const stepY = tileHeight + gap;

        graphics.fillStyle(0x0a0804, 1);
        graphics.fillRect(0, 0, 120, 88);

        for (let row = 0; row < this.mapRows; row += 1) {
            for (let col = 0; col < this.mapCols; col += 1) {
                const type = MAP_DATA[row][col];
                if (type === TILE.VOID) {
                    continue;
                }
                let color = getTileBaseColor(type);
                if (type === TILE.FOG) {
                    color = '#090909';
                } else if (type === TILE.ENEMY) {
                    color = blendHex(getTileBaseColor(type), '#2a0000', 0.8);
                }
                graphics.fillStyle(Phaser.Display.Color.HexStringToColor(color).color, 1);
                graphics.fillRect(originX + col * stepX, originY + row * stepY, tileWidth, tileHeight);
            }
        }

        const viewport = this.getViewportBounds();
        graphics.lineStyle(1, 0xf5f4ef, 0.95);
        graphics.strokeRect(
            originX + viewport.minCol * stepX,
            originY + viewport.minRow * stepY,
            Math.max(tileWidth, (viewport.maxCol - viewport.minCol + 1) * stepX),
            Math.max(tileHeight, (viewport.maxRow - viewport.minRow + 1) * stepY)
        );
        graphics.lineStyle(1, 0xdcb43c, 0.75);
        graphics.strokeRect(
            originX + viewport.minCol * stepX + 1,
            originY + viewport.minRow * stepY + 1,
            Math.max(tileWidth - 2, (viewport.maxCol - viewport.minCol + 1) * stepX - 2),
            Math.max(tileHeight - 2, (viewport.maxRow - viewport.minRow + 1) * stepY - 2)
        );

        if (window.GAME?.selectedTile) {
            graphics.fillStyle(0xffffff, 1);
            graphics.fillRect(
                originX + window.GAME.selectedTile.col * stepX + 2,
                originY + window.GAME.selectedTile.row * stepY + 1.5,
                2,
                2
            );
        }

        graphics.lineStyle(1, 0xdcb43c, 0.6);
        graphics.strokeRect(0.5, 0.5, 119, 87);
        this.minimap.draw(graphics);
        graphics.destroy();
    }

    getViewportBounds() {
        const zoom = this.cameras.main.zoom;
        const left = (0 - this.mapContainer.x) / zoom;
        const right = (this.cameras.main.width - this.mapContainer.x) / zoom;
        const top = (0 - this.mapContainer.y) / zoom;
        const bottom = (this.cameras.main.height - this.mapContainer.y) / zoom;
        const corners = [
            this.localToGrid(left, top),
            this.localToGrid(right, top),
            this.localToGrid(left, bottom),
            this.localToGrid(right, bottom)
        ];
        const cols = corners.map((corner) => corner.col);
        const rows = corners.map((corner) => corner.row);
        return {
            minCol: clamp(Math.floor(Math.min(...cols)), 0, this.mapCols - 1),
            maxCol: clamp(Math.ceil(Math.max(...cols)), 0, this.mapCols - 1),
            minRow: clamp(Math.floor(Math.min(...rows)), 0, this.mapRows - 1),
            maxRow: clamp(Math.ceil(Math.max(...rows)), 0, this.mapRows - 1)
        };
    }
}

const config = {
    type: Phaser.AUTO,
    parent: 'game-container',
    width: window.innerWidth,
    height: window.innerHeight,
    scene: MapScene,
    transparent: true
};

const game = new Phaser.Game(config);

window.addEventListener('resize', () => {
    if (!game.isBooted || !game.scale) {
        return;
    }
    try {
        game.scale.resize(window.innerWidth, window.innerHeight);
    } catch (error) {
        return;
    }
    const scene = game.scene.keys.MapScene;
    if (scene) {
        scene.positionMinimap();
        scene.updateMinimap();
    }
});
