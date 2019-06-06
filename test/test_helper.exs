ExUnit.configure(formatters: [ExUnit.CLIFormatter, ExUnitNotifier])
ExUnit.start()

Code.require_file("support/testutil.exs", __DIR__)
Code.require_file("support/testio.exs", __DIR__)
Code.require_file("support/testverifier.exs", __DIR__)
