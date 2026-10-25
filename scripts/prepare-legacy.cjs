const fs = require('node:fs');
const path = require('node:path');
const { describeSite, buildSite } = require('./build.cjs');

function matchesSnapshot(directory, rendered) {
    return [...rendered].every(([file, content]) => {
        const target = path.join(directory, file);
        return fs.existsSync(target) && fs.readFileSync(target).equals(content);
    });
}
async function prepareLegacy(
    root = path.resolve(__dirname, '..'),
    destination = path.join(root, '.build-cache/legacy'),
    { publishedUrl = 'https://obmaz.github.io/sjrpg/legacy/', fetcher = fetch } = {},
) {
    const plan = describeSite(root);
    if (matchesSnapshot(destination, plan.rendered))
        return { assetRoot: plan.assetRoot, source: 'cache' };
    const temporary = `${destination}.restore-${process.pid}`;
    try {
        const read = async (file, expected) => {
            const response = await fetcher(new URL(file, publishedUrl), {
                signal: AbortSignal.timeout(30000),
            });
            if (!response.ok) throw new Error(`Published Legacy ${file}: HTTP ${response.status}`);
            const content = Buffer.from(await response.arrayBuffer());
            if (!content.equals(expected))
                throw new Error(`Published Legacy does not match source: ${file}`);
            const target = path.join(temporary, file);
            fs.mkdirSync(path.dirname(target), { recursive: true });
            fs.writeFileSync(target, content);
        };
        fs.rmSync(temporary, { recursive: true, force: true });
        // Check the entry before downloading anything: a changed Legacy requires its own build.
        await read('index.html', plan.rendered.get('index.html'));
        const pending = [...plan.rendered].filter(
            ([file]) => file !== 'index.html' && file !== '.nojekyll',
        );
        const results = await Promise.allSettled(
            Array.from({ length: 6 }, async () => {
                while (pending.length) {
                    const [file, expected] = pending.shift();
                    await read(file, expected);
                }
            }),
        );
        const failed = results.find((result) => result.status === 'rejected');
        if (failed) throw failed.reason;
        fs.writeFileSync(path.join(temporary, '.nojekyll'), '');
        fs.rmSync(destination, { recursive: true, force: true });
        fs.renameSync(temporary, destination);
        return { assetRoot: plan.assetRoot, source: 'published' };
    } catch (error) {
        fs.rmSync(temporary, { recursive: true, force: true });
        buildSite(root, destination);
        return { assetRoot: plan.assetRoot, source: 'built', reason: error.message };
    }
}
if (require.main === module)
    prepareLegacy()
        .then((result) => {
            console.log(`Legacy ${result.source}: ${result.assetRoot}`);
            if (result.reason) console.log(result.reason);
            if (process.env.GITHUB_OUTPUT)
                fs.appendFileSync(process.env.GITHUB_OUTPUT, `source=${result.source}\n`);
        })
        .catch((error) => {
            console.error(error);
            process.exitCode = 1;
        });
module.exports = { prepareLegacy, matchesSnapshot };
