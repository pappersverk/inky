{[runs: runs], []} =
  OptionParser.parse!(System.argv(),
    strict: [runs: :integer]
  )

Inky.InkyBench.run(runs: runs)
