import fs from 'fs'
import archiver from 'archiver'

const output = fs.createWriteStream('dist/Linux64.zip')
const archive = archiver('zip', { zlib: { level: 9 } })

output.on('close', function() {
  console.log(archive.pointer() + ' total bytes')
  console.log('Finished.')
})

archive.on('warning', (err) => console.log(err))
archive.on('error', (err) => console.log(err))

archive.pipe(output)

archive.file('dist/dozer-linux', { name: 'dozer' })
archive.directory('dist/webui/', 'webui')

archive.finalize()