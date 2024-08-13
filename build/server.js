import { writeFile, open } from 'node:fs/promises'
import * as http from 'http'
import { createWriteStream } from 'node:fs'

var count = 0;
var cpt = '' + count;

const file = await open('app/count.txt')
//const stream = createWriteStream('app/count.txt');

const httpServer = http.createServer(function(req, res) {
    count++;
    cpt = '' + count;
    //file.open()
    file.File(cpt)
});
//file.close()

httpServer.on('request', (request, response) => {
    // On écrit le corps de la réponse
    response.end('Nombre de connexions : ' + count);
});

httpServer.listen(80);
