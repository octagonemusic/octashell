.pragma library

// Reusable memory buffers for faster edit distance calculation
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
            let cost = (aChar === b[j]) ? 0 : 1;
            _v1[j + 1] = Math.min(_v1[j] + 1, _v0[j + 1] + 1, _v0[j] + cost);
        }
        for (let j = 0; j <= bLen; j++) _v0[j] = _v1[j];
    }
    return _v0[bLen];
}

function filterEmojis(baseItems, queryStr) {
    let query = queryStr.toLowerCase();
    let queryLen = query.length;
    let filtered = [];

    for (let i = 0; i < baseItems.length; i++) {
        let item = baseItems[i];
        let maxScore = 0;
        let searchStr = item.searchString;

        if (item.display.toLowerCase() === query) {
            maxScore = 110;
        } else if (searchStr.startsWith(query)) {
            maxScore = 95;
        }

        if (maxScore < 100) {
            let tokens = item.tokens;
            for (let t = 0; t < tokens.length; t++) {
                let token = tokens[t];
                if (token === query) {
                    maxScore = Math.max(maxScore, 100);
                    break;
                } else if (token.startsWith(query)) {
                    maxScore = Math.max(maxScore, 90);
                } else if (token.includes(query)) {
                    maxScore = Math.max(maxScore, 70);
                } else if (queryLen >= 3) {
                    let allowedTypos = queryLen >= 6 ? 2 : 1;
                    if (Math.abs(token.length - queryLen) <= allowedTypos) {
                        let dist = getEditDistance(token, query);
                        if (dist <= allowedTypos) {
                            maxScore = Math.max(maxScore, 45 - (dist * 10));
                        }
                    }
                }
            }
        }

        if (maxScore < 50) {
            let qIdx = 0;
            let strIdx = 0;
            while (qIdx < queryLen && strIdx < searchStr.length) {
                if (query[qIdx] === searchStr[strIdx]) qIdx++;
                strIdx++;
            }
            if (qIdx === queryLen) maxScore = Math.max(maxScore, 50);
        }

        if (maxScore > 0) {
            item.score = maxScore;
            filtered.push(item);
        }
    }

    filtered.sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        return a.display.length - b.display.length;
    });

    return filtered.slice(0, 150);
}

function parseEmojiJson(textBody) {
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
