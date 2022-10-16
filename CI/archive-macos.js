import fs from 'fs'
import archiver from 'archiver'

let version = process.env['CI_VERSION'] || '1.0.0'
let fileName = `dist/Dozer_${version}_MacOS.zip`;

const output = fs.createWriteStream(fileName)
const archive = archiver('zip', { zlib: { level: 9 } })

output.on('close', function() {
  console.log(archive.pointer() + ' total bytes')
  console.log('Finished.')
})

archive.on('warning', (err) => console.log(err))
archive.on('error', (err) => console.log(err))

archive.pipe(output)

archive.file('dist/dozer-macos', { name: 'dozer' })
archive.directory('dist/webui/', 'webui')

archive.finalize()