import express, { Express, Request, Response } from 'express';
import { ChildProcessByStdio } from 'child_process'
import { Readable, Writable } from 'stream'

const { spawn } = require('node:child_process');

const app: Express = express();
const port: number = 3000
const domainRegex: RegExp =
  /^([A-Z\d]{1,63}|[A-Z\d][A-Z\d\\-]{0,61}[A-Z\d])(\.([A-Z\d]{1,63}|[A-Z\d][A-Z\d\\-]{0,61}[A-Z\d]))+$/i

app.get('/*', (req: Request, res: Response) => {

    const url: string = req.url || '/'
    const domain : string = url.substring(1).trim()

    // ensure domain only contains letters, numbers, dots and hyphens, in the correct pattern
    // this is important because this string gets passed as an argument to a shell script
    // and thus is obvious place for an injection attack
    if (domain.search(domainRegex) === -1) {
        res.statusCode = 422
        res.end('Domain parameter was invalid')
        return
    }

    // domain arg has been scrubbed above
    const analysis: ChildProcessByStdio<Writable, Readable, Readable>
      = spawn('scripts/analyze.sh', [domain]);

    let result: string = ''
    analysis.stdout.on('data', (data: string) => {
        // console.log(`stdout: ${data}`);
        result = result + data
    });

    analysis.stderr.on('data', (data: string) => {
        // console.error(`stderr: ${data}`);
    });

    analysis.on('close', (code: number) => {
        if (code !== 0) console.warn(`child process exited with code ${code}`);
        res.setHeader('Content-Type', 'application/json')
        res.end(result)
    });
})

app.listen(port, () => {
    console.log(`Botalyzer listening on port ${port}`)
})
