
let step = 1

setInterval(() => {
    console.log(step)

    ++step

    if (step > process.argv[2]) {
        process.exit(0)
    }
}, 1000)