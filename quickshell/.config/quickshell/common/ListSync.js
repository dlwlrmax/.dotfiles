.pragma library

// Make a ListModel (one role, "k") hold exactly `keys` in order, touching as little as possible:
// existing keys keep their delegates (and their local state); only new keys are inserted, gone
// ones removed, moved ones moved.
function sync(model, keys) {
    for (var i = 0; i < keys.length; i++) {
        if (i < model.count && model.get(i).k === keys[i]) continue
        var from = -1
        for (var j = i + 1; j < model.count; j++) {
            if (model.get(j).k === keys[i]) { from = j; break }
        }
        if (from >= 0) model.move(from, i, 1)
        else model.insert(i, { k: keys[i] })
    }
    while (model.count > keys.length) model.remove(model.count - 1)
}
