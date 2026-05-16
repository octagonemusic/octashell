.pragma library

let _v0 = new Int32Array(100);
let _v1 = new Int32Array(100);

function getEditDistance(a, b) {
    let aLen = a.length;
    let bLen = b.length;
    if (a === b) return 0;
    if (aLen === 0) return bLen;
    if (bLen === 0) return aLen;
    if (bLen >= _v0.length) {
        _v0 = new Int32Array(bLen + 1);
        _v1 = new Int32Array(bLen + 1);
    }
    for (let i = 0; i <= bLen; i++) _v0[i] = i;
    for (let i = 0; i < aLen; i++) {
        _v1[0] = i + 1;
        let aChar = a[i];
        for (let j = 0; j < bLen; j++) {
            let cost = aChar === b[j] ? 0 : 1;
            _v1[j + 1] = Math.min(_v1[j] + 1, _v0[j + 1] + 1, _v0[j] + cost);
        }
        for (let j = 0; j <= bLen; j++) _v0[j] = _v1[j];
    }
    return _v0[bLen];
}

let _prefixIndex = null;
let _exactIndex = null;

function buildIndex(items) {
    _exactIndex = {};
    _prefixIndex = {};

    for (let i = 0; i < items.length; i++) {
        let item = items[i];
        let tokens = item.tokens;

        for (let t = 0; t < tokens.length; t++) {
            let token = tokens[t];

            if (!_exactIndex[token]) _exactIndex[token] = [];
            _exactIndex[token].push(i);

            for (let l = 1; l <= token.length; l++) {
                let prefix = token.slice(0, l);
                if (!_prefixIndex[prefix]) _prefixIndex[prefix] = [];
                if (_prefixIndex[prefix].indexOf(i) === -1) _prefixIndex[prefix].push(i);
            }
        }

        let display = item.display.toLowerCase();
        for (let l = 1; l <= display.length; l++) {
            let prefix = display.slice(0, l);
            if (!_prefixIndex[prefix]) _prefixIndex[prefix] = [];
            if (_prefixIndex[prefix].indexOf(i) === -1) _prefixIndex[prefix].push(i);
        }
    }
}

function getCandidatesForWord(word) {
    let result = {};
    let exact = _exactIndex[word];
    if (exact) {
        for (let i = 0; i < exact.length; i++) result[exact[i]] = true;
    }
    let prefix = _prefixIndex[word];
    if (prefix) {
        for (let i = 0; i < prefix.length; i++) result[prefix[i]] = true;
    }
    return result;
}

function filterEmojis(baseItems, queryStr) {
    let query = queryStr.toLowerCase().trim();
    let queryLen = query.length;
    if (queryLen === 0) return [];

    if (!_exactIndex || !_prefixIndex) buildIndex(baseItems);

    let words = query.split(/\s+/);
    let scores = {};

    if (words.length === 1) {
        let exactHits = _exactIndex[query];
        if (exactHits) {
            for (let i = 0; i < exactHits.length; i++) scores[exactHits[i]] = 500;
        }

        let prefixHits = _prefixIndex[query];
        if (prefixHits) {
            for (let i = 0; i < prefixHits.length; i++) {
                let idx = prefixHits[i];
                if (scores[idx] !== undefined) continue;
                let item = baseItems[idx];
                let display = item.display.toLowerCase();
                let band = display.startsWith(query) ? 400
                         : item.tokens[0] && item.tokens[0].startsWith(query) ? 300
                         : 200;
                scores[idx] = band;
            }
        }
    } else {
        let candidateSets = [];
        for (let w = 0; w < words.length; w++) {
            if (words[w].length > 0) candidateSets.push(getCandidatesForWord(words[w]));
        }

        if (candidateSets.length === 0) return [];

        let first = candidateSets[0];
        let idxList = Object.keys(first);
        for (let i = 0; i < idxList.length; i++) {
            let idx = idxList[i];
            let inAll = true;
            for (let s = 1; s < candidateSets.length; s++) {
                if (!candidateSets[s][idx]) { inAll = false; break; }
            }
            if (inAll) scores[idx] = 200;
        }
    }

    if (queryLen >= 4 && Object.keys(scores).length < 20) {
        let allowedTypos = queryLen >= 6 ? 2 : 1;
        for (let i = 0; i < baseItems.length; i++) {
            if (scores[i] !== undefined) continue;
            let tokens = baseItems[i].tokens;
            for (let t = 0; t < tokens.length; t++) {
                let token = tokens[t];
                if (Math.abs(token.length - queryLen) <= allowedTypos) {
                    if (getEditDistance(token, query) <= allowedTypos) {
                        scores[i] = 100;
                        break;
                    }
                }
            }
        }
    }

    let results = [];
    let idxList = Object.keys(scores);
    for (let i = 0; i < idxList.length; i++) {
        let idx = idxList[i];
        let item = baseItems[idx];
        item.score = scores[idx];
        results.push(item);
    }

    results.sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        return a.display.length - b.display.length;
    });

    return results.slice(0, 50);
}

function parseEmojiJson(textBody) {
    _exactIndex = null;
    _prefixIndex = null;

    let parsedJson = JSON.parse(textBody);
    let dynamicAllItems = [];

    Object.keys(parsedJson).forEach(key => {
        let tags = parsedJson[key] || [];
        let rawDesc = tags.length > 0 ? tags[0] : "emoji";
        let displayDesc = rawDesc.replace(/_/g, " ");

        let allWords = displayDesc.split(" ").concat(tags);
        let uniqueTokens = [];

        for (let i = 0; i < allWords.length; i++) {
            let w = allWords[i].toLowerCase();
            if (uniqueTokens.indexOf(w) === -1) uniqueTokens.push(w);
        }

        dynamicAllItems.push({
            emoji: key,
            display: displayDesc,
            category: "All",
            searchString: (displayDesc + " " + tags.join(" ")).toLowerCase(),
            tokens: uniqueTokens,
            score: 0
        });
    });

    return dynamicAllItems;
}

function updateRecents(emojiChar, allItems, recentItems) {
    let itemObj = allItems.find(item => item.emoji === emojiChar);
    if (!itemObj) return recentItems;

    let newRecents = recentItems.filter(item => item.emoji !== emojiChar);
    newRecents.unshift(itemObj);

    if (newRecents.length > 100) newRecents.pop();
    return newRecents;
}
