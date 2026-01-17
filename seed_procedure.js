// Stored Procedure: bulkInsertEmployees
function bulkInsertEmployees(dataArray) {
    var collection = getContext().getCollection();
    var response = getContext().getResponse();
    var insertedCount = 0;

    if (!dataArray || !Array.isArray(dataArray)) {
        throw new Error("Input must be an array of documents");
    }

    for (var i = 0; i < dataArray.length; i++) {
        var doc = dataArray[i];
        var accepted = collection.createDocument(collection.getSelfLink(), doc, {}, function (err) {
            if (err) throw err;
        });

        if (!accepted) break;
        insertedCount++;
    }

    response.setBody({
        inserted: insertedCount,
        total: dataArray.length
    });
}
