function filterEmojis(baseItems, queryStr) {
  let query = queryStr.toLowerCase().trim();
  if (query.length === 0) return [];

  let results = [];

  // Simple, fast iteration
  for (let i = 0; i < baseItems.length; i++) {
    let item = baseItems[i];

    // Check if the query exists anywhere in the search string (name + tags)
    if (item.searchString.includes(query)) {
      // Prioritize items that actually start with the query
      let displayLower = item.display.toLowerCase();
      item.score = displayLower.startsWith(query) ? 2 : 1;

      results.push(item);
    }
  }

  // Sort by score (startsWith first), then by shortest display name
  results.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.display.length - b.display.length;
  });

  // Cap results to keep rendering fast
  return results.slice(0, 50);
}

function parseEmojiJson(textBody) {
  let parsedJson = JSON.parse(textBody);
  let dynamicAllItems = [];

  Object.keys(parsedJson).forEach((key) => {
    let tags = parsedJson[key] || [];
    let rawDesc = tags.length > 0 ? tags[0] : "emoji";
    let displayDesc = rawDesc.replace(/_/g, " ");

    dynamicAllItems.push({
      emoji: key,
      display: displayDesc,
      category: "All",
      // Flatten display name and tags into one searchable string
      searchString: (displayDesc + " " + tags.join(" ")).toLowerCase(),
      score: 0,
    });
  });

  return dynamicAllItems;
}

function updateRecents(emojiChar, allItems, recentItems) {
  let itemObj = allItems.find((item) => item.emoji === emojiChar);
  if (!itemObj) return recentItems;

  let newRecents = recentItems.filter((item) => item.emoji !== emojiChar);
  newRecents.unshift(itemObj);

  if (newRecents.length > 100) newRecents.pop();
  return newRecents;
}
