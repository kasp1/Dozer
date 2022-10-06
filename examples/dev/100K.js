
let step = 1

while (step <= 100000) {
  console.log(step)

  ++step
}

setInterval(() => {
    console.log(step)

    ++step

    if (step > process.argv[2]) {
        process.exit(0)
    }
}, 500)