import {writeFile} from 'node:fs/promises'

var count= '2'

await writeFile('app/count.txt', count, {
    encoding: 'utf8'
})

async function processFiles(array) {
    const unparsedData = await fs.promises.readFile(entry.file_name, "utf8");
    const parsedData = JSON.parse(unparsedData);
    parsedData.data.push(entry.dataObj);
    const json = JSON.stringify(parsedData, null, 2);
    await fs.promise.writeFile(entry.file_name, json, "utf8");
}