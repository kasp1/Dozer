import fs from 'fs'
import archiver from 'archiver'

let version = process.env['CI_VERSION'] || '1.0.0'
let fileName = `dist/Dozer_${version}_Windows_x64.zip`;

const output = fs.createWriteStream(fileName)
const archive = archiver('zip', { zlib: { level: 9 } })

output.on('close', function() {
  console.log(archive.pointer() + ' total bytes')
  console.log('Finished', fileName)
})

archive.on('warning', (err) => console.log(err))
archive.on('error', (err) => console.log(err))

archive.pipe(output)

let files = {
  'dist/dozer-win.exe': 'dozer.exe',
  'dist/dozerui-win.exe': 'dozerui.exe'
}

for (let file in files) {
  archive.file(file, { name: files[file] })
}

for (let name of fs.readdirSync('dist')) {
  if (name.includes('.dll')) {
    archive.file('dist/' + name, { name: name })
  }
}

archive.directory('dist/webui/', 'webui')
archive.directory('dist/data/', 'data')

archive.finalize()